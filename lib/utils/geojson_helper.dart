import 'package:latlong2/latlong.dart';
import '../models/location_drawing.dart';

class GeoJsonHelper {
  /// GeoJSON Feature'dan LatLng listesi çıkar (tek bir liste döner)
  static List<LatLng> extractCoordinates(Map<String, dynamic> geojson) {
    final List<LatLng> coordinates = [];
    
    try {
      final geometry = geojson['geometry'];
      if (geometry == null) return coordinates;
      
      final geometryType = geometry['type']?.toString().toLowerCase();
      final coords = geometry['coordinates'];
      
      if (coords == null) return coordinates;
      
      switch (geometryType) {
        case 'point':
          if (coords is List && coords.length >= 2) {
            final lat = _safeDouble(coords[1]);
            final lng = _safeDouble(coords[0]);
            if (isValidCoordinate(lat, lng)) {
              coordinates.add(LatLng(lat, lng));
            } else {
              print('⚠️ Geçersiz koordinat atlandı: lat=$lat, lng=$lng');
            }
          }
          break;
          
        case 'linestring':
          if (coords is List) {
            for (final coord in coords) {
              if (coord is List && coord.length >= 2) {
                final lat = _safeDouble(coord[1]);
                final lng = _safeDouble(coord[0]);
                if (isValidCoordinate(lat, lng)) {
                  coordinates.add(LatLng(lat, lng));
                } else {
                  print('⚠️ Geçersiz koordinat atlandı: lat=$lat, lng=$lng');
                }
              }
            }
          }
          break;
          
        case 'multilinestring':
          // MultiLineString için tüm line string'leri birleştir
          if (coords is List) {
            for (final lineString in coords) {
              if (lineString is List) {
                for (final coord in lineString) {
                  if (coord is List && coord.length >= 2) {
                    final lat = _safeDouble(coord[1]);
                    final lng = _safeDouble(coord[0]);
                    if (isValidCoordinate(lat, lng)) {
                      coordinates.add(LatLng(lat, lng));
                    } else {
                      print('⚠️ Geçersiz koordinat atlandı: lat=$lat, lng=$lng');
                    }
                  }
                }
              }
            }
          }
          break;
          
        case 'polygon':
          // Polygon'ın ilk ring'ini al (dış sınır)
          if (coords is List && coords.isNotEmpty) {
            final exteriorRing = coords[0];
            if (exteriorRing is List) {
              for (final coord in exteriorRing) {
                if (coord is List && coord.length >= 2) {
                  final lat = _safeDouble(coord[1]);
                  final lng = _safeDouble(coord[0]);
                  if (isValidCoordinate(lat, lng)) {
                    coordinates.add(LatLng(lat, lng));
                  } else {
                    print('⚠️ Geçersiz koordinat atlandı: lat=$lat, lng=$lng');
                  }
                }
              }
            }
          }
          break;
          
        case 'multipolygon':
          // MultiPolygon'ın ilk polygon'ının ilk ring'ini al
          if (coords is List && coords.isNotEmpty) {
            final firstPolygon = coords[0];
            if (firstPolygon is List && firstPolygon.isNotEmpty) {
              final exteriorRing = firstPolygon[0];
              if (exteriorRing is List) {
                for (final coord in exteriorRing) {
                  if (coord is List && coord.length >= 2) {
                    final lat = _safeDouble(coord[1]);
                    final lng = _safeDouble(coord[0]);
                    if (isValidCoordinate(lat, lng)) {
                      coordinates.add(LatLng(lat, lng));
                    } else {
                      print('⚠️ Geçersiz koordinat atlandı: lat=$lat, lng=$lng');
                    }
                  }
                }
              }
            }
          }
          break;
      }
    } catch (e) {
      print('GeoJSON parse hatası: $e');
    }
    
    return coordinates;
  }

  /// MultiLineString için her bir LineString'i ayrı liste olarak döndür
  static List<List<LatLng>> extractMultiLineStringCoordinates(Map<String, dynamic> geojson) {
    final List<List<LatLng>> lineStrings = [];
    
    try {
      final geometry = geojson['geometry'];
      if (geometry == null) return lineStrings;
      
      final geometryType = geometry['type']?.toString().toLowerCase();
      if (geometryType != 'multilinestring') {
        // Eğer MultiLineString değilse, tek bir LineString olarak döndür
        final coords = extractCoordinates(geojson);
        if (coords.isNotEmpty) {
          lineStrings.add(coords);
        }
        return lineStrings;
      }
      
      final coords = geometry['coordinates'];
      if (coords is List) {
        for (final lineString in coords) {
          if (lineString is List) {
            final List<LatLng> points = [];
            for (final coord in lineString) {
              if (coord is List && coord.length >= 2) {
                final lat = _safeDouble(coord[1]);
                final lng = _safeDouble(coord[0]);
                if (isValidCoordinate(lat, lng)) {
                  points.add(LatLng(lat, lng));
                } else {
                  print('⚠️ Geçersiz koordinat atlandı: lat=$lat, lng=$lng');
                }
              }
            }
            if (points.length >= 2) {
              lineStrings.add(points);
            }
          }
        }
      }
    } catch (e) {
      print('MultiLineString parse hatası: $e');
    }
    
    return lineStrings;
  }

  /// Hex renk kodunu Color'a çevir
  static int hexToColorInt(String hexColor) {
    try {
      // # işaretini kaldır
      String hex = hexColor.replaceAll('#', '');
      
      // Eğer 3 karakterli ise 6 karaktere çevir (#RGB -> #RRGGBB)
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      
      // Alpha değeri ekle (FF = tam opak)
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      
      return int.parse(hex, radix: 16);
    } catch (e) {
      print('Renk parse hatası: $e, hex: $hexColor');
      // Varsayılan siyah
      return 0xFF000000;
    }
  }

  /// Güvenli double parsing
  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Koordinatın geçerli WGS84 enlem/boylam aralığında olup olmadığını kontrol et
  static bool isValidCoordinate(double lat, double lng) {
    // Enlem: -90 ile 90 arasında olmalı
    // Boylam: -180 ile 180 arasında olmalı
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Çizim tipine göre geometry tipini belirle
  static String getGeometryType(LocationDrawing drawing) {
    final geometry = drawing.geojson['geometry'];
    if (geometry != null && geometry['type'] != null) {
      return geometry['type'].toString().toLowerCase();
    }
    return drawing.type.toLowerCase();
  }

  /// Çizim tipine göre çizim yapılabilir mi kontrol et
  static bool canDraw(LocationDrawing drawing) {
    if (!drawing.isVisible) return false;
    
    final geometryType = getGeometryType(drawing);
    return ['point', 'linestring', 'multilinestring', 'polygon', 'multipolygon']
        .contains(geometryType);
  }
}

