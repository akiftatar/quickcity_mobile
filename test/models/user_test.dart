import 'package:flutter_test/flutter_test.dart';
import 'package:quickcity_mobile/models/user.dart';

void main() {
  group('User Model Tests', () {
    
    // Test 1: JSON'dan User oluşturma
    test('User.fromJson doğru şekilde parse edilmeli', () {
      // Arrange (Hazırlık)
      final json = {
        'id': '123',
        'username': 'test_user',
        'firstname': 'Ahmet',
        'lastname': 'Yılmaz',
        'email': 'ahmet@test.com',
        'roles': [
          {'name': 'admin'}
        ],
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      // Act (Aksiyon)
      final user = User.fromJson(json);

      // Assert (Doğrulama)
      expect(user.id, '123');
      expect(user.username, 'test_user');
      expect(user.firstname, 'Ahmet');
      expect(user.lastname, 'Yılmaz');
      expect(user.fullName, 'Ahmet Yılmaz');
      expect(user.email, 'ahmet@test.com');
      expect(user.roles, ['admin']);
    });

    // Test 2: fullName getter
    test('fullName doğru birleştirilmeli', () {
      final user = User(
        id: '1',
        username: 'test',
        firstname: 'Mehmet',
        lastname: 'Demir',
        email: 'test@test.com',
        roles: [],
        createdAt: '',
        updatedAt: '',
      );

      expect(user.fullName, 'Mehmet Demir');
    });

    // Test 3: Admin rolü kontrolü
    test('isAdmin doğru çalışmalı', () {
      final adminUser = User(
        id: '1',
        username: 'admin',
        firstname: 'Admin',
        lastname: 'User',
        email: 'admin@test.com',
        roles: ['admin'],
        createdAt: '',
        updatedAt: '',
      );

      final normalUser = User(
        id: '2',
        username: 'user',
        firstname: 'Normal',
        lastname: 'User',
        email: 'user@test.com',
        roles: ['user'],
        createdAt: '',
        updatedAt: '',
      );

      expect(adminUser.isAdmin, true);
      expect(normalUser.isAdmin, false);
    });

    // Test 4: SuperAdmin rolü kontrolü
    test('isSuperAdmin doğru çalışmalı', () {
      final superAdminUser = User(
        id: '1',
        username: 'superadmin',
        firstname: 'Super',
        lastname: 'Admin',
        email: 'super@test.com',
        roles: ['superadmin'],
        createdAt: '',
        updatedAt: '',
      );

      expect(superAdminUser.isSuperAdmin, true);
      expect(superAdminUser.isAdmin, true); // SuperAdmin aynı zamanda admin
    });

    // Test 5: Büyük/küçük harf duyarsızlığı
    test('Role kontrolü case-insensitive olmalı', () {
      final user = User(
        id: '1',
        username: 'test',
        firstname: 'Test',
        lastname: 'User',
        email: 'test@test.com',
        roles: ['ADMIN'], // Büyük harf
        createdAt: '',
        updatedAt: '',
      );

      expect(user.isAdmin, true);
    });

    // Test 6: toJson doğru şekilde serialize edilmeli
    test('toJson doğru şekilde serialize edilmeli', () {
      final user = User(
        id: '123',
        username: 'test_user',
        firstname: 'Ahmet',
        lastname: 'Yılmaz',
        email: 'ahmet@test.com',
        roles: ['admin'],
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      final json = user.toJson();

      expect(json['id'], '123');
      expect(json['username'], 'test_user');
      expect(json['firstname'], 'Ahmet');
      expect(json['roles'], ['admin']);
    });

    // Test 7: Null değerler
    test('Null değerler handle edilmeli', () {
      final json = {
        'id': '123',
        'username': 'test',
        'firstname': 'Test',
        'lastname': 'User',
        'email': 'test@test.com',
        'roles': null, // Null role
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final user = User.fromJson(json);

      expect(user.roles, isEmpty); // Boş liste olmalı
      expect(user.isAdmin, false);
    });
  });
}

