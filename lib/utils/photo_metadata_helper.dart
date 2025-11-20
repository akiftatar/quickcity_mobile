import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';

class PhotoMetadata {
  final String timestamp;
  final String formattedDate;
  final double? latitude;
  final double? longitude;
  final String? deviceModel;
  final String? deviceOS;
  final String userName;
  final String locationAddress;
  final int photoIndex;
  final int totalPhotos;

  PhotoMetadata({
    required this.timestamp,
    required this.formattedDate,
    this.latitude,
    this.longitude,
    this.deviceModel,
    this.deviceOS,
    required this.userName,
    required this.locationAddress,
    required this.photoIndex,
    required this.totalPhotos,
  });

  String toWatermarkText() {
    final buffer = StringBuffer();
    buffer.writeln('📅 $formattedDate');
    
    if (latitude != null && longitude != null) {
      buffer.writeln('📍 ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}');
    }
    
    buffer.writeln('👤 $userName');
    buffer.writeln('🏢 $locationAddress');
    
    if (deviceModel != null) {
      buffer.writeln('📱 $deviceModel');
    }
    
    buffer.writeln('🔢 Fotoğraf $photoIndex/$totalPhotos');
    
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'formatted_date': formattedDate,
      'latitude': latitude,
      'longitude': longitude,
      'device_model': deviceModel,
      'device_os': deviceOS,
      'user_name': userName,
      'location_address': locationAddress,
      'photo_index': photoIndex,
      'total_photos': totalPhotos,
    };
  }
}

class PhotoMetadataHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Fotoğraf metadata'sını topla
  static Future<PhotoMetadata> collectMetadata({
    required String userName,
    required String locationAddress,
    required int photoIndex,
    required int totalPhotos,
  }) async {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm:ss').format(now);

    // GPS koordinatlarını al
    Position? position;
    try {
      position = await _getCurrentPosition();
    } catch (e) {
      print('GPS alınamadı: $e');
    }

    // Cihaz bilgilerini al
    String? deviceModel;
    String? deviceOS;
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        deviceOS = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        deviceOS = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e) {
      print('Cihaz bilgisi alınamadı: $e');
    }

    return PhotoMetadata(
      timestamp: timestamp,
      formattedDate: formattedDate,
      latitude: position?.latitude,
      longitude: position?.longitude,
      deviceModel: deviceModel,
      deviceOS: deviceOS,
      userName: userName,
      locationAddress: locationAddress,
      photoIndex: photoIndex,
      totalPhotos: totalPhotos,
    );
  }

  /// Mevcut GPS konumunu al
  static Future<Position?> _getCurrentPosition() async {
    try {
      // Konum servislerinin açık olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Konum izinlerini kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Konumu al (5 saniye timeout)
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('Konum alınırken hata: $e');
      return null;
    }
  }

  /// Metadata'yı JSON string olarak kaydet (backend'e göndermek için)
  static String metadataToJsonString(PhotoMetadata metadata) {
    return '''
{
  "timestamp": "${metadata.timestamp}",
  "formatted_date": "${metadata.formattedDate}",
  "latitude": ${metadata.latitude},
  "longitude": ${metadata.longitude},
  "device_model": "${metadata.deviceModel}",
  "device_os": "${metadata.deviceOS}",
  "user_name": "${metadata.userName}",
  "location_address": "${metadata.locationAddress}",
  "photo_index": ${metadata.photoIndex},
  "total_photos": ${metadata.totalPhotos}
}
''';
  }
}
