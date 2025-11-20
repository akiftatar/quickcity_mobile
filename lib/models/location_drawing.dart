import 'dart:convert';
import 'location.dart';

class LocationDrawing {
  final int id;
  final int locationId;
  final String name;
  final String? description;
  final String type; // 'line', 'polygon', 'point'
  final Map<String, dynamic> geojson;
  final String color;
  final String? serviceType; // 'machine', 'hand'
  final double strokeWidth;
  final double opacity;
  final Map<String, dynamic>? properties;
  final double? length;
  final double? area;
  final double? calculatedValue;
  final bool isVisible;
  final String? createdAt;
  final String? updatedAt;
  final Location? location;

  LocationDrawing({
    required this.id,
    required this.locationId,
    required this.name,
    this.description,
    required this.type,
    required this.geojson,
    required this.color,
    this.serviceType,
    required this.strokeWidth,
    required this.opacity,
    this.properties,
    this.length,
    this.area,
    this.calculatedValue,
    required this.isVisible,
    this.createdAt,
    this.updatedAt,
    this.location,
  });

  factory LocationDrawing.fromJson(Map<String, dynamic> json) {
    // GeoJSON parse et
    Map<String, dynamic> geojsonData = {};
    if (json['geojson'] != null) {
      if (json['geojson'] is String) {
        // String ise JSON parse et
        try {
          geojsonData = jsonDecode(json['geojson']) as Map<String, dynamic>;
        } catch (e) {
          print('GeoJSON parse hatası: $e');
          geojsonData = {};
        }
      } else if (json['geojson'] is Map) {
        geojsonData = json['geojson'] as Map<String, dynamic>;
      }
    }

    // Properties parse et
    Map<String, dynamic>? propertiesData;
    if (json['properties'] != null) {
      if (json['properties'] is String) {
        try {
          propertiesData = jsonDecode(json['properties']) as Map<String, dynamic>;
        } catch (e) {
          print('Properties parse hatası: $e');
        }
      } else if (json['properties'] is Map) {
        propertiesData = json['properties'] as Map<String, dynamic>;
      }
    }

    return LocationDrawing(
      id: _safeInt(json['id']),
      locationId: _safeInt(json['location_id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? 'line',
      geojson: geojsonData,
      color: json['color']?.toString() ?? '#000000',
      serviceType: json['service_type']?.toString(),
      strokeWidth: _safeDouble(json['stroke_width']),
      opacity: _safeDouble(json['opacity']),
      properties: propertiesData,
      length: json['length'] != null ? _safeDouble(json['length']) : null,
      area: json['area'] != null ? _safeDouble(json['area']) : null,
      calculatedValue: json['calculated_value'] != null ? _safeDouble(json['calculated_value']) : null,
      isVisible: json['is_visible'] == 1 || json['is_visible'] == true,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      location: json['location'] != null ? Location.fromJson(json['location']) : null,
    );
  }

  // Güvenli int parsing
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Güvenli double parsing
  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location_id': locationId,
      'name': name,
      'description': description,
      'type': type,
      'geojson': geojson,
      'color': color,
      'service_type': serviceType,
      'stroke_width': strokeWidth,
      'opacity': opacity,
      'properties': properties,
      'length': length,
      'area': area,
      'calculated_value': calculatedValue,
      'is_visible': isVisible,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'location': location?.toJson(),
    };
  }
}

