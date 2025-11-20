import 'package:flutter_test/flutter_test.dart';
import 'package:quickcity_mobile/services/auth_service.dart';
import 'package:quickcity_mobile/services/api_service.dart';
import 'package:quickcity_mobile/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  // Test setup - Her test başlamadan önce çalışır
  setUp(() async {
    // SharedPreferences'ı test modunda başlat
    SharedPreferences.setMockInitialValues({});
    
    // FlutterSecureStorage mock (gerçek cihaz simülasyonu)
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AuthService Tests', () {
    
    test('Yeni AuthService başlangıçta login olmamış durumda olmalı', () {
      final authService = AuthService(ApiService());
      
      expect(authService.isLoggedIn, false);
      expect(authService.currentUser, isNull);
      expect(authService.token, isNull);
    });

    test('rememberMe varsayılan olarak false olmalı', () {
      final authService = AuthService(ApiService());
      
      expect(authService.rememberMe, false);
    });

    // Not: Gerçek login testi için API mock'u gerekir
    // Bu, integration test seviyesindedir
    // Burada sadece logic testleri yapıyoruz
  });

  group('User Role Tests', () {
    
    test('Admin kullanıcı isAdmin true dönmeli', () {
      final adminUser = User(
        id: '1',
        username: 'admin',
        firstname: 'Admin',
        lastname: 'User',
        email: 'admin@test.com',
        roles: ['admin'],
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(adminUser.isAdmin, true);
      expect(adminUser.isSuperAdmin, false);
      expect(adminUser.isUser, false);
    });

    test('SuperAdmin kullanıcı hem isAdmin hem isSuperAdmin true dönmeli', () {
      final superAdminUser = User(
        id: '1',
        username: 'superadmin',
        firstname: 'Super',
        lastname: 'Admin',
        email: 'super@test.com',
        roles: ['superadmin'],
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(superAdminUser.isSuperAdmin, true);
      expect(superAdminUser.isAdmin, true); // SuperAdmin aynı zamanda admin
      expect(superAdminUser.isUser, false);
    });

    test('Normal kullanıcı sadece isUser true dönmeli', () {
      final normalUser = User(
        id: '1',
        username: 'user',
        firstname: 'Normal',
        lastname: 'User',
        email: 'user@test.com',
        roles: ['user'],
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(normalUser.isUser, true);
      expect(normalUser.isAdmin, false);
      expect(normalUser.isSuperAdmin, false);
    });

    test('Birden fazla role olan kullanıcı', () {
      final multiRoleUser = User(
        id: '1',
        username: 'multi',
        firstname: 'Multi',
        lastname: 'Role',
        email: 'multi@test.com',
        roles: ['user', 'admin'],
        createdAt: '2024-01-01',
        updatedAt: '2024-01-01',
      );

      expect(multiRoleUser.isAdmin, true);
      expect(multiRoleUser.isUser, false); // isUser sadece user rolü varsa ve admin değilse
    });
  });
}

