import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/work_session.dart';
import '../models/location_log.dart';
import '../models/location.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';
import 'geofencing_service.dart';
import 'background_location_service.dart';
import 'connectivity_service.dart';

class WorkSessionService extends ChangeNotifier {
  final ApiService _apiService;
  final ConnectivityService _connectivityService = ConnectivityService();
  
  WorkSession? _currentSession;
  Map<int, LocationLog> _locationLogs = {};
  bool _isSessionActive = false;
  String? _activeUserId;
  
  // Geofencing servisi
  GeofencingService? _geofencingService;
  List<Location> _trackedLocations = [];
  
  // Periyodik konum güncellemesi için timer'lar
  Timer? _locationCollectTimer;  // Her 1 dakika konum topla
  Timer? _locationSendTimer;     // Her 5 dakika gönder
  
  // Konum buffer'ı (5 dakikalık veriler burada birikir)
  final List<Map<String, dynamic>> _locationBuffer = [];
  
  // Connectivity listener
  StreamSubscription<bool>? _connectivitySubscription;
  
  // Offline mod flag
  bool _isOfflineMode = false;
  bool _isProcessingPendingActions = false;
  
  WorkSession? get currentSession => _currentSession;
  bool get isSessionActive => _isSessionActive;
  Map<int, LocationLog> get locationLogs => _locationLogs;
  bool get isOfflineMode => _isOfflineMode;
  
  int get completedCount => _locationLogs.values
      .where((log) => log.isCompleted)
      .length;

  WorkSessionService(this._apiService) {
    _initializeConnectivity();
  }
  
  /// Connectivity servisini başlat ve internet değişikliklerini dinle
  void _initializeConnectivity() {
    // Internet durumunu dinle
    _connectivitySubscription = _connectivityService.connectionStatus.listen((isOnline) {
      _isOfflineMode = !isOnline;
      notifyListeners();
      
      if (isOnline) {
        print('🌐 İnternet bağlantısı geldi - pending veriler gönderiliyor...');
        _syncPendingLocationUpdates();
        unawaited(_processPendingCheckActions());
      } else {
        print('📴 İnternet bağlantısı kesildi - offline mod aktif');
      }
    });
    
    // İlk durumu kontrol et
    _isOfflineMode = !_connectivityService.isOnline;
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Token'ı set et (login sonrası çağrılmalı)
  void setToken(String token) {
    _apiService.setToken(token);
  }

  /// AuthService değiştiğinde çağrılmalı (token/user değişimi)
  void handleAuthChange(User? user, String? token) {
    final newUserId = user?.id;
    
    if (token != null && token.isNotEmpty) {
      _apiService.setToken(token);
    } else {
      _apiService.clearToken();
    }
    
    if (_activeUserId == newUserId) {
      return;
    }
    
    final previousUserId = _activeUserId;
    _activeUserId = newUserId;
    unawaited(_onUserChanged(previousUserId, newUserId));
  }

  Future<void> _onUserChanged(String? previousUserId, String? newUserId) async {
    final shouldClearLocalData = newUserId == null;
    
    await clearSession(clearLocalData: shouldClearLocalData);
    await OfflineStorageService.setUserContext(newUserId);
    
    if (newUserId != null) {
      await loadActiveSession();
      await _syncPendingLocationUpdates();
      await _processPendingCheckActions();
    }
  }

  /// İş oturumu başlat
  Future<Map<String, dynamic>> startWorkSession({
    required int totalLocations,
    required List<Location> locations,
    String? weatherNote,
  }) async {
    try {
      // 1. Aktif oturum var mı kontrol et
      if (_isSessionActive) {
        return {
          'success': false,
          'message': 'Zaten aktif bir iş oturumu var',
        };
      }

      // 2. Backend'e gönder
      final result = await _apiService.startWorkSession(
        totalLocations: totalLocations,
        weatherNote: weatherNote,
      );

      if (result['success'] == true) {
        // 3. Yeni session oluştur
        _currentSession = WorkSession.fromJson(result['session']);
        _isSessionActive = true;
        _locationLogs.clear();
        _trackedLocations = List<Location>.from(locations);
        
        // 4. Local'e kaydet
        await _saveSessionLocally();
        
        // 5. Geofencing'i başlat
        await _startGeofencing(locations);
        
        // 6. Periyodik konum güncellemesini başlat (her 1 dakika)
        _startLocationUpdateTimer();
        
        // 7. Pending verileri varsa senkronize et
        _syncPendingLocationUpdates();
        unawaited(_processPendingCheckActions());
        
        notifyListeners();
        
        return {
          'success': true,
          'session': _currentSession,
          'message': 'İş oturumu başlatıldı',
        };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'İş oturumu başlatılamadı: $e',
      };
    }
  }

  /// İş oturumu bitir
  Future<Map<String, dynamic>> endWorkSession({
    String? workNote,
  }) async {
    try {
      if (!_isSessionActive || _currentSession == null || _currentSession!.id == null) {
        return {
          'success': false,
          'message': 'Aktif iş oturumu yok',
        };
      }

      // 1. Backend'e gönder (sessionId artık String/UUID)
      final result = await _apiService.endWorkSession(
        sessionId: _currentSession!.id!,  // UUID direkt gönder
        completedLocations: completedCount,
        workNote: workNote,
      );

      if (result['success'] == true) {
        // 2. Periyodik konum güncellemesini durdur
        _stopLocationUpdateTimer();
        
        // 3. Background GPS tracking'i durdur
        await BackgroundLocationService.stopService();
        
        // 4. Geofencing'i durdur
        await _stopGeofencing();
        
        // 4. Local state güncelle
        _isSessionActive = false;
        
        // 4. Oturumu completed olarak işaretle
        _currentSession = WorkSession(
          id: _currentSession!.id,
          userId: _currentSession!.userId,
          startedAt: _currentSession!.startedAt,
          endedAt: DateTime.now(),
          totalDuration: DateTime.now().difference(_currentSession!.startedAt).inSeconds,
          totalAssignedLocations: _currentSession!.totalAssignedLocations,
          completedLocations: completedCount,
          completionRate: (completedCount / _currentSession!.totalAssignedLocations) * 100,
          notes: workNote,
          status: 'completed',
        );
        
        // 5. Local'e kaydet (tarihçe için)
        await _saveSessionLocally();
        
        // 6. Temizle
        await Future.delayed(const Duration(seconds: 2));
        _currentSession = null;
        _locationLogs.clear();
        _trackedLocations.clear();
        
        notifyListeners();
        
        return {
          'success': true,
          'message': 'İş oturumu tamamlandı',
        };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'İş oturumu bitirilemedi: $e',
      };
    }
  }

  /// Lokasyona check-in
  Future<Map<String, dynamic>> checkInLocation({
    required Location location,
    required Position position,
  }) async {
    Map<String, dynamic>? checkInPayload;
    try {
      if (!_isSessionActive || _currentSession == null) {
        return {
          'success': false,
          'message': 'Aktif iş oturumu yok',
        };
      }

      // 1. Zaten check-in yapılmış mı?
      if (_locationLogs.containsKey(location.id)) {
        final existingLog = _locationLogs[location.id]!;
        if (existingLog.isInProgress || existingLog.isCompleted || existingLog.isPendingCheckIn) {
          return {
            'success': false,
            'message': 'Bu lokasyona zaten check-in yapıldı',
          };
        }
      }

      checkInPayload = {
        'work_session_id': _currentSession!.id!,
        'location_id': location.id,
        'assignment_id': location.assignmentId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'notes': 'Check-in yapıldı',
      };

      if (!_connectivityService.isOnline) {
        return await _queueCheckIn(
          location: location,
          position: position,
          payload: checkInPayload!,
        );
      }

      final result = await _apiService.checkInLocation(
        sessionId: _currentSession!.id!,
        locationId: location.id,
        assignmentId: location.assignmentId, // UUID ekle
        lat: position.latitude,
        lng: position.longitude,
      );

      if (result['success'] == true) {
        await _handleCheckInSuccess(location.id, result['log']);
        return {
          'success': true,
          'log': result['log'],
          'message': result['message'] ?? 'Check-in başarılı',
        };
      } else {
        return result;
      }
    } on DioException catch (e) {
      if (_shouldQueueError(e)) {
        return await _queueCheckIn(
          location: location,
          position: position,
          payload: checkInPayload ??
              {
                'work_session_id': _currentSession?.id,
                'location_id': location.id,
                'assignment_id': location.assignmentId,
                'latitude': position.latitude,
                'longitude': position.longitude,
                'notes': 'Check-in yapıldı',
              },
        );
      }
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Check-in başarısız',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Check-in başarısız: $e',
      };
    }
  }

  /// Lokasyondan check-out
  Future<Map<String, dynamic>> checkOutLocation({
    required Location location,
    String? notes,
  }) async {
    Map<String, dynamic>? lastCheckoutPayload;
    int durationMinutes = 0;
    
    try {
      if (!_isSessionActive || _currentSession == null) {
        return {
          'success': false,
          'message': 'Aktif iş oturumu yok',
        };
      }

      // 1. Check-in yapılmış mı?
      if (!_locationLogs.containsKey(location.id)) {
        return {
          'success': false,
          'message': 'Bu lokasyona check-in yapılmamış',
        };
      }

      final log = _locationLogs[location.id]!;
      
      // Check-out zaten yapılmış mı?
      if (log.isCompleted || log.isPendingCheckOut) {
        return {
          'success': false,
          'message': 'Bu lokasyon için check-out zaten yapıldı',
        };
      }
      
      // Pending check-in durumunda: Eğer check-in çok eskiyse (5 dakika+), check-out'a izin ver
      if (log.isPendingCheckIn) {
        final timeSinceCheckIn = DateTime.now().difference(log.checkedInAt);
        if (timeSinceCheckIn.inMinutes >= 5) {
          print('⚠️ Pending check-in çok eski (${timeSinceCheckIn.inMinutes} dk), check-out yapılıyor');
          // Check-in pending ama eski, devam et
        } else {
          return {
            'success': false,
            'message': 'Check-in henüz tamamlanmadı, lütfen bekleyin veya internet bağlantınızı kontrol edin',
          };
        }
      }
      
      // Log ID kontrolü - Check-out için gerekli
      if (log.id == null || log.id!.isEmpty) {
        print('⚠️ Check-out için log ID yok, geçici ID oluşturuluyor...');
        // Log ID yoksa, check-in önce tamamlanmalı veya geçici ID kullanılmalı
        // Bu durumda pending check-out yapılmalı
        final timeSinceCheckIn = DateTime.now().difference(log.checkedInAt);
        if (timeSinceCheckIn.inMinutes >= 5) {
          // Eski bir check-in, direkt queue'ya al
          final durationMinutes = timeSinceCheckIn.inMinutes;
          Position? checkoutPosition;
          try {
            checkoutPosition = await Geolocator.getCurrentPosition(
              timeLimit: const Duration(seconds: 10),
            );
          } catch (e) {
            print('⚠️ Check-out konumu alınamadı: $e');
          }
          
          return await _queueCheckOut(
            location: location,
            log: log,
            durationMinutes: durationMinutes,
            payload: {
              'latitude': checkoutPosition?.latitude ?? log.checkinLat,
              'longitude': checkoutPosition?.longitude ?? log.checkinLng,
              'notes': notes ?? 'Check-out yapıldı',
            },
          );
        } else {
          return {
            'success': false,
            'message': 'Check-in henüz tamamlanmadı, lütfen bekleyin',
          };
        }
      }

      // 2. Süreyi hesapla
      durationMinutes = DateTime.now().difference(log.checkedInAt).inMinutes;

      Position? checkoutPosition;
      try {
        checkoutPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        print('⚠️ Check-out konumu alınamadı: $e');
        // Fallback: Check-in konumunu kullan
        if (log.checkinLat != null && log.checkinLng != null) {
          print('📍 Check-in koordinatları fallback olarak kullanılıyor');
        }
      }
      
      // Fallback mekanizması: Check-in koordinatlarını kullan
      final payload = {
        'latitude': checkoutPosition?.latitude ?? log.checkinLat,
        'longitude': checkoutPosition?.longitude ?? log.checkinLng,
        'notes': notes ?? 'Check-out yapıldı',
      };
      lastCheckoutPayload = payload;

      if (!_connectivityService.isOnline) {
        return await _queueCheckOut(
          location: location,
          log: log,
          durationMinutes: durationMinutes,
          payload: payload,
        );
      }

      // Log ID tekrar kontrol et (güvenlik için)
      if (log.id == null || log.id!.isEmpty) {
        print('❌ Check-out için log ID hala yok, queue\'ya alınıyor');
        return await _queueCheckOut(
          location: location,
          log: log,
          durationMinutes: durationMinutes,
          payload: payload,
        );
      }

      final result = await _apiService.checkOutLocation(
        logId: log.id!,
        durationMinutes: durationMinutes,
        notes: notes,
        lat: (payload['latitude'] as num?)?.toDouble(),
        lng: (payload['longitude'] as num?)?.toDouble(),
      );

      if (result['success'] == true) {
        await _handleCheckOutSuccess(location.id, result['log']);
        return {
          'success': true,
          'log': result['log'],
          'message': result['message'] ?? 'Check-out başarılı',
        };
      } else {
        return result;
      }
    } on DioException catch (e) {
      final log = _locationLogs[location.id]!;
      if (_shouldQueueError(e)) {
        return await _queueCheckOut(
          location: location,
          log: log,
          durationMinutes: durationMinutes,
          payload: lastCheckoutPayload ??
              {
                'latitude': null,
                'longitude': null,
                'notes': notes ?? 'Check-out yapıldı',
              },
        );
      }
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Check-out başarısız',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Check-out başarısız: $e',
      };
    }
  }

  /// Lokasyon durumunu al
  String getLocationStatus(int locationId) {
    if (!_locationLogs.containsKey(locationId)) {
      return 'not_started';
    }
    
    final log = _locationLogs[locationId]!;
    
    if (log.isPendingCheckIn) {
      return 'pending_check_in';
    }
    
    if (log.isPendingCheckOut) {
      return 'pending_check_out';
    }
    
    // Backend status mapping
    if (log.status == 'checked_in') {
      return 'in_progress';
    } else if (log.status == 'checked_out') {
      return 'completed';
    }
    
    return log.status;
  }

  /// Aktif oturumu backend'den yükle
  Future<void> loadActiveSession() async {
    try {
      print('🔄 Aktif oturum kontrol ediliyor...');
      
      // 1. Önce backend'den kontrol et
      final result = await _apiService.getActiveWorkSession();
      
      if (result['success'] == true && result['session'] != null) {
        print('✅ Backend\'de aktif oturum bulundu');
        
        // Backend'de aktif oturum var
        _currentSession = WorkSession.fromJson(result['session']);
        _isSessionActive = true;
        
        // Location logs'u yükle
        if (result['logs'] != null) {
          final logsData = result['logs'] as List;
          _locationLogs = Map.fromEntries(
            logsData.map((log) {
              final locationLog = LocationLog.fromJson(log);
              return MapEntry(locationLog.locationId, locationLog);
            }),
          );
        }

        if (_trackedLocations.isEmpty) {
          _trackedLocations = await _loadTrackedLocationsFromCache(await OfflineStorageService.getActiveWorkSession());
        }
        
        // Local'e de kaydet
        await _saveSessionLocally();
        await _restartTrackingPipelines();
        unawaited(_processPendingCheckActions());
        
        notifyListeners();
        print('✅ Aktif oturum yüklendi: ${_currentSession!.id}');
      } else {
        print('ℹ️ Aktif oturum yok');
        
        // Backend'de aktif oturum yok, local'i temizle
        await clearSession();
      }
    } catch (e) {
      print('⚠️ Aktif oturum yükleme hatası: $e');
      
      // Hata durumunda local'den yüklemeyi dene
      try {
        final sessionData = await OfflineStorageService.getActiveWorkSession();
        
        if (sessionData != null) {
          _currentSession = WorkSession.fromJson(sessionData['session']);
          _isSessionActive = true;
          
          final logsData = sessionData['logs'] as List?;
          if (logsData != null) {
            _locationLogs = Map.fromEntries(
              logsData.map((log) {
                final locationLog = LocationLog.fromJson(log);
                return MapEntry(locationLog.locationId, locationLog);
              }),
            );
          }

          _trackedLocations = _restoreTrackedLocationsFromData(sessionData);
          if (_trackedLocations.isEmpty) {
            _trackedLocations = await OfflineStorageService.getLocations();
          }
          
          notifyListeners();
          print('✅ Local\'den aktif oturum yüklendi');
          
          await _restartTrackingPipelines();
          unawaited(_processPendingCheckActions());
        }
      } catch (localError) {
        print('❌ Local yükleme de başarısız: $localError');
      }
    }
  }

  /// Oturumu local'e kaydet
  Future<void> _saveSessionLocally() async {
    try {
      if (_currentSession != null) {
        await OfflineStorageService.saveActiveWorkSession({
          'session': _currentSession!.toJson(),
          'logs': _locationLogs.values.map((log) => log.toJson()).toList(),
          'locations': _trackedLocations.map((location) => location.toJson()).toList(),
        });
      }
    } catch (e) {
      print('Oturum kaydedilemedi: $e');
    }
  }

  /// Oturumu temizle
  Future<void> clearSession({bool clearLocalData = true}) async {
    _stopLocationUpdateTimer();
    await BackgroundLocationService.stopService();
    await _stopGeofencing();
    _currentSession = null;
    _isSessionActive = false;
    _locationLogs.clear();
    _trackedLocations.clear();
    _locationBuffer.clear();
    if (clearLocalData) {
      await OfflineStorageService.clearActiveWorkSession();
      await OfflineStorageService.clearPendingCheckActions();
    }
    notifyListeners();
  }
  
  /// Periyodik konum güncellemesini başlat (15 sn topla, 5 dk gönder)
  void _startLocationUpdateTimer() {
    // Önce varsa eski timer'ları durdur
    _stopLocationUpdateTimer();
    
    print('⏱️ Konum toplama başlatıldı (15 saniye aralık)');
    print('📤 Toplu gönderim başlatıldı (5 dakika aralık)');
    
    // İlk konumu hemen topla
    _collectLocation();
    
    // Her 15 saniyede bir konum topla (buffer'a ekle)
    _locationCollectTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _collectLocation();
    });
    
    // Her 5 dakikada bir buffer'daki konumları toplu gönder
    _locationSendTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _sendBatchLocationUpdate();
    });
  }
  
  /// Periyodik konum güncellemesini durdur
  void _stopLocationUpdateTimer() {
    // Toplama timer'ını durdur
    if (_locationCollectTimer != null) {
      _locationCollectTimer!.cancel();
      _locationCollectTimer = null;
      print('⏱️ Konum toplama durduruldu');
    }
    
    // Gönderim timer'ını durdur
    if (_locationSendTimer != null) {
      _locationSendTimer!.cancel();
      _locationSendTimer = null;
      print('📤 Toplu gönderim durduruldu');
    }
    
    // Kalan verileri gönder
    if (_locationBuffer.isNotEmpty) {
      print('📦 ${_locationBuffer.length} bekleyen konum son kez gönderiliyor...');
      _sendBatchLocationUpdate();
    }
  }
  
  /// Mevcut konumu al ve buffer'a ekle
  Future<void> _collectLocation() async {
    try {
      // Aktif oturum kontrolü
      if (!_isSessionActive || _currentSession == null || _currentSession!.id == null) {
        print('⚠️ Aktif oturum yok, konum toplanmadı');
        return;
      }
      
      // Konum izni kontrolü
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('⚠️ Konum izni yok, konum toplanmadı');
        return;
      }
      
      // Mevcut konumu al (orta hassasiyet - batarya tasarrufu)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      // Buffer'a ekle (backend'in beklediği formatta)
      // Background service'teki formatla uyumlu olmalı
      _locationBuffer.add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
      });
      
      print('📍 Konum buffer\'a eklendi: ${position.latitude}, ${position.longitude} (Toplam: ${_locationBuffer.length})');
      
      // Eğer buffer 10'dan fazla konum içeriyorsa hemen gönder (güvenlik)
      // Backend maksimum 10 konum kabul ediyor, bu yüzden limit 10
      if (_locationBuffer.length >= 10) {
        print('⚠️ Buffer doldu (${_locationBuffer.length}), hemen gönderiliyor...');
        await _sendBatchLocationUpdate();
      }
    } catch (e) {
      print('❌ Konum toplama hatası: $e');
    }
  }
  
  /// Buffer'daki tüm konumları toplu olarak API'ye gönder (veya offline'a kaydet)
  Future<void> _sendBatchLocationUpdate() async {
    // Buffer boşsa işlem yapma
    if (_locationBuffer.isEmpty) {
      print('ℹ️ Gönderilecek konum yok (buffer boş)');
      return;
    }
    
    try {
      // Aktif oturum kontrolü
      if (!_isSessionActive || _currentSession == null || _currentSession!.id == null) {
        print('⚠️ Aktif oturum yok, toplu gönderim iptal edildi');
        _locationBuffer.clear();
        return;
      }
      
      // Gönderilecek verileri kopyala
      final locationsToSend = List<Map<String, dynamic>>.from(_locationBuffer);
      
      // İnternet var mı kontrol et
      if (!_connectivityService.isOnline) {
        print('📴 İnternet yok - ${locationsToSend.length} konum offline\'a kaydediliyor...');
        
        // Offline storage'a kaydet
        await OfflineStorageService.savePendingLocationUpdates(
          sessionId: _currentSession!.id!,
          locations: locationsToSend,
        );
        
        // Buffer'ı temizle
        _locationBuffer.clear();
        
        print('💾 Offline kayıt başarılı');
        return;
      }
      
      print('📤 ${locationsToSend.length} konum toplu olarak gönderiliyor...');
      
      // Backend maksimum 10 konum kabul ediyor, 10'ar 10'ar gönder
      const maxBatchSize = 10;
      int totalSent = 0;
      int totalFailed = 0;
      
      // Konumları 10'ar 10'ar grupla
      for (int i = 0; i < locationsToSend.length; i += maxBatchSize) {
        final batchEnd = (i + maxBatchSize < locationsToSend.length) 
            ? i + maxBatchSize 
            : locationsToSend.length;
        final batch = locationsToSend.sublist(i, batchEnd);
        
        print('📦 Batch ${(i ~/ maxBatchSize) + 1}: ${batch.length} konum gönderiliyor...');
        
        // API'ye batch gönder
        final result = await _apiService.sendBatchLocationUpdate(
          sessionId: _currentSession!.id!,
          locations: batch,
        );
        
        if (result['success'] == true) {
          totalSent += batch.length;
          print('✅ Batch ${(i ~/ maxBatchSize) + 1} başarılı: ${batch.length} konum kaydedildi');
        } else {
          totalFailed += batch.length;
          print('❌ Batch ${(i ~/ maxBatchSize) + 1} başarısız: ${result['message']}');
          
          // Başarısız batch'i offline'a kaydet
          await OfflineStorageService.savePendingLocationUpdates(
            sessionId: _currentSession!.id!,
            locations: batch,
          );
        }
      }
      
      // Tüm batch'ler gönderildi
      if (totalSent > 0) {
        print('✅ Toplu konum güncellemesi tamamlandı: $totalSent konum kaydedildi');
      }
      
      if (totalFailed == 0) {
        // Tüm batch'ler başarılı, buffer'ı temizle
        _locationBuffer.clear();
      } else {
        // Bazı batch'ler başarısız, sadece başarılı olanları buffer'dan çıkar
        // Başarısız olanlar zaten offline'a kaydedildi
        if (totalSent == locationsToSend.length) {
          // Hepsi başarılı
          _locationBuffer.clear();
        } else {
          // Başarısız olanları buffer'da tutma, zaten offline'a kaydedildi
          // Buffer'ı temizle, çünkü başarısız olanlar offline storage'da
          _locationBuffer.clear();
        }
      }
      
      // Tüm batch'ler tamamlandı, buffer temizlendi
      if (totalFailed > 0) {
        print('⚠️ $totalFailed konum offline\'a kaydedildi, daha sonra tekrar denenecek');
      }
    } catch (e) {
      print('❌ Toplu konum güncellemesi hatası: $e');
      
      // Hata durumunda offline'a kaydet
      try {
        if (_currentSession?.id != null) {
          final locationsToSave = List<Map<String, dynamic>>.from(_locationBuffer);
          await OfflineStorageService.savePendingLocationUpdates(
            sessionId: _currentSession!.id!,
            locations: locationsToSave,
          );
          _locationBuffer.clear();
          print('💾 Hata sonrası offline kayıt yapıldı');
        }
      } catch (saveError) {
        print('❌ Offline kayıt hatası: $saveError');
        // Son çare: buffer'ı temizle
        if (_locationBuffer.length > 20) {
          _locationBuffer.clear();
        }
      }
    }
  }
  
  /// Pending (bekleyen) GPS verilerini senkronize et
  Future<void> _syncPendingLocationUpdates() async {
    if (_activeUserId == null) {
      print('ℹ️ Aktif kullanıcı yok - pending konum senkronizasyonu atlandı');
      return;
    }
    try {
      // Tüm pending location updates'i al
      final allPending = await OfflineStorageService.getAllPendingLocationUpdates();
      
      if (allPending.isEmpty) {
        print('ℹ️ Senkronize edilecek pending konum yok');
        return;
      }
      
      int totalSynced = 0;
      int totalFailed = 0;
      
      // Her session için pending verileri gönder
      for (var entry in allPending.entries) {
        final sessionId = entry.key;
        final locations = entry.value;
        
        if (locations.isEmpty) continue;
        
        print('🔄 Session $sessionId için ${locations.length} pending konum senkronize ediliyor...');
        
        try {
          // Backend maksimum 10 konum kabul ediyor, 10'ar 10'ar gönder
          const maxBatchSize = 10;
          int batchSynced = 0;
          int batchFailed = 0;
          final failedBatches = <Map<String, dynamic>>[];
          
          // Konumları 10'ar 10'ar grupla
          for (int i = 0; i < locations.length; i += maxBatchSize) {
            final batchEnd = (i + maxBatchSize < locations.length) 
                ? i + maxBatchSize 
                : locations.length;
            final batch = locations.sublist(i, batchEnd);
            
            print('📦 Pending Batch ${(i ~/ maxBatchSize) + 1}: ${batch.length} konum gönderiliyor...');
            
            final result = await _apiService.sendBatchLocationUpdate(
              sessionId: sessionId,
              locations: batch,
            );
            
            if (result['success'] == true) {
              batchSynced += batch.length;
              print('✅ Pending Batch ${(i ~/ maxBatchSize) + 1} başarılı: ${batch.length} konum');
            } else {
              batchFailed += batch.length;
              failedBatches.addAll(batch);
              print('❌ Pending Batch ${(i ~/ maxBatchSize) + 1} başarısız: ${result['message']}');
            }
          }
          
          if (batchSynced == locations.length) {
            // Tüm batch'ler başarılı - pending verileri sil
            await OfflineStorageService.deletePendingLocationUpdates(sessionId);
            totalSynced += locations.length;
            print('✅ ${locations.length} konum başarıyla senkronize edildi');
          } else if (batchSynced > 0) {
            // Bazı batch'ler başarılı, başarısız olanları güncelle
            totalSynced += batchSynced;
            totalFailed += batchFailed;
            
            // Başarısız olanları tekrar offline'a kaydet
            if (failedBatches.isNotEmpty) {
              await OfflineStorageService.savePendingLocationUpdates(
                sessionId: sessionId,
                locations: failedBatches,
              );
            }
            
            print('⚠️ $batchSynced konum senkronize edildi, $batchFailed konum tekrar offline\'a kaydedildi');
          } else {
            // Hiçbiri başarılı değil
            totalFailed += locations.length;
            print('❌ Senkronizasyon başarısız: Tüm batch\'ler başarısız oldu');
          }
        } catch (e) {
          totalFailed += locations.length;
          print('❌ Session $sessionId senkronizasyon hatası: $e');
        }
      }
      
      if (totalSynced > 0) {
        print('🎉 Toplam $totalSynced konum başarıyla senkronize edildi!');
      }
      
      if (totalFailed > 0) {
        print('⚠️ Toplam $totalFailed konum senkronize edilemedi (daha sonra tekrar denenecek)');
      }
    } catch (e) {
      print('❌ Pending veriler senkronize edilemedi: $e');
    }

    await _processPendingCheckActions();
  }

  /// Geofencing servisini başlat
  Future<void> _startGeofencing(List<Location> locations) async {
    try {
      if (locations.isEmpty) {
        print('⚠️ Geofencing başlatılamadı: lokasyon listesi boş');
        return;
      }
      
      await _stopGeofencing();
      _geofencingService = GeofencingService();
      
      final success = await _geofencingService!.startTracking(
        locations: locations,
        onArrival: _onLocationArrival,
        onCheckIn: _onAutoCheckIn,
        onCheckOut: _onAutoCheckOut,
        onUpdate: _onPositionUpdate,
      );
      
      if (success) {
        print('✅ Geofencing başlatıldı - ${locations.length} lokasyon takip ediliyor');
      } else {
        print('❌ Geofencing başlatılamadı');
      }
    } catch (e) {
      print('❌ Geofencing başlatma hatası: $e');
    }
  }

  /// Geofencing servisini durdur
  Future<void> _stopGeofencing() async {
    try {
      await _geofencingService?.stopTracking();
      _geofencingService = null;
      print('✅ Geofencing durduruldu');
    } catch (e) {
      print('❌ Geofencing durdurma hatası: $e');
    }
  }

  /// Lokasyona yaklaşıldığında (bildirim için)
  void _onLocationArrival(Location location, Position position) {
    print('📍 Lokasyona yaklaşıldı: ${location.displayAddress}');
    // Burada bildirim gösterilebilir, şu anda sadece log
  }

  /// Otomatik check-in yapıldığında
  void _onAutoCheckIn(Location location) async {
    try {
      print('🔄 Otomatik check-in başlatılıyor: ${location.displayAddress}');
      
      // GPS konumunu al
      final position = await Geolocator.getCurrentPosition();
      
      // Work session service'e check-in
      final result = await checkInLocation(
        location: location,
        position: position,
      );

      if (result['success'] == true) {
        print('✅ Otomatik check-in başarılı: ${location.displayAddress}');
        
        // Bildirim göster (mounted kontrolü gerekebilir)
        // ScaffoldMessenger.of(context).showSnackBar(...)
      } else {
        print('❌ Otomatik check-in başarısız: ${result['message']}');
      }
    } catch (e) {
      print('❌ Otomatik check-in hatası: $e');
    }
  }

  /// Otomatik check-out yapıldığında
  void _onAutoCheckOut(Location location) async {
    try {
      print('🔄 Otomatik check-out başlatılıyor: ${location.displayAddress}');
      
      // Önce check-in yapılmış mı kontrol et
      if (!_locationLogs.containsKey(location.id)) {
        print('⚠️ Otomatik check-out iptal: Bu lokasyona check-in yapılmamış');
        return;
      }
      
      final log = _locationLogs[location.id]!;
      
      // Check-out zaten yapılmış mı?
      if (log.isCompleted || log.isPendingCheckOut) {
        print('ℹ️ Otomatik check-out iptal: Check-out zaten yapılmış');
        return;
      }
      
      // Log ID kontrolü - otomatik check-out için kritik
      if (log.id == null || log.id!.isEmpty) {
        print('⚠️ Otomatik check-out iptal: Check-in henüz tamamlanmamış (log ID yok)');
        // Check-in pending ise, bir süre bekleyip tekrar dene (pending check-in 5 dakika sonra check-out'a izin verir)
        return;
      }
      
      // Work session service'e check-out
      final result = await checkOutLocation(
        location: location,
        notes: 'Otomatik check-out',
      );

      if (result['success'] == true) {
        print('✅ Otomatik check-out başarılı: ${location.displayAddress}');
        // Bildirim göster (mounted kontrolü gerekebilir)
        // ScaffoldMessenger.of(context).showSnackBar(...)
      } else {
        print('❌ Otomatik check-out başarısız: ${result['message']}');
        // Hata durumunda tekrar deneme mekanizması eklenebilir
      }
    } catch (e) {
      print('❌ Otomatik check-out hatası: $e');
      // Hata durumunda log yazdır ama crash etme
    }
  }

  /// Konum güncellendiğinde
  void _onPositionUpdate(Position position) {
    // Konum güncellemeleri burada işlenebilir
    // Şu anda sadece log
    // print('📍 Konum güncellendi: ${position.latitude}, ${position.longitude}');
  }

  void _markLocationCheckedInState(int locationId) {
    _geofencingService?.markLocationCheckedIn(locationId);
  }

  void _markLocationCheckedOutState(int locationId) {
    _geofencingService?.markLocationCheckedOut(locationId);
  }

  List<Location> _restoreTrackedLocationsFromData(Map<String, dynamic>? data) {
    if (data == null) return [];
    final rawList = data['locations'];
    if (rawList is! List) return [];
    
    final restored = <Location>[];
    for (final item in rawList) {
      try {
        restored.add(Location.fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        print('Lokasyon restore hatası: $e');
      }
    }
    return restored;
  }

  Future<List<Location>> _loadTrackedLocationsFromCache([Map<String, dynamic>? sessionData]) async {
    final restored = _restoreTrackedLocationsFromData(sessionData);
    if (restored.isNotEmpty) {
      return restored;
    }
    
    try {
      return await OfflineStorageService.getLocations();
    } catch (e) {
      print('Lokasyon listesi yüklenemedi: $e');
      return [];
    }
  }

  Future<void> _restartTrackingPipelines() async {
    if (!_isSessionActive || _currentSession == null) {
      return;
    }
    
    if (_trackedLocations.isEmpty) {
      print('⚠️ Takip edilecek lokasyon yok, geofencing başlatılmadı');
      return;
    }
    
    await _stopGeofencing();
    await _startGeofencing(_trackedLocations);
    _startLocationUpdateTimer();
  }

  /// Uygulama resume olduğunda GPS tracking'i yeniden başlat (eğer aktif session varsa)
  Future<void> resumeTrackingIfNeeded() async {
    try {
      // Aktif session kontrolü
      if (!_isSessionActive || _currentSession == null) {
        print('ℹ️ Aktif session yok, GPS tracking yeniden başlatılmayacak');
        return;
      }
      
      // Takip edilecek lokasyonlar var mı kontrol et
      if (_trackedLocations.isEmpty) {
        print('⚠️ Takip edilecek lokasyon yok, lokasyonlar yükleniyor...');
        // Lokasyonları tekrar yüklemeyi dene
        final sessionData = await OfflineStorageService.getActiveWorkSession();
        if (sessionData != null) {
          _trackedLocations = _restoreTrackedLocationsFromData(sessionData);
        }
        
        if (_trackedLocations.isEmpty) {
          print('⚠️ Lokasyonlar yüklenemedi, GPS tracking başlatılamıyor');
          return;
        }
      }
      
      print('🔄 Uygulama resume oldu - GPS tracking yeniden başlatılıyor...');
      
      // GPS tracking'i yeniden başlat
      await _restartTrackingPipelines();
      
      print('✅ GPS tracking başarıyla yeniden başlatıldı');
    } catch (e) {
      print('❌ GPS tracking yeniden başlatılırken hata: $e');
    }
  }

  Location? _findLocationById(int locationId) {
    for (final location in _trackedLocations) {
      if (location.id == locationId) {
        return location;
      }
    }
    return null;
  }

  String _generateTempId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _shouldQueueError(Object error) {
    if (error is! DioException) return false;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401) {
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  Future<Map<String, dynamic>> _queueCheckIn({
    required Location location,
    required Position position,
    required Map<String, dynamic> payload,
  }) async {
    final tempLogId = _generateTempId('localLog');
    final actionId = _generateTempId('checkin');
    final now = DateTime.now();
    
    final pendingLog = LocationLog(
      id: tempLogId,
      workSessionId: _currentSession!.id!,
      locationId: location.id,
      userId: _currentSession!.userId,
      checkedInAt: now,
      status: 'pending_check_in',
      checkinLat: position.latitude,
      checkinLng: position.longitude,
    );
    
    _locationLogs[location.id] = pendingLog;
    await _saveSessionLocally();
    _markLocationCheckedInState(location.id);
    
    await OfflineStorageService.addPendingCheckAction({
      'id': actionId,
      'type': 'check_in',
      'session_id': _currentSession!.id!,
      'location_id': location.id,
      'assignment_id': location.assignmentId,
      'local_log_id': tempLogId,
      'payload': payload,
      'created_at': now.toIso8601String(),
    });
    
    notifyListeners();
    
    return {
      'success': true,
      'log': pendingLog,
      'message': 'Çevrimdışı: Check-in kuyruğa alındı',
      'pending': true,
    };
  }

  Future<Map<String, dynamic>> _queueCheckOut({
    required Location location,
    required LocationLog log,
    required int durationMinutes,
    required Map<String, dynamic> payload,
  }) async {
    final actionId = _generateTempId('checkout');
    final now = DateTime.now();
    final effectiveLogId = log.id ?? _generateTempId('localLog');
    final hasRealLogId = log.id != null && !log.id!.toString().startsWith('local_');
    
    final pendingLog = LocationLog(
      id: effectiveLogId,
      workSessionId: log.workSessionId,
      locationId: log.locationId,
      userId: log.userId,
      checkedInAt: log.checkedInAt,
      checkedOutAt: now,
      duration: durationMinutes * 60,
      checkinLat: log.checkinLat,
      checkinLng: log.checkinLng,
      checkInNotes: log.checkInNotes,
      checkOutNotes: payload['notes'],
      status: 'pending_check_out',
    );
    
    _locationLogs[location.id] = pendingLog;
    await _saveSessionLocally();
    _markLocationCheckedOutState(location.id);
    
    await OfflineStorageService.addPendingCheckAction({
      'id': actionId,
      'type': 'check_out',
      'session_id': _currentSession!.id!,
      'location_id': location.id,
      'log_id': hasRealLogId ? log.id : null,
      'local_log_id': effectiveLogId,
      'payload': {
        ...payload,
        'duration_minutes': durationMinutes,
      },
      'created_at': now.toIso8601String(),
    });
    
    notifyListeners();
    
    return {
      'success': true,
      'log': pendingLog,
      'message': 'Çevrimdışı: Check-out kuyruğa alındı',
      'pending': true,
    };
  }

  Future<void> _processPendingCheckActions() async {
    if (_isProcessingPendingActions) return;
    if (!_connectivityService.isOnline) return;
    
    _isProcessingPendingActions = true;
    try {
      final pendingActions = await OfflineStorageService.getPendingCheckActions();
      if (pendingActions.isEmpty) {
        return;
      }
      
      print('🔄 ${pendingActions.length} bekleyen check-in/out işlemi işleniyor...');
      
      for (final action in List<Map<String, dynamic>>.from(pendingActions)) {
        if (!_connectivityService.isOnline) break;
        final sessionId = action['session_id']?.toString();
        if (_currentSession == null || _currentSession!.id != sessionId) {
          continue;
        }
        
        final type = action['type']?.toString();
        final locationId = action['location_id'] is int
            ? action['location_id']
            : int.tryParse(action['location_id']?.toString() ?? '');
        if (locationId == null) continue;
        
        if (type == 'check_in') {
          final payload = Map<String, dynamic>.from(action['payload'] ?? {});
          final locationInfo = _findLocationById(locationId);
          double? latitude = (payload['latitude'] as num?)?.toDouble();
          double? longitude = (payload['longitude'] as num?)?.toDouble();
          
          if ((latitude == null || longitude == null) && locationInfo != null) {
            latitude ??= locationInfo.lat;
            longitude ??= locationInfo.lng;
          }
          
          if (latitude == null || longitude == null) {
            try {
              final pos = await Geolocator.getCurrentPosition();
              latitude ??= pos.latitude;
              longitude ??= pos.longitude;
            } catch (e) {
              print('⚠️ Pending check-in koordinatı alınamadı: $e');
            }
          }
          
          if (latitude == null || longitude == null) {
            print('❌ Pending check-in için koordinat bulunamadı, işlem atlandı');
            continue;
          }
          
          final assignmentId = payload['assignment_id']?.toString() ?? action['assignment_id']?.toString();
          
          try {
            final result = await _apiService.checkInLocation(
              sessionId: payload['work_session_id'] ?? _currentSession!.id!,
              locationId: payload['location_id'] ?? locationId,
              assignmentId: assignmentId,
              lat: latitude,
              lng: longitude,
            );
            
            if (result['success'] == true) {
              await _handleCheckInSuccess(locationId, result['log'], localLogId: action['local_log_id']?.toString());
              await OfflineStorageService.removePendingCheckAction(action['id'].toString());
              continue;
            } else {
              print('❌ Pending check-in başarısız: ${result['message']}');
            }
          } catch (e) {
            print('❌ Pending check-in hatası: $e');
          }
        } else if (type == 'check_out') {
          var logId = action['log_id']?.toString();
          final localLogId = action['local_log_id']?.toString();
          final payload = Map<String, dynamic>.from(action['payload'] ?? {});
          final locationInfo = _findLocationById(locationId);
          double? latitude = (payload['latitude'] as num?)?.toDouble();
          double? longitude = (payload['longitude'] as num?)?.toDouble();
          
          if ((logId == null || logId.isEmpty) && localLogId != null) {
            final currentLog = _locationLogs[locationId];
            if (currentLog != null && currentLog.id != null && !currentLog.id!.startsWith('local_')) {
              logId = currentLog.id;
              await OfflineStorageService.updatePendingActionsForLog(localLogId, logId);
            } else {
              continue;
            }
          }
          
          if (logId == null || logId.isEmpty) {
            continue;
          }

          if ((latitude == null || longitude == null) && locationInfo != null) {
            latitude ??= locationInfo.lat;
            longitude ??= locationInfo.lng;
          }
          
          if (latitude == null || longitude == null) {
            try {
              final pos = await Geolocator.getCurrentPosition();
              latitude ??= pos.latitude;
              longitude ??= pos.longitude;
            } catch (e) {
              print('⚠️ Pending check-out koordinatı alınamadı: $e');
            }
          }
          
          if (latitude == null || longitude == null) {
            print('❌ Pending check-out için koordinat bulunamadı, işlem atlandı');
            continue;
          }
          
          int actionDuration = 0;
          final durationValue = payload['duration_minutes'];
          if (durationValue is int) {
            actionDuration = durationValue;
          } else if (durationValue != null) {
            actionDuration = int.tryParse(durationValue.toString()) ?? 0;
          }
          
          try {
            final result = await _apiService.checkOutLocation(
              logId: logId,
              durationMinutes: actionDuration,
              notes: payload['notes'],
              lat: latitude,
              lng: longitude,
            );
            
            if (result['success'] == true) {
              await _handleCheckOutSuccess(locationId, result['log']);
              await OfflineStorageService.removePendingCheckAction(action['id'].toString());
              continue;
            } else {
              print('❌ Pending check-out başarısız: ${result['message']}');
            }
          } catch (e) {
            print('❌ Pending check-out hatası: $e');
          }
        }
      }
    } finally {
      _isProcessingPendingActions = false;
    }
  }

  Future<void> _handleCheckInSuccess(int locationId, Map<String, dynamic>? logData, {String? localLogId}) async {
    if (logData == null) return;
    final log = LocationLog.fromJson(Map<String, dynamic>.from(logData));
    _locationLogs[locationId] = log;
    await _saveSessionLocally();
    if (localLogId != null) {
      await OfflineStorageService.updatePendingActionsForLog(localLogId, log.id);
    }
    _markLocationCheckedInState(locationId);
    notifyListeners();
  }

  Future<void> _handleCheckOutSuccess(int locationId, Map<String, dynamic>? logData) async {
    if (logData == null) return;
    final log = LocationLog.fromJson(Map<String, dynamic>.from(logData));
    _locationLogs[locationId] = log;
    await _saveSessionLocally();
    _markLocationCheckedOutState(locationId);
    notifyListeners();
  }
}

