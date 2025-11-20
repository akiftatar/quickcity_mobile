import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';
import 'connectivity_service.dart';

class SyncService extends ChangeNotifier {
  final ApiService _apiService;
  final ConnectivityService _connectivityService = ConnectivityService();
  
  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  String? _token;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;

  SyncService(this._apiService) {
    _init();
  }

  /// Token'ı set et (login sonrası çağrılmalı)
  void setToken(String token) {
    _token = token;
    _apiService.setToken(token);
  }

  Future<void> _init() async {
    // Bekleyen sorun sayısını yükle
    _pendingCount = await OfflineStorageService.getPendingIssuesCount();
    notifyListeners();

    // Online olunca otomatik sync
    _connectivityService.connectionStatus.listen((isOnline) {
      if (isOnline && _pendingCount > 0) {
        syncPendingIssues();
      }
    });
  }

  /// Lokasyonları sync et (API'den çek, offline'a kaydet)
  Future<bool> syncLocations() async {
    if (!_connectivityService.isOnline) {
      print('⚠️ Offline - Lokasyonlar sync edilemiyor');
      return false;
    }

    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      // API'den lokasyonları çek
      final result = await _apiService.getUserAssignmentsRouted();
      
      if (result['success'] == true) {
        final locations = result['locations'] ?? [];
        
        // Offline storage'a kaydet
        await OfflineStorageService.saveLocations(locations);
        
        _lastSyncTime = DateTime.now();
        print('✅ ${locations.length} lokasyon sync edildi');
        
        return true;
      } else {
        _lastSyncError = result['message'];
        return false;
      }
    } catch (e) {
      _lastSyncError = 'Sync hatası: $e';
      print('❌ Lokasyon sync hatası: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Bekleyen sorunları sync et (offline'dan API'ye gönder)
  Future<bool> syncPendingIssues() async {
    if (!_connectivityService.isOnline) {
      print('⚠️ Offline - Sorunlar sync edilemiyor');
      return false;
    }

    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      final pendingIssues = await OfflineStorageService.getPendingIssues();
      
      if (pendingIssues.isEmpty) {
        print('✅ Sync edilecek sorun yok');
        return true;
      }

      int successCount = 0;
      int failCount = 0;

      for (var issueData in pendingIssues) {
        try {
          final tempId = issueData['temp_id'] as String;
          
          // Fotoğrafları hazırla
          final imagePaths = issueData['image_paths'] as List<dynamic>?;
          final images = <File>[];
          
          if (imagePaths != null) {
            for (var path in imagePaths) {
              final file = File(path.toString());
              if (await file.exists()) {
                images.add(file);
              }
            }
          }

          // API'ye gönder
          final result = await _apiService.reportIssue(
            locationId: issueData['location_id'] as int,
            description: issueData['description'] as String,
            priority: issueData['priority'] as String,
            images: images,
          );

          if (result['success'] == true) {
            // Başarılı - pending'den sil
            await OfflineStorageService.deletePendingIssue(tempId);
            successCount++;
            print('✅ Sorun sync edildi: $tempId');
          } else {
            failCount++;
            print('❌ Sorun sync edilemedi: ${result['message']}');
          }
        } catch (e) {
          failCount++;
          print('❌ Sorun sync hatası: $e');
        }
      }

      // Bekleyen sayıyı güncelle
      _pendingCount = await OfflineStorageService.getPendingIssuesCount();
      _lastSyncTime = DateTime.now();

      print('📊 Sync tamamlandı: $successCount başarılı, $failCount başarısız');
      
      return failCount == 0;
    } catch (e) {
      _lastSyncError = 'Sync hatası: $e';
      print('❌ Pending issues sync hatası: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Tam sync (lokasyonlar + sorunlar)
  Future<bool> fullSync() async {
    if (!_connectivityService.isOnline) {
      print('⚠️ Offline - Full sync edilemiyor');
      return false;
    }

    final locationsSync = await syncLocations();
    final issuesSync = await syncPendingIssues();

    return locationsSync && issuesSync;
  }

  /// Manuel sync tetikle
  Future<void> manualSync() async {
    await fullSync();
  }

  /// Pending count'u güncelle
  Future<void> updatePendingCount() async {
    _pendingCount = await OfflineStorageService.getPendingIssuesCount();
    notifyListeners();
  }
}
