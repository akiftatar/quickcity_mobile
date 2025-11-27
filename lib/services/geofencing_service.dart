import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/location.dart';
import '../models/auto_checkin_settings.dart';
import 'background_location_service.dart';

/// Lokasyon durum takibi için sınıf
class LocationTrackingState {
  final int locationId;
  DateTime? enteredAt; // Lokasyona girildiği zaman
  DateTime? exitedAt; // Lokasyondan çıkıldığı zaman
  bool isInProximity = false; // Şu anda yakınlık alanında mı?
  bool hasAutoCheckedIn = false; // Otomatik check-in yapıldı mı?
  bool hasAutoCheckedOut = false; // Otomatik check-out yapıldı mı?

  LocationTrackingState(this.locationId);
}

class GeofencingService {
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  bool _isTracking = false;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Kontrol edilen lokasyonlar (bir kez bildirim için)
  final Set<int> _notifiedLocationIds = <int>{};
  
  // Otomatik check-in/check-out için lokasyon durumları
  final Map<int, LocationTrackingState> _locationStates = {};
  
  // Otomatik check-in/check-out ayarları
  AutoCheckInSettings? _autoSettings;
  
  // Otomatik check-in/check-out timer'ı
  Timer? _autoCheckTimer;
  
  // Yakınlık eşiği (metre)
  static const double proximityThreshold = 50.0;
  
  // Callback fonksiyonları
  Function(Location location, Position position)? onLocationArrival;
  Function(Location location)? onAutoCheckIn; // Otomatik check-in
  Function(Location location)? onAutoCheckOut; // Otomatik check-out
  Function(Position position)? onPositionUpdate;
  
  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;

  GeofencingService() {
    _initializeNotifications();
  }

  /// Bildirimleri başlat
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(initSettings);
  }

  /// GPS izlemeyi başlat (Background destekli)
  Future<bool> startTracking({
    required List<Location> locations,
    Function(Location, Position)? onArrival,
    Function(Location)? onCheckIn,
    Function(Location)? onCheckOut,
    Function(Position)? onUpdate,
  }) async {
    try {
      // 1. İzin kontrolü
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        print('GPS izni alınamadı');
        return false;
      }

      // 2. GPS aktif mi kontrol et
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        print('GPS servisi kapalı');
        return false;
      }

      // 3. Otomatik check-in/check-out ayarlarını yükle
      _autoSettings = await AutoCheckInSettings.load();
      print('🔧 Otomatik Check-In/Out Ayarları: $_autoSettings');

      // 4. Callback'leri ata
      onLocationArrival = onArrival;
      onAutoCheckIn = onCheckIn;
      onAutoCheckOut = onCheckOut;
      onPositionUpdate = onUpdate;

      // 5. Lokasyon durumlarını başlat
      _locationStates.clear();
      for (var location in locations) {
        _locationStates[location.id] = LocationTrackingState(location.id);
      }

      // 6. Background service'i başlat
      final locationsData = locations.map((loc) => {
        'id': loc.id,
        'lat': loc.lat,
        'lng': loc.lng,
        'address': loc.displayAddress,
        'cluster': loc.clusterLabel,
      }).toList();

      final bgStarted = await BackgroundLocationService.startService(locationsData);
      
      if (!bgStarted) {
        print('⚠️ Background service başlatılamadı, sadece foreground çalışacak');
      }

      // 7. İlk konumu al
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 8. Konum stream'ini başlat (foreground için)
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10 metre hareket edince güncelle
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _onPositionChanged(position, locations);
        },
        onError: (error) {
          print('GPS hatası: $error');
        },
      );

      // 9. Otomatik check-in/check-out timer'ını başlat
      _startAutoCheckTimer(locations);

      _isTracking = true;
      _notifiedLocationIds.clear();
      
      print('🛰️ GPS takibi başlatıldı (Background + Foreground)');
      if (_autoSettings?.autoCheckInEnabled == true) {
        print('✅ Otomatik Check-In aktif');
      }
      if (_autoSettings?.autoCheckOutEnabled == true) {
        print('✅ Otomatik Check-Out aktif');
      }
      return true;
    } catch (e) {
      print('GPS başlatma hatası: $e');
      return false;
    }
  }

  /// GPS izlemeyi durdur (Background dahil)
  Future<void> stopTracking() async {
    // Foreground tracking'i durdur
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    _currentPosition = null;
    _notifiedLocationIds.clear();
    
    // Otomatik check-in/check-out timer'ını durdur
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;
    _locationStates.clear();
    
    // Background service'i durdur
    await BackgroundLocationService.stopService();
    
    print('🛰️ GPS takibi durduruldu (Background + Foreground)');
  }

  /// Konum değiştiğinde
  void _onPositionChanged(Position position, List<Location> locations) {
    _currentPosition = position;
    
    // 1. Callback'i çağır
    onPositionUpdate?.call(position);
    
    // 2. Yakındaki lokasyonları kontrol et
    _checkNearbyLocations(position, locations);
  }

  /// Yakındaki lokasyonları kontrol et ve durumları güncelle
  void _checkNearbyLocations(Position position, List<Location> locations) {
    final now = DateTime.now();
    final checkInProximity = _autoSettings?.checkInProximityMeters ?? 50.0;
    final checkOutDistance = _autoSettings?.checkOutDistanceMeters ?? 100.0;

    for (final location in locations) {
      final state = _locationStates[location.id];
      if (state == null) continue;

      // Mesafeyi hesapla
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        location.lat,
        location.lng,
      );

      // Lokasyona yakınlık durumunu güncelle
      final wasInProximity = state.isInProximity;
      final isNowInProximity = distance <= checkInProximity;

      // Yakınlık durumu değişti mi?
      if (!wasInProximity && isNowInProximity) {
        // Lokasyona girildi
        state.isInProximity = true;
        state.enteredAt = now;
        state.exitedAt = null;
        print('📍 Lokasyona girildi: ${location.displayAddress} (${distance.toStringAsFixed(0)}m)');
      } else if (wasInProximity && !isNowInProximity) {
        // Lokasyondan çıkıldı
        final isFarEnough = distance >= checkOutDistance;
        if (isFarEnough) {
          state.isInProximity = false;
          state.exitedAt = now;
          print('🚶 Lokasyondan çıkıldı: ${location.displayAddress} (${distance.toStringAsFixed(0)}m)');
        }
      } else if (isNowInProximity) {
        // Hala lokasyonda
        state.isInProximity = true;
      }

      // Bildirim kontrolü (sadece ilk girişte)
      if (isNowInProximity && !_notifiedLocationIds.contains(location.id)) {
        _onLocationProximity(location, position, distance);
        _notifiedLocationIds.add(location.id);
      }
    }
  }

  /// Lokasyona yaklaşıldığında
  void _onLocationProximity(Location location, Position position, double distance) {
    print('📍 Lokasyona yaklaşıldı: ${location.displayAddress} (${distance.toStringAsFixed(0)}m)');
    
    // 1. Bildirim gönder
    _showArrivalNotification(location, distance);
    
    // 2. Callback'i çağır
    onLocationArrival?.call(location, position);
  }

  /// Varış bildirimi göster
  Future<void> _showArrivalNotification(Location location, double distance) async {
    const androidDetails = AndroidNotificationDetails(
      'location_arrival',
      'Lokasyon Varışı',
      channelDescription: 'Lokasyona yaklaşıldığında bildirim',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      location.id,
      '📍 Lokasyona Ulaştınız!',
      '${location.displayAddress} (${distance.toStringAsFixed(0)}m uzakta)\nİşe başlamak istiyor musunuz?',
      details,
    );
  }

  /// İki nokta arası mesafe hesapla (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // metre
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c; // metre cinsinden
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// İzinleri kontrol et ve iste
  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }

  /// En yakın lokasyonu bul
  Location? findNearestLocation(List<Location> locations) {
    if (_currentPosition == null || locations.isEmpty) {
      return null;
    }

    Location? nearest;
    double minDistance = double.infinity;

    for (final location in locations) {
      final distance = calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        location.lat,
        location.lng,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = location;
      }
    }

    return nearest;
  }

  /// Lokasyona olan mesafeyi al
  double? getDistanceToLocation(Location location) {
    if (_currentPosition == null) {
      return null;
    }

    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      location.lat,
      location.lng,
    );
  }

  /// Otomatik check-in/check-out timer'ını başlat
  void _startAutoCheckTimer(List<Location> locations) {
    // Her 30 saniyede bir kontrol et
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAutoCheckInOut(locations);
    });
    print('⏱️ Otomatik check-in/out timer başlatıldı (30 saniye aralık)');
  }

  /// Otomatik check-in/check-out kontrolü yap
  void _checkAutoCheckInOut(List<Location> locations) {
    if (_autoSettings == null) {
      print('⚠️ Otomatik ayarlar yüklenmedi');
      return;
    }

    if (_currentPosition != null) {
      _checkNearbyLocations(_currentPosition!, locations);
    } else {
      print('⚠️ Otomatik kontrol için güncel konum yok');
    }

    final now = DateTime.now();
    final checkInDwellMinutes = _autoSettings!.checkInDwellMinutes;
    final checkOutDepartureMinutes = _autoSettings!.checkOutDepartureMinutes;

    print('🔍 Otomatik check kontrolü - ${locations.length} lokasyon');
    print('📋 Check-in aktif: ${_autoSettings!.autoCheckInEnabled}, Check-out aktif: ${_autoSettings!.autoCheckOutEnabled}');

    for (final location in locations) {
      final state = _locationStates[location.id];
      if (state == null) continue;
      
      // Debug bilgisi
      final distance = _currentPosition != null 
          ? calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, location.lat, location.lng)
          : null;
      
      print('📍 ${location.displayAddress}: ${distance?.toStringAsFixed(0)}m, Proximity: ${state.isInProximity}, Check-in: ${state.hasAutoCheckedIn}, Check-out: ${state.hasAutoCheckedOut}');
      
      // DEBUG: Check-out için tüm koşulları kontrol et
      if (state.hasAutoCheckedIn && !state.hasAutoCheckedOut && !state.isInProximity) {
        print('   🔍 Check-out adayı: ${location.displayAddress}');
        print('      - exitedAt: ${state.exitedAt}');
        if (state.exitedAt != null) {
          final minutesOutside = now.difference(state.exitedAt!).inMinutes;
          print('      - minutesOutside: $minutesOutside dk (Gereken: ${checkOutDepartureMinutes} dk)');
        } else {
          print('      - ⚠️ exitedAt NULL! Check-out yapılamaz!');
        }
      }

      // OTOMATIK CHECK-IN kontrolü
      if (_autoSettings!.autoCheckInEnabled &&
          !state.hasAutoCheckedIn &&
          state.isInProximity &&
          state.enteredAt != null) {
        
        final minutesInside = now.difference(state.enteredAt!).inMinutes;
        
        if (minutesInside >= checkInDwellMinutes) {
          // Kullanıcı yeterince süre lokasyonda kaldı, otomatik check-in yap
          print('✅ OTOMATIK CHECK-IN: ${location.displayAddress} ($minutesInside dakikadır lokasyonda)');
          state.hasAutoCheckedIn = true;
          state.hasAutoCheckedOut = false; // Reset check-out durumu
          
          // Callback'i çağır
          onAutoCheckIn?.call(location);
          
          // Bildirim gönder
          _showAutoCheckInNotification(location, minutesInside);
        }
      }

      // OTOMATIK CHECK-OUT kontrolü
      if (_autoSettings!.autoCheckOutEnabled &&
          state.hasAutoCheckedIn &&
          !state.hasAutoCheckedOut &&
          !state.isInProximity &&
          state.exitedAt != null) {
        
        final minutesOutside = now.difference(state.exitedAt!).inMinutes;
        
        // Debug log ekle
        print('   🔍 Check-out kontrolü: ${location.displayAddress}');
        print('      - hasAutoCheckedIn: ${state.hasAutoCheckedIn}');
        print('      - hasAutoCheckedOut: ${state.hasAutoCheckedOut}');
        print('      - isInProximity: ${state.isInProximity}');
        print('      - exitedAt: ${state.exitedAt}');
        print('      - minutesOutside: $minutesOutside dk (Gereken: ${checkOutDepartureMinutes} dk)');
        
        if (minutesOutside >= checkOutDepartureMinutes) {
          // Kullanıcı yeterince süre lokasyondan uzakta kaldı, otomatik check-out yap
          print('✅ OTOMATIK CHECK-OUT: ${location.displayAddress} ($minutesOutside dakikadır uzakta)');
          state.hasAutoCheckedOut = true;
          
          // Callback'i çağır
          onAutoCheckOut?.call(location);
          
          // Bildirim gönder
          _showAutoCheckOutNotification(location, minutesOutside);
        } else {
          print('   ⏳ Check-out henüz yapılmayacak: ${checkOutDepartureMinutes - minutesOutside} dakika daha bekleniyor');
        }
      }
    }
  }

  /// Otomatik check-in bildirimi
  Future<void> _showAutoCheckInNotification(Location location, int minutes) async {
    const androidDetails = AndroidNotificationDetails(
      'auto_checkin',
      'Otomatik Check-In',
      channelDescription: 'Otomatik check-in bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      location.id + 10000, // Farklı ID kullan
      '✅ Otomatik Check-In',
      '${location.displayAddress}\n$minutes dakikadır bu lokasyondasınız. Otomatik olarak check-in yapıldı.',
      details,
    );
  }

  /// Otomatik check-out bildirimi
  Future<void> _showAutoCheckOutNotification(Location location, int minutes) async {
    const androidDetails = AndroidNotificationDetails(
      'auto_checkout',
      'Otomatik Check-Out',
      channelDescription: 'Otomatik check-out bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      location.id + 20000, // Farklı ID kullan
      '🔚 Otomatik Check-Out',
      '${location.displayAddress}\n$minutes dakikadır lokasyondan uzaktasınız. Otomatik olarak check-out yapıldı.',
      details,
    );
  }

  /// Lokasyonun otomatik check-in durumunu sıfırla (manuel check-out sonrası)
  void resetLocationState(int locationId) {
    final state = _locationStates[locationId];
    if (state != null) {
      state.hasAutoCheckedIn = false;
      state.hasAutoCheckedOut = false;
      state.enteredAt = null;
      state.exitedAt = null;
      print('🔄 Lokasyon durumu sıfırlandı: $locationId');
    }
  }

  /// Manuel veya otomatik check-in gerçekleştiğinde çağır
  void markLocationCheckedIn(int locationId) {
    final state = _locationStates[locationId];
    if (state != null) {
      state.hasAutoCheckedIn = true;
      state.hasAutoCheckedOut = false;
      state.enteredAt ??= DateTime.now();
      state.isInProximity = true;
    }
  }

  /// Manuel veya otomatik check-out gerçekleştiğinde çağır
  void markLocationCheckedOut(int locationId) {
    final state = _locationStates[locationId];
    if (state != null) {
      state.hasAutoCheckedIn = false;
      state.hasAutoCheckedOut = true;
      state.isInProximity = false;
      state.enteredAt = null;
      state.exitedAt = DateTime.now();
    }
  }

  /// Lokasyondan çıkıldığını işaretle (check-in var ama uzaktayız)
  void markLocationExited(int locationId, DateTime exitedAt) {
    final state = _locationStates[locationId];
    if (state != null) {
      state.isInProximity = false;
      state.exitedAt = exitedAt;
      print('   🚶 Location $locationId: exitedAt set edildi ($exitedAt)');
    }
  }

  /// Dispose
  void dispose() {
    stopTracking();
  }
}

