import 'dart:math' as math;
import '../models/location.dart';

/// Gerçekçi süre tahmini yardımcısı
class TimeEstimationHelper {
  // ==================== HIZLAR ====================
  
  static const double trafficSpeed = 35.0;        // km/s - Trafikteki ortalama hız
  static const double workSpeedGehwege = 10.0;    // km/s - Gehwege temizleme hızı
  static const double workSpeedParking = 8.0;     // km/s - Park alanı temizleme (daha yavaş)
  static const double workSpeedHandreinigung = 5.0; // km/s - Manuel temizlik (en yavaş)
  
  // ==================== SABİT SÜRELER ====================
  
  static const int parkingTime = 2;               // Dakika - Park etme
  static const int equipmentPrepTime = 2;         // Dakika - Ekipman hazırlama
  static const int locationFindingTime = 1;       // Dakika - Lokasyon bulma
  
  // ==================== STANDART SAPMALAR ====================
  
  static const double trafficVariance = 0.15;     // %15 sapma (trafik değişkenliği)
  static const double workVariance = 0.20;        // %20 sapma (iş verimliliği)
  
  /// Toplam süre tahmini (Yol + Temizleme + Sabit süreler + Varyans)
  static int estimateTotalMinutes({
    required Location location,
    required double distanceKm,
    bool includeVariance = true,
  }) {
    // 1. Yol süresi
    final travelMinutes = _calculateTravelTime(distanceKm, includeVariance);
    
    // 2. Temizleme süresi
    final workMinutes = _calculateWorkTime(location, includeVariance);
    
    // 3. Sabit süreler
    final fixedMinutes = parkingTime + equipmentPrepTime + locationFindingTime;
    
    // 4. Toplam
    final totalMinutes = travelMinutes + workMinutes + fixedMinutes;
    
    return totalMinutes.round();
  }
  
  /// Sadece temizleme süresi (Alan için)
  static int estimateWorkMinutes(Location location, {bool includeVariance = true}) {
    return _calculateWorkTime(location, includeVariance).round();
  }
  
  /// Yol süresi hesapla (Mesafeye göre)
  static double _calculateTravelTime(double distanceKm, bool includeVariance) {
    if (distanceKm <= 0) return 0.0;
    
    // Temel süre (saat cinsinden)
    double timeInHours = distanceKm / trafficSpeed;
    
    // Dakikaya çevir
    double timeInMinutes = timeInHours * 60;
    
    // Varyans ekle (trafik değişkenliği)
    if (includeVariance) {
      timeInMinutes = _applyVariance(timeInMinutes, trafficVariance);
    }
    
    return timeInMinutes;
  }
  
  /// Temizleme süresi hesapla (Alan ve cluster tipine göre)
  static double _calculateWorkTime(Location location, bool includeVariance) {
    final clusterType = location.clusterLabel.toUpperCase();
    final workAreas = location.workAreas;
    
    double timeInMinutes = 0.0;
    
    if (clusterType.startsWith('MFILE')) {
      // M-File: Gehwege temizleme
      final areaKm2 = (workAreas.gehwege1 + workAreas.gehwege15) / 1_000_000;
      timeInMinutes = (areaKm2 / workSpeedGehwege) * 60;
      
    } else if (clusterType.startsWith('HFILE')) {
      // H-File: Manuel temizlik (en yavaş)
      final areaKm2 = workAreas.handreinigung / 1_000_000;
      timeInMinutes = (areaKm2 / workSpeedHandreinigung) * 60;
      
    } else if (clusterType.startsWith('UFILE')) {
      // U-File: Park alanları
      final areaKm2 = (workAreas.parkingSpacesSurface + workAreas.parkingSpacesPaths) / 1_000_000;
      timeInMinutes = (areaKm2 / workSpeedParking) * 60;
      
    } else {
      // Bilinmeyen cluster: Tüm alanlar, ortalama hız
      final totalAreaKm2 = location.relevantArea / 1_000_000;
      timeInMinutes = (totalAreaKm2 / workSpeedGehwege) * 60;
    }
    
    // Varyans ekle (verimlilik değişkenliği)
    if (includeVariance) {
      timeInMinutes = _applyVariance(timeInMinutes, workVariance);
    }
    
    // Minimum 3 dakika (çok küçük alanlar için)
    if (timeInMinutes < 3) {
      timeInMinutes = 3;
    }
    
    return timeInMinutes;
  }
  
  /// Standart sapma uygula (Gerçekçi tahmin için)
  static double _applyVariance(double value, double varianceRate) {
    // Normal distribution'a yakın bir varyans
    // %15 sapma = ±%7.5 arasında değişim
    final random = math.Random();
    final variance = random.nextDouble() * varianceRate * 2 - varianceRate;
    return value * (1 + variance);
  }
  
  /// Saat dilimine göre trafik çarpanı
  static double getTrafficMultiplier() {
    final hour = DateTime.now().hour;
    
    // Sabah trafiği (7-9): %30 daha yavaş
    if (hour >= 7 && hour <= 9) {
      return 1.3;
    }
    // Akşam trafiği (17-19): %40 daha yavaş
    else if (hour >= 17 && hour <= 19) {
      return 1.4;
    }
    // Öğle (12-14): %10 daha yavaş
    else if (hour >= 12 && hour <= 14) {
      return 1.1;
    }
    // Gece (22-6): %20 daha hızlı
    else if (hour >= 22 || hour <= 6) {
      return 0.8;
    }
    // Normal
    return 1.0;
  }
  
  /// Mesafeye göre yol süresi (Trafik çarpanı ile)
  static int estimateTravelMinutes(double distanceKm) {
    if (distanceKm <= 0) return 0;
    
    final baseTime = (distanceKm / trafficSpeed) * 60;
    final trafficMultiplier = getTrafficMultiplier();
    final adjustedTime = baseTime * trafficMultiplier;
    
    return adjustedTime.round();
  }
  
  /// Toplam süreyi formatla (Saat + Dakika)
  static String formatDuration(int minutes) {
    if (minutes < 1) {
      return '< 1 dk';
    } else if (minutes < 60) {
      return '$minutes dk';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '${hours}s';
      }
      return '${hours}s ${mins}dk';
    }
  }
  
  /// Tahmini bitiş saatini hesapla
  static DateTime estimateFinishTime(int totalMinutes) {
    return DateTime.now().add(Duration(minutes: totalMinutes));
  }
  
  /// Bitiş saatini formatla
  static String formatFinishTime(DateTime finishTime) {
    return '${finishTime.hour}:${finishTime.minute.toString().padLeft(2, '0')}';
  }
}

