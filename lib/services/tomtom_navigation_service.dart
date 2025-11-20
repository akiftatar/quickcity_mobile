import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TomTomNavigationService {
  TomTomNavigationService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  Future<TomTomRouteResult> calculateRoute({
    required double startLat,
    required double startLng,
    required double destinationLat,
    required double destinationLng,
    bool considerTraffic = true,
  }) async {
    final params = <String, String>{
      'instructionsType': 'text',
      'sectionType': 'traffic',
      'routeType': 'fastest',
      'traffic': considerTraffic ? 'true' : 'false',
      'travelMode': 'car',
      'vehicleCommercial': 'false',
      'avoid': 'unpavedRoads',
      'key': apiKey,
    };

    final uri = Uri.https(
      'api.tomtom.com',
      '/routing/1/calculateRoute/'
          '$startLat,$startLng:$destinationLat,$destinationLng/json',
      params,
    );

    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TomTomNavigationException(
        'TomTom route request failed (${response.statusCode})',
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TomTomRouteResult.fromJson(data);
  }

  void dispose() {
    _client.close();
  }
}

class TomTomNavigationException implements Exception {
  TomTomNavigationException(this.message, {this.body});

  final String message;
  final String? body;

  @override
  String toString() => body == null ? message : '$message: $body';
}

class TomTomRouteResult {
  TomTomRouteResult({
    required this.polyline,
    required this.instructions,
    required this.lengthInMeters,
    required this.travelTimeInSeconds,
    required this.trafficDelayInSeconds,
    this.departureTime,
    this.arrivalTime,
  });

  final List<LatLng> polyline;
  final List<TomTomInstruction> instructions;
  final int lengthInMeters;
  final int travelTimeInSeconds;
  final int trafficDelayInSeconds;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  int get totalTimeInSeconds => travelTimeInSeconds + trafficDelayInSeconds;

  factory TomTomRouteResult.fromJson(Map<String, dynamic> json) {
    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw TomTomNavigationException('No routes returned from TomTom');
    }

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? [];

    final List<LatLng> polyline = [];
    for (final leg in legs) {
      final legPoints =
          (leg as Map<String, dynamic>)['points'] as List<dynamic>? ?? [];
      for (final point in legPoints) {
        final map = point as Map<String, dynamic>;
        final lat = (map['latitude'] as num?)?.toDouble();
        final lng = (map['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          polyline.add(LatLng(lat, lng));
        }
      }
    }

    final guidance = route['guidance'] as Map<String, dynamic>? ?? {};
    final instructionsJson = guidance['instructions'] as List<dynamic>? ?? [];
    final instructions =
        instructionsJson
            .map(
              (item) =>
                  TomTomInstruction.fromJson(item as Map<String, dynamic>),
            )
            .toList();

    final summary = route['summary'] as Map<String, dynamic>? ?? {};

    return TomTomRouteResult(
      polyline: polyline,
      instructions: instructions,
      lengthInMeters: (summary['lengthInMeters'] as num?)?.toInt() ?? 0,
      travelTimeInSeconds:
          (summary['travelTimeInSeconds'] as num?)?.toInt() ?? 0,
      trafficDelayInSeconds:
          (summary['trafficDelayInSeconds'] as num?)?.toInt() ?? 0,
      departureTime: _parseDate(summary['departureTime']),
      arrivalTime: _parseDate(summary['arrivalTime']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class TomTomInstruction {
  TomTomInstruction({
    required this.message,
    required this.lengthInMeters,
    required this.travelTimeInSeconds,
    this.street,
    this.pointIndex,
  });

  final String message;
  final double lengthInMeters;
  final double travelTimeInSeconds;
  final String? street;
  final int? pointIndex;

  factory TomTomInstruction.fromJson(Map<String, dynamic> json) {
    return TomTomInstruction(
      message: json['message']?.toString() ?? '',
      lengthInMeters: (json['lengthInMeters'] as num?)?.toDouble() ?? 0,
      travelTimeInSeconds:
          (json['travelTimeInSeconds'] as num?)?.toDouble() ?? 0,
      street: json['street']?.toString(),
      pointIndex: (json['pointIndex'] as num?)?.toInt(),
    );
  }
}
