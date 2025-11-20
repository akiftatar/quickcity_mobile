import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  static const String _currentUserIdKey = 'current_user_id';
  static const String _sessionEmailKey = 'session_email';
  static const String _sessionPasswordKey = 'session_password';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ApiService _apiService;
  
  User? _currentUser;
  String? _token;
  bool _rememberMe = false;
  bool _isRefreshingToken = false;
  Completer<bool>? _refreshCompleter;

  AuthService(this._apiService) {
    _apiService.unauthorizedHandler = _handleUnauthorized;
  }

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _currentUser != null;
  bool get rememberMe => _rememberMe;

  // Login
  Future<Map<String, dynamic>> login(String email, String password, {bool rememberMe = false}) async {
    try {
      final result = await _apiService.login(email, password);
      
      if (result['success'] == true) {
        await _applyLoginResult(
          user: result['user'],
          token: result['token'],
          email: email,
          password: password,
          rememberMe: rememberMe,
        );
        
        return {
          'success': true,
          'user': _currentUser,
          'message': result['message'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Giriş sırasında hata oluştu: $e',
      };
    }
  }

  // Logout
  Future<Map<String, dynamic>> logout() async {
    try {
      // API'den logout yap
      await _apiService.logout();
      
      // Beni hatırla durumunu kontrol et
      final prefs = await SharedPreferences.getInstance();
      final shouldRemember = prefs.getBool(_rememberMeKey) ?? false;
      
      // Local verileri temizle
      _currentUser = null;
      _token = null;
      _rememberMe = false;
      
      // Güvenli depolamadan token'ı sil
      await _secureStorage.delete(key: _tokenKey);
      
      // SharedPreferences'tan kullanıcı verilerini sil
      await prefs.remove(_userKey);
      await prefs.remove(_currentUserIdKey);
      
      // Beni hatırla işaretli değilse, kayıtlı email/password'u da temizle
      if (!shouldRemember) {
        await _secureStorage.delete(key: _savedEmailKey);
        await _secureStorage.delete(key: _savedPasswordKey);
        await prefs.remove(_rememberMeKey);
      }
      
      await _clearSessionCredentials();
      _apiService.clearToken();
      await OfflineStorageService.setUserContext(null);
      
      notifyListeners();
      
      return {
        'success': true,
        'message': 'Çıkış başarılı',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Çıkış sırasında hata oluştu: $e',
      };
    }
  }

  // Uygulama başlatıldığında oturum kontrolü
  Future<bool> checkAuthStatus() async {
    try {
      // Token'ı güvenli depolamadan al
      _token = await _secureStorage.read(key: _tokenKey);
      
      if (_token != null) {
        // Kullanıcı verilerini al
        _currentUser = await _getUserData();
        
        if (_currentUser != null) {
          await OfflineStorageService.setUserContext(_currentUser!.id);
          // API service'e token'ı set et
          _apiService.setToken(_token!);
          
          // Beni hatırla durumunu yükle
          final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserIdKey, _currentUser!.id);
          _rememberMe = prefs.getBool(_rememberMeKey) ?? false;
          
          notifyListeners();
          return true;
        } else {
          // Kullanıcı verisi yok, token'ı temizle
          await _secureStorage.delete(key: _tokenKey);
          _token = null;
          notifyListeners();
          return false;
        }
      }
      
      // Token yok, beni hatırla kontrolü yap
      final prefs = await SharedPreferences.getInstance();
      final shouldRemember = prefs.getBool(_rememberMeKey) ?? false;
      
      if (shouldRemember) {
        // Kayıtlı email ve password'u al
        final savedEmail = await _secureStorage.read(key: _savedEmailKey);
        final savedPassword = await _secureStorage.read(key: _savedPasswordKey);
        
        if (savedEmail != null && savedPassword != null) {
          // Otomatik giriş yap
          final result = await login(savedEmail, savedPassword, rememberMe: true);
          return result['success'] == true;
        }
      }
      
      return false;
    } catch (e) {
      // Auth status check error: $e
      return false;
    }
  }

  // Kullanıcı verilerini kaydet
  Future<void> _saveUserData(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = user.toJson();
      await prefs.setString(_userKey, jsonEncode(userJson));
    } catch (e) {
      // User data save error: $e
    }
  }

  // Kullanıcı verilerini al
  Future<User?> _getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonString = prefs.getString(_userKey);
      
      if (userJsonString != null) {
        // JSON string'i parse et
        final userJson = jsonDecode(userJsonString) as Map<String, dynamic>;
        return User.fromJson(userJson);
      }
      
      return null;
    } catch (e) {
      // User data get error: $e
      return null;
    }
  }

  // Token'ı kontrol et (logout etmeden)
  Future<bool> checkTokenValidity() async {
    try {
      if (_token != null) {
        // Token'ın geçerli olup olmadığını test et
        final result = await _apiService.getUserAssignments();
        if (result['success'] == true) {
          print('✅ Token hala geçerli');
          return true;
        } else {
          print('⚠️ Token geçersiz, sessiz yenileme denenecek');
          return await _silentLogin();
        }
      }
      return false;
    } catch (e) {
      print('⚠️ Token kontrol hatası: $e - Sessiz yenileme denenecek');
      return await _silentLogin();
    }
  }

  // Kullanıcı bilgilerini güncelle
  void updateUser(User user) {
    _currentUser = user;
    _saveUserData(user);
    notifyListeners();
  }

  // Kayıtlı email'i al (beni hatırla için)
  Future<String?> getSavedEmail() async {
    try {
      return await _secureStorage.read(key: _savedEmailKey);
    } catch (e) {
      return null;
    }
  }

  // Kayıtlı password'u al (beni hatırla için)
  Future<String?> getSavedPassword() async {
    try {
      return await _secureStorage.read(key: _savedPasswordKey);
    } catch (e) {
      return null;
    }
  }

  // Beni hatırla durumunu al
  Future<bool> getRememberMeStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _applyLoginResult({
    required User user,
    required String token,
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _currentUser = user;
    _token = token;
    _rememberMe = rememberMe;
    
    await _secureStorage.write(key: _tokenKey, value: _token);
    await _secureStorage.write(key: _sessionEmailKey, value: email);
    await _secureStorage.write(key: _sessionPasswordKey, value: password);
    await _saveUserData(user);
    await OfflineStorageService.setUserContext(user.id);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);
    await prefs.setString(_currentUserIdKey, user.id);
    
    if (rememberMe) {
      await _secureStorage.write(key: _savedEmailKey, value: email);
      await _secureStorage.write(key: _savedPasswordKey, value: password);
    } else {
      await _secureStorage.delete(key: _savedEmailKey);
      await _secureStorage.delete(key: _savedPasswordKey);
    }
    
    _apiService.setToken(token);
    notifyListeners();
  }

  Future<void> _clearSessionCredentials() async {
    await _secureStorage.delete(key: _sessionEmailKey);
    await _secureStorage.delete(key: _sessionPasswordKey);
  }

  Future<bool> _silentLogin() async {
    if (_isRefreshingToken) {
      return await (_refreshCompleter?.future ?? Future.value(false));
    }
    
    final email = await _secureStorage.read(key: _sessionEmailKey);
    final password = await _secureStorage.read(key: _sessionPasswordKey);
    
    if (email == null || password == null) {
      return false;
    }
    
    _isRefreshingToken = true;
    _refreshCompleter = Completer<bool>();
    
    try {
      final result = await _apiService.login(email, password);
      if (result['success'] == true) {
        await _applyLoginResult(
          user: result['user'],
          token: result['token'],
          email: email,
          password: password,
          rememberMe: _rememberMe,
        );
        _refreshCompleter?.complete(true);
        return true;
      } else {
        _refreshCompleter?.complete(false);
        await _clearSessionCredentials();
        return false;
      }
    } catch (e) {
      _refreshCompleter?.complete(false);
      return false;
    } finally {
      _isRefreshingToken = false;
      _refreshCompleter = null;
    }
  }

  Future<void> _handleUnauthorized() async {
    if (!isLoggedIn) {
      return;
    }
    
    final success = await _silentLogin();
    if (!success) {
      print('❌ Sessiz yeniden giriş başarısız, kullanıcı çıkarılıyor');
      _currentUser = null;
      _token = null;
      await _secureStorage.delete(key: _tokenKey);
      await _clearSessionCredentials();
      await OfflineStorageService.setUserContext(null);
      notifyListeners();
    }
  }
}
