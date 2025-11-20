import 'package:flutter_test/flutter_test.dart';
import 'package:quickcity_mobile/models/location.dart';

void main() {
  group('Location Model Tests', () {
    
    test('Location.fromJson doğru şekilde parse edilmeli', () {
      final json = {
        'id': 1,
        'assignment_id': 'abc-123',
        'lat': 52.5200,
        'lng': 13.4050,
        'street': 'Unter den Linden',
        'city': 'Berlin',
        'state': 'Berlin',
        'zip': '10117',
        'formatted_address': 'Unter den Linden, 10117 Berlin',
        'cluster_label': 'MFILE-1',
        'work_areas': {
          'gehwege_1': 100.0,
          'gehwege_1_5': 50.0,
          'parking_spaces_surface': 75.0,
          'parking_spaces_paths': 25.0,
          'handreinigung': 30.0,
        },
        'attachments': [],
        'assigned_at': '2024-01-01T00:00:00Z',
        'waypoint_index': 1,
        'is_routed': true,
      };

      final location = Location.fromJson(json);

      expect(location.id, 1);
      expect(location.assignmentId, 'abc-123');
      expect(location.lat, 52.5200);
      expect(location.lng, 13.4050);
      expect(location.street, 'Unter den Linden');
      expect(location.city, 'Berlin');
      expect(location.clusterLabel, 'MFILE-1');
      expect(location.waypointIndex, 1);
      expect(location.isRouted, true);
    });

    test('displayAddress formattedAddress varsa onu döndürmeli', () {
      final location = Location(
        id: 1,
        lat: 52.5200,
        lng: 13.4050,
        formattedAddress: 'Test Address, Berlin',
        clusterLabel: 'MFILE-1',
        workAreas: WorkAreas(
          gehwege1: 0,
          gehwege15: 0,
          parkingSpacesSurface: 0,
          parkingSpacesPaths: 0,
          handreinigung: 0,
        ),
        attachments: [],
        assignedAt: '',
      );

      expect(location.displayAddress, 'Test Address, Berlin');
    });

    test('displayAddress formattedAddress yoksa street, city, zip birleştirmeli', () {
      final location = Location(
        id: 1,
        lat: 52.5200,
        lng: 13.4050,
        street: 'Unter den Linden',
        city: 'Berlin',
        zip: '10117',
        clusterLabel: 'MFILE-1',
        workAreas: WorkAreas(
          gehwege1: 0,
          gehwege15: 0,
          parkingSpacesSurface: 0,
          parkingSpacesPaths: 0,
          handreinigung: 0,
        ),
        attachments: [],
        assignedAt: '',
      );

      expect(location.displayAddress, 'Unter den Linden, Berlin, 10117');
    });

    test('displayAddress hiçbir bilgi yoksa varsayılan mesaj döndürmeli', () {
      final location = Location(
        id: 1,
        lat: 52.5200,
        lng: 13.4050,
        clusterLabel: 'MFILE-1',
        workAreas: WorkAreas(
          gehwege1: 0,
          gehwege15: 0,
          parkingSpacesSurface: 0,
          parkingSpacesPaths: 0,
          handreinigung: 0,
        ),
        attachments: [],
        assignedAt: '',
      );

      expect(location.displayAddress, 'Adres bilgisi yok');
    });
  });

  group('WorkAreas Tests', () {
    
    test('MFILE cluster için sadece gehwege alanlarını döndürmeli', () {
      final workAreas = WorkAreas(
        gehwege1: 100.0,
        gehwege15: 50.0,
        parkingSpacesSurface: 75.0,
        parkingSpacesPaths: 25.0,
        handreinigung: 30.0,
      );

      final relevantArea = workAreas.getRelevantArea('MFILE-1');

      expect(relevantArea, 150.0); // 100 + 50
    });

    test('HFILE cluster için sadece handreinigung döndürmeli', () {
      final workAreas = WorkAreas(
        gehwege1: 100.0,
        gehwege15: 50.0,
        parkingSpacesSurface: 75.0,
        parkingSpacesPaths: 25.0,
        handreinigung: 30.0,
      );

      final relevantArea = workAreas.getRelevantArea('HFILE-2');

      expect(relevantArea, 30.0);
    });

    test('UFILE cluster için park alanlarını döndürmeli', () {
      final workAreas = WorkAreas(
        gehwege1: 100.0,
        gehwege15: 50.0,
        parkingSpacesSurface: 75.0,
        parkingSpacesPaths: 25.0,
        handreinigung: 30.0,
      );

      final relevantArea = workAreas.getRelevantArea('UFILE-3');

      expect(relevantArea, 100.0); // 75 + 25
    });

    test('Bilinmeyen cluster için tüm alanları toplamalı', () {
      final workAreas = WorkAreas(
        gehwege1: 100.0,
        gehwege15: 50.0,
        parkingSpacesSurface: 75.0,
        parkingSpacesPaths: 25.0,
        handreinigung: 30.0,
      );

      final relevantArea = workAreas.getRelevantArea('UNKNOWN-1');

      expect(relevantArea, 280.0); // Hepsinin toplamı
    });

    test('totalArea tüm alanları toplar', () {
      final workAreas = WorkAreas(
        gehwege1: 100.0,
        gehwege15: 50.0,
        parkingSpacesSurface: 75.0,
        parkingSpacesPaths: 25.0,
        handreinigung: 30.0,
      );

      expect(workAreas.totalArea, 280.0);
    });

    test('WorkAreas.fromJson güvenli double parsing yapmalı', () {
      final json = {
        'gehwege_1': '100.5', // String
        'gehwege_1_5': 50, // Integer
        'parking_spaces_surface': 75.5, // Double
        'parking_spaces_paths': null, // Null
        'handreinigung': 'invalid', // Geçersiz string
      };

      final workAreas = WorkAreas.fromJson(json);

      expect(workAreas.gehwege1, 100.5);
      expect(workAreas.gehwege15, 50.0);
      expect(workAreas.parkingSpacesSurface, 75.5);
      expect(workAreas.parkingSpacesPaths, 0.0); // Null -> 0
      expect(workAreas.handreinigung, 0.0); // Invalid -> 0
    });
  });

  group('Location Parsing Tests', () {
    
    test('Güvenli int parsing çalışmalı', () {
      final json = <String, dynamic>{
        'id': '123', // String
        'lat': 52.5200,
        'lng': 13.4050,
        'cluster_label': 'MFILE-1',
        'work_areas': <String, dynamic>{},
        'attachments': [],
        'assigned_at': '',
      };

      final location = Location.fromJson(json);

      expect(location.id, 123);
    });

    test('Güvenli double parsing çalışmalı', () {
      final json = <String, dynamic>{
        'id': 1,
        'lat': '52.5200', // String
        'lng': 13, // Integer
        'cluster_label': 'MFILE-1',
        'work_areas': <String, dynamic>{},
        'attachments': [],
        'assigned_at': '',
      };

      final location = Location.fromJson(json);

      expect(location.lat, 52.5200);
      expect(location.lng, 13.0);
    });

    test('Attachments array olarak parse edilmeli', () {
      final json = <String, dynamic>{
        'id': 1,
        'lat': 52.5200,
        'lng': 13.4050,
        'cluster_label': 'MFILE-1',
        'work_areas': <String, dynamic>{},
        'attachments': ['file1.pdf', 'file2.pdf'],
        'assigned_at': '',
      };

      final location = Location.fromJson(json);

      expect(location.attachments, ['file1.pdf', 'file2.pdf']);
    });

    test('Attachments string ise tek elemanlı liste olmalı', () {
      final json = <String, dynamic>{
        'id': 1,
        'lat': 52.5200,
        'lng': 13.4050,
        'cluster_label': 'MFILE-1',
        'work_areas': <String, dynamic>{},
        'attachments': 'single_file.pdf', // String
        'assigned_at': '',
      };

      final location = Location.fromJson(json);

      expect(location.attachments, ['single_file.pdf']);
    });

    test('Attachments null ise boş liste olmalı', () {
      final json = <String, dynamic>{
        'id': 1,
        'lat': 52.5200,
        'lng': 13.4050,
        'cluster_label': 'MFILE-1',
        'work_areas': <String, dynamic>{},
        'attachments': null,
        'assigned_at': '',
      };

      final location = Location.fromJson(json);

      expect(location.attachments, isEmpty);
    });
  });
}

