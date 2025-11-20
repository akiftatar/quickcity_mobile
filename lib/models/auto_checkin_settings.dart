import 'package:shared_preferences/shared_preferences.dart';

/// Otomatik Check-in/Check-out ayarları
class AutoCheckInSettings {
  // Otomatik check-in/check-out aktif mi?
  final bool autoCheckInEnabled;
  final bool autoCheckOutEnabled;

  // Check-in kriterleri
  final double checkInProximityMeters; // Lokasyona ne kadar yakın olmalı (metre)
  final int checkInDwellMinutes; // Lokasyonda ne kadar süre beklemeli (dakika)

  // Check-out kriterleri
  final double checkOutDistanceMeters; // Lokasyondan ne kadar uzak olmalı (metre)
  final int checkOutDepartureMinutes; // Dışarıda ne kadar süre kalmalı (dakika)

  AutoCheckInSettings({
    this.autoCheckInEnabled = true,  // Her zaman aktif
    this.autoCheckOutEnabled = true,  // Her zaman aktif
    this.checkInProximityMeters = 50.0,  // Sabit: 50 metre
    this.checkInDwellMinutes = 2,  // Sabit: 2 dakika
    this.checkOutDistanceMeters = 100.0,  // Sabit: 100 metre
    this.checkOutDepartureMinutes = 5,  // Sabit: 5 dakika
  });

  /// SharedPreferences'tan yükle - Kullanıcılar için sabit ayarlar
  static Future<AutoCheckInSettings> load() async {
    // Kullanıcılar için her zaman sabit ayarlar döndür
    return AutoCheckInSettings(
      autoCheckInEnabled: true,  // Her zaman aktif
      autoCheckOutEnabled: true,  // Her zaman aktif
      checkInProximityMeters: 50.0,  // Sabit: 50 metre
      checkInDwellMinutes: 2,  // Sabit: 2 dakika
      checkOutDistanceMeters: 100.0,  // Sabit: 100 metre
      checkOutDepartureMinutes: 5,  // Sabit: 5 dakika
    );
  }

  /// SharedPreferences'a kaydet - Kullanıcılar için kaydedilmiyor (sabit ayarlar)
  Future<bool> save() async {
    // Kullanıcılar için ayarlar değiştirilemez, kaydedilmiyor
    return true;
  }

  /// Ayarları kopyala
  AutoCheckInSettings copyWith({
    bool? autoCheckInEnabled,
    bool? autoCheckOutEnabled,
    double? checkInProximityMeters,
    int? checkInDwellMinutes,
    double? checkOutDistanceMeters,
    int? checkOutDepartureMinutes,
  }) {
    return AutoCheckInSettings(
      autoCheckInEnabled: autoCheckInEnabled ?? this.autoCheckInEnabled,
      autoCheckOutEnabled: autoCheckOutEnabled ?? this.autoCheckOutEnabled,
      checkInProximityMeters: checkInProximityMeters ?? this.checkInProximityMeters,
      checkInDwellMinutes: checkInDwellMinutes ?? this.checkInDwellMinutes,
      checkOutDistanceMeters: checkOutDistanceMeters ?? this.checkOutDistanceMeters,
      checkOutDepartureMinutes: checkOutDepartureMinutes ?? this.checkOutDepartureMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_checkin_enabled': autoCheckInEnabled,
      'auto_checkout_enabled': autoCheckOutEnabled,
      'checkin_proximity_meters': checkInProximityMeters,
      'checkin_dwell_minutes': checkInDwellMinutes,
      'checkout_distance_meters': checkOutDistanceMeters,
      'checkout_departure_minutes': checkOutDepartureMinutes,
    };
  }

  @override
  String toString() {
    return 'AutoCheckInSettings(checkIn: $autoCheckInEnabled, checkOut: $autoCheckOutEnabled, '
           'proximity: ${checkInProximityMeters}m, dwell: ${checkInDwellMinutes}min, '
           'distance: ${checkOutDistanceMeters}m, departure: ${checkOutDepartureMinutes}min)';
  }
}

