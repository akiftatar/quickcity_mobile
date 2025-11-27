import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:math' as math;

class BackgroundLocationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // iOS Native Method Channel
  static const MethodChannel _channel = MethodChannel('com.quickcity.mobile/background');

  /// Background service'i başlat
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Bildirimleri başlat
    const androidChannel = AndroidNotificationChannel(
      'location_tracking_channel',
      'GPS Takibi',
      description: 'Lokasyonlara yaklaşınca bildirim gönderir',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: '🛰️ QuickCity GPS Aktif',
        initialNotificationContent: 'Lokasyonlar kontrol ediliyor...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Service başladığında
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Timer referansı
    Timer? locationTimer;

    service.on('stopService').listen((event) {
      // Timer'ı cancel et
      locationTimer?.cancel();
      print('⏹️ Background timer durduruldu');
      
      // Service'i durdur
      service.stopSelf();
    });

    // Lokasyonları ve tracking bilgilerini yükle
    final prefs = await SharedPreferences.getInstance();
    final locationsJson = prefs.getString('tracking_locations');
    final notifiedIds = prefs.getStringList('notified_location_ids') ?? [];

    if (locationsJson == null) {
      print('⚠️ Takip edilecek lokasyon yok');
      service.stopSelf();
      return;
    }

    final locationsList = jsonDecode(locationsJson) as List;
    print('🛰️ Background service başladı - ${locationsList.length} lokasyon takip ediliyor');

    // GPS stream'i başlat (TestFlight için daha uzun aralık)
    locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          // Mevcut konumu al (Android için)
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );

          // GPS koordinatları NaN kontrolü
          if (position.latitude.isNaN || position.longitude.isNaN) {
            print('⚠️ GPS koordinatları NaN: lat=${position.latitude}, lng=${position.longitude}');
            return; // Bu iterasyonu atla
          }

      print('📍 GPS Güncelleme: ${position.latitude}, ${position.longitude}');
      await writeLogToFile('📍 GPS Güncelleme: ${position.latitude}, ${position.longitude}');

      // Background'da konum verisi gönder
      await _sendLocationToAPI(position);

        // PERFORMANS: Sadece yakındaki lokasyonları kontrol et
        int nearbyCount = 0;
        for (var locationData in locationsList) {
          final locationId = locationData['id'];
          
          // Bu lokasyona daha önce bildirim gönderilmiş mi?
          if (notifiedIds.contains(locationId.toString())) {
            continue;
          }

          final lat = locationData['lat'];
          final lng = locationData['lng'];
          final address = locationData['address'];

          // Mesafeyi hesapla
          final distance = _calculateDistance(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );

          // PERFORMANS: 1 km'den uzaktaki lokasyonları atla
          if (distance > 1000) {
            continue;
          }
          
          nearbyCount++;
          print('📏 ${locationData['address']}: ${distance.toStringAsFixed(0)}m');

          // 100 metre içinde mi?
          if (distance <= 100) {
            print('🎯 Lokasyona yaklaşıldı: $address');
            
            // Bildirim gönder
            await _showArrivalNotification(
              locationId,
              address,
              distance.toStringAsFixed(0),
            );

            // Bu lokasyonu bildirildi olarak işaretle
            notifiedIds.add(locationId.toString());
            await prefs.setStringList('notified_location_ids', notifiedIds);

            // Ana uygulamaya event gönder
            service.invoke('locationArrival', {
              'location_id': locationId,
              'distance': distance,
            });
          }
        }

        // Foreground notification'ı güncelle
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '🛰️ QuickCity GPS Aktif',
            content: '${locationsList.length - notifiedIds.length} lokasyon kontrol ediliyor...',
          );
        }
      } catch (e) {
        print('❌ GPS Hatası: $e');
      }
    });
  }

  /// iOS background
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    
    // iOS'ta background'da GPS tracking başlat
    print('🍎 iOS Background GPS tracking başlatılıyor...');
    
    // Timer referansı
    Timer? locationTimer;
    
    // Lokasyonları yükle
    final prefs = await SharedPreferences.getInstance();
    final locationsJson = prefs.getString('tracking_locations');
    final notifiedIds = prefs.getStringList('notified_location_ids') ?? [];
    
    if (locationsJson != null) {
      final locationsList = jsonDecode(locationsJson) as List;
      
      // GPS tracking başlat (TestFlight için daha uzun aralık)
      locationTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
        try {
          // iOS Simulator için daha düşük accuracy kullan
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
          
          // GPS koordinatları NaN kontrolü
          if (position.latitude.isNaN || position.longitude.isNaN) {
            print('⚠️ iOS GPS koordinatları NaN: lat=${position.latitude}, lng=${position.longitude}');
            return; // Bu iterasyonu atla
          }
          
          print('🍎 iOS Background GPS: ${position.latitude}, ${position.longitude}');
          await writeLogToFile('🍎 iOS Background GPS: ${position.latitude}, ${position.longitude}');
          
          // Background'da konum verisi gönder
          await _sendLocationToAPI(position);
          
          // Lokasyon kontrolü
          for (var locationData in locationsList) {
            final locationId = locationData['id'];
            
            if (notifiedIds.contains(locationId.toString())) continue;
            
            final lat = locationData['lat'];
            final lng = locationData['lng'];
            final address = locationData['address'];
            
            final distance = _calculateDistance(
              position.latitude,
              position.longitude,
              lat,
              lng,
            );
            
            if (distance <= 100) {
              print('🎯 iOS Background: Lokasyona yaklaşıldı: $address');
              
              await _showArrivalNotification(
                locationId,
                address,
                distance.toStringAsFixed(0),
              );
              
              notifiedIds.add(locationId.toString());
              await prefs.setStringList('notified_location_ids', notifiedIds);
            }
          }
        } catch (e) {
          print('❌ iOS Background GPS Hatası: $e');
        }
      });
    }
    
    return true;
  }

  /// Varış bildirimi göster
  static Future<void> _showArrivalNotification(
    int locationId,
    String address,
    String distance,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'location_arrival',
      'Lokasyon Varışı',
      channelDescription: 'Lokasyona yaklaşıldığında bildirim',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color(0xFF1976D2),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      locationId,
      '📍 Lokasyona Ulaştınız!',
      '$address ($distance m uzakta)\nİşe başlamak için uygulamayı açın',
      details,
      payload: locationId.toString(),
    );
  }

  /// Mesafe hesapla (Haversine formula)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // NaN kontrolü
    if (lat1.isNaN || lon1.isNaN || lat2.isNaN || lon2.isNaN) {
      print('⚠️ NaN koordinat tespit edildi: lat1=$lat1, lon1=$lon1, lat2=$lat2, lon2=$lon2');
      return double.infinity; // Çok büyük mesafe döndür
    }
    
    // Geçerli koordinat aralığı kontrolü
    if (lat1 < -90 || lat1 > 90 || lat2 < -90 || lat2 > 90 ||
        lon1 < -180 || lon1 > 180 || lon2 < -180 || lon2 > 180) {
      print('⚠️ Geçersiz koordinat aralığı: lat1=$lat1, lon1=$lon1, lat2=$lat2, lon2=$lon2');
      return double.infinity;
    }
    
    const earthRadius = 6371000; // metre
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    final distance = earthRadius * c;
    
    // Sonuç NaN kontrolü
    if (distance.isNaN) {
      print('⚠️ Mesafe hesaplama sonucu NaN: lat1=$lat1, lon1=$lon1, lat2=$lat2, lon2=$lon2');
      return double.infinity;
    }
    
    return distance;
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// TestFlight için dosyaya log yaz
  static Future<void> writeLogToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gps_debug.log');
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] $message\n';
      
      await file.writeAsString(logMessage, mode: FileMode.append);
      print('📝 LOG: $message'); // Console'a da yaz
    } catch (e) {
      print('❌ Log yazma hatası: $e');
    }
  }

  /// Background'da konum verisi gönder (TestFlight uyumlu)
  static Future<void> _sendLocationToAPI(Position position) async {
    try {
      // Aktif oturum kontrolü
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('active_work_session');
      
      if (sessionData == null) {
        print('⚠️ Background: Aktif oturum yok, konum gönderilmiyor');
        return;
      }
      
      final session = jsonDecode(sessionData);
      final sessionId = session['session']['id'];
      
      if (sessionId == null) {
        print('⚠️ Background: Session ID yok, konum gönderilmiyor');
        return;
      }
      
      // Konum verisi hazırla
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
      };
      
      print('📤 Background: Konum verisi gönderiliyor - ${position.latitude}, ${position.longitude}');
      await writeLogToFile('📤 Background: Konum verisi gönderiliyor - ${position.latitude}, ${position.longitude}');
      
      // TestFlight için offline storage'a kaydet (güvenli)
      await _saveLocationOffline(locationData, sessionId);
      
      // API'ye gönder (timeout ile)
      final response = await http.post(
        Uri.parse('http://212.91.237.42/api/work-sessions/$sessionId/location-update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session['token']}',
        },
        body: jsonEncode(locationData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Background: Konum verisi başarıyla gönderildi');
        await writeLogToFile('✅ Background: Konum verisi başarıyla gönderildi');
        // Başarılı gönderim sonrası offline'dan sil
        await _removeLocationFromOffline(locationData['timestamp'].toString());
      } else {
        print('❌ Background: Konum gönderme hatası - ${response.statusCode}');
        await writeLogToFile('❌ Background: Konum gönderme hatası - ${response.statusCode}');
        // Hata durumunda offline'da kalsın
      }
    } catch (e) {
      print('❌ Background: Konum gönderme hatası: $e');
      await writeLogToFile('❌ Background: Konum gönderme hatası: $e');
      // Hata durumunda offline'a kaydet
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('active_work_session');
      if (sessionData != null) {
        final session = jsonDecode(sessionData);
        final sessionId = session['session']['id'];
        if (sessionId != null) {
          final locationData = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'timestamp': DateTime.now().toIso8601String(),
            'altitude': position.altitude,
            'speed': position.speed,
            'heading': position.heading,
          };
          await _saveLocationOffline(locationData, sessionId);
        }
      }
    }
  }

  /// Konumu offline'a kaydet
  static Future<void> _saveLocationOffline(Map<String, dynamic> locationData, String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineKey = 'offline_locations_$sessionId';
      final existingData = prefs.getString(offlineKey) ?? '[]';
      final List<dynamic> locations = jsonDecode(existingData);
      
      locations.add(locationData);
      
      // Son 100 konumu sakla (bellek tasarrufu)
      if (locations.length > 100) {
        locations.removeRange(0, locations.length - 100);
      }
      
      await prefs.setString(offlineKey, jsonEncode(locations));
      print('💾 Background: Konum offline\'a kaydedildi');
    } catch (e) {
      print('❌ Background: Offline kayıt hatası: $e');
    }
  }

  /// Offline'dan konumu sil
  static Future<void> _removeLocationFromOffline(String timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('offline_locations_'));
      
      for (final key in keys) {
        final existingData = prefs.getString(key) ?? '[]';
        final List<dynamic> locations = jsonDecode(existingData);
        
        locations.removeWhere((loc) => loc['timestamp'] == timestamp);
        
        await prefs.setString(key, jsonEncode(locations));
      }
    } catch (e) {
      print('❌ Background: Offline silme hatası: $e');
    }
  }

  /// TestFlight log dosyasını oku
  static Future<String> getDebugLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gps_debug.log');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isEmpty) {
          return 'Log dosyası boş - Background service henüz çalışmamış olabilir';
        }
        return content;
      } else {
        // Log dosyası yoksa test logu yaz
        await writeLogToFile('🔍 Debug log testi - ${DateTime.now()}');
        return 'Log dosyası bulunamadı. Test logu oluşturuldu. Tekrar deneyin.';
      }
    } catch (e) {
      return 'Log okuma hatası: $e';
    }
  }

  /// Service'i başlat
  static Future<bool> startService(List<Map<String, dynamic>> locations) async {
    try {
      await writeLogToFile('🚀 Background service başlatılıyor...');
      
      // iOS için native background task kullan
      if (Platform.isIOS) {
        await writeLogToFile('🍎 iOS Native background task başlatılıyor...');
        try {
          await _channel.invokeMethod('startBackgroundLocationTracking');
          await writeLogToFile('✅ iOS Native background task başlatıldı');
          return true;
        } catch (e) {
          await writeLogToFile('❌ iOS Native background task hatası: $e');
          // Fallback olarak Flutter background service kullan
        }
      }
      
      final service = FlutterBackgroundService();

      // Lokasyonları kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tracking_locations', jsonEncode(locations));
      await prefs.setStringList('notified_location_ids', []);

      // Service'i başlat
      await service.startService();
      
      print('✅ Background service başlatıldı - ${locations.length} lokasyon');
      await writeLogToFile('✅ Background service başlatıldı - ${locations.length} lokasyon');
      return true;
    } catch (e) {
      print('❌ Background service başlatılamadı: $e');
      await writeLogToFile('❌ Background service başlatılamadı: $e');
      return false;
    }
  }

  /// Service'i durdur (Tamamen temizle)
  static Future<void> stopService() async {
    try {
      // iOS için native background task durdur
      if (Platform.isIOS) {
        try {
          await _channel.invokeMethod('stopBackgroundLocationTracking');
          await writeLogToFile('✅ iOS Native background task durduruldu');
        } catch (e) {
          await writeLogToFile('❌ iOS Native background task durdurma hatası: $e');
        }
      }
      
      final service = FlutterBackgroundService();
      
      // Service'i durdur
      service.invoke('stopService');
      
      // Tüm bildirimleri temizle
      await _notificationsPlugin.cancelAll();
      
      // Tracking verilerini temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tracking_locations');
      await prefs.remove('notified_location_ids');
      
      print('✅ Background service durduruldu ve temizlendi');
      print('🔕 Tüm bildirimler temizlendi');
    } catch (e) {
      print('❌ Background service durdurulamadı: $e');
    }
  }

  /// Service çalışıyor mu?
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}

