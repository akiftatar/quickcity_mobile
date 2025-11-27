import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user.dart';
import '../models/location.dart';
import '../models/issue.dart';
import '../models/location_drawing.dart';

class ApiService {
  static const String _baseUrl = 'http://212.91.237.42/api';
  late Dio _dio;
  String? _token;
  VoidCallback? _onUnauthorized;

  // Base URL getter
  String get baseUrl => _baseUrl;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Request interceptor - token ekleme
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token geçersiz, logout yap
          _token = null;
          _onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  // Token setter
  void setToken(String token) {
    _token = token;
  }

  // Token getter
  String? get token => _token;

  // Token temizle
  void clearToken() {
    _token = null;
  }

  // Unauthorized handler setter
  set unauthorizedHandler(VoidCallback? handler) {
    _onUnauthorized = handler;
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['token'] != null) {
          _token = data['token'];
          return {
            'success': true,
            'user': User.fromJson(data['user']),
            'token': data['token'],
            'message': data['message'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Giriş başarısız',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Logout
  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await _dio.post('/logout');
      _token = null;
      
      return {
        'success': true,
        'message': response.data['message'] ?? 'Çıkış başarılı',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Tüm lokasyonları getir - rotalanmış (admin/superadmin için cluster filtreli)
  Future<Map<String, dynamic>> getAllLocations({String? cluster}) async {
    try {
      // Cluster parametresini güvenli hale getir (trim + url encode)
      String? safeCluster = cluster?.trim();
      final queryParams = (safeCluster != null && safeCluster.isNotEmpty)
          ? '?cluster=${Uri.encodeQueryComponent(safeCluster)}'
          : '';
      final response = await _dio.get('/assignments/routed$queryParams');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          var locations = (data['data'] as List)
              .map((json) => Location.fromJson(json))
              .toList();

          // Eğer backend filtre uygulamadıysa, istemci tarafında cluster_label ile filtrele
          if (safeCluster != null && safeCluster.isNotEmpty) {
            locations = locations
                .where((loc) => loc.clusterLabel.toLowerCase() == safeCluster.toLowerCase())
                .toList();
          }
          
          // waypoint_index'e göre sırala
          locations.sort((a, b) {
            if (a.waypointIndex == null && b.waypointIndex == null) return 0;
            if (a.waypointIndex == null) return 1;
            if (b.waypointIndex == null) return -1;
            return a.waypointIndex!.compareTo(b.waypointIndex!);
          });

          return {
            'success': true,
            'locations': locations,
            'total': data['total'] ?? locations.length,
            'message': data['message'] ?? 'Lokasyonlar başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Lokasyonlar getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Cluster'ları lokasyonlardan çıkar
  Future<Map<String, dynamic>> getClusters() async {
    try {
      // Önce tüm lokasyonları çek (cluster filtresi olmadan)
      final response = await _dio.get('/assignments/routed');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final locations = data['data'] as List;
          
          // cluster_label'ları çıkar ve benzersiz yap
          final clusterSet = <String>{};
          for (final location in locations) {
            final clusterLabel = location['cluster_label']?.toString();
            if (clusterLabel != null && clusterLabel.isNotEmpty) {
              clusterSet.add(clusterLabel);
            }
          }
          
          final clusters = clusterSet.toList()..sort();

          return {
            'success': true,
            'clusters': clusters,
            'message': 'Cluster\'lar başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Cluster\'lar getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Kullanıcının atanmış lokasyonlarını getir (rotalanmış)
  Future<Map<String, dynamic>> getUserAssignmentsRouted() async {
    try {
      final response = await _dio.get('/assignments/routed');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          var locations = (data['data'] as List)
              .map((json) => Location.fromJson(json))
              .toList();
          
          // waypoint_index'e göre sırala
          locations.sort((a, b) {
            if (a.waypointIndex == null && b.waypointIndex == null) return 0;
            if (a.waypointIndex == null) return 1;
            if (b.waypointIndex == null) return -1;
            return a.waypointIndex!.compareTo(b.waypointIndex!);
          });

          return {
            'success': true,
            'locations': locations,
            'total': data['total'] ?? locations.length,
            'message': data['message'] ?? 'Lokasyonlar başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Lokasyonlar getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Kullanıcının atanmış lokasyonlarını getir (eski endpoint - geriye uyumluluk için)
  Future<Map<String, dynamic>> getUserAssignments() async {
    try {
      final response = await _dio.get('/assignments');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final locations = (data['data'] as List)
              .map((json) => Location.fromJson(json))
              .toList();

          return {
            'success': true,
            'locations': locations,
            'total': data['total'] ?? locations.length,
            'message': data['message'] ?? 'Lokasyonlar başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Lokasyonlar getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Belirli bir lokasyonun detaylarını getir
  Future<Map<String, dynamic>> getLocationDetails(int locationId) async {
    try {
      final response = await _dio.get('/assignments/location/$locationId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'location': Location.fromJson(data['data']),
            'message': data['message'] ?? 'Lokasyon detayları başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Lokasyon detayları getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Atama özetini getir
  Future<Map<String, dynamic>> getAssignmentSummary() async {
    try {
      final response = await _dio.get('/assignments/summary');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'summary': data['data'],
            'message': data['message'] ?? 'Atama özeti başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Atama özeti getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Dio hata yönetimi - Bu fonksiyon artık kullanılmıyor, hata mesajları UI'da işleniyor
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 401) {
          return 'Authentication error';
        } else if (e.response?.statusCode == 403) {
          return 'Access denied';
        } else if (e.response?.statusCode == 404) {
          return 'Page not found';
        } else if (e.response?.statusCode == 500) {
          return 'Server error';
        } else {
          return 'HTTP error: ${e.response?.statusCode}';
        }
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error';
      case DioExceptionType.badCertificate:
        return 'Certificate error';
      case DioExceptionType.unknown:
        return 'Unknown error: ${e.message}';
    }
  }

  // Sorun bildir
  Future<Map<String, dynamic>> reportIssue({
    required int locationId,
    required String description,
    required String priority,
    required List<File> images,
  }) async {
    try {
      final formData = FormData();
      
      // Temel veriler (backend'in beklediği alan isimleri)
      formData.fields.addAll([
        MapEntry('location_id', locationId.toString()),
        MapEntry('description', description),
        // Backend'de 'severity' olarak kaydediliyor
        MapEntry('severity', priority),
      ]);

      // Resimleri ekle (backend 'photos[]' bekliyor)
      for (int i = 0; i < images.length; i++) {
        formData.files.add(MapEntry(
          'photos[]',
          await MultipartFile.fromFile(
            images[i].path,
            filename: 'issue_photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ),
        ));
      }

      final response = await _dio.post('/issues', data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data['success'] == true) {
          try {
            return {
              'success': true,
              'issue': Issue.fromJson(data['data']),
              'message': data['message'] ?? 'Sorun başarıyla bildirildi',
            };
          } catch (parseError) {
            print('Issue parse error: $parseError');
            print('Response data: ${data['data']}');
            return {
              'success': false,
              'message': 'Veri işleme hatası: $parseError',
            };
          }
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Sorun bildirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      print('DioException in reportIssue: $e');
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      print('Unexpected error in reportIssue: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Sorunları listele
  Future<Map<String, dynamic>> getIssues({int? locationId}) async {
    try {
      final queryParams = locationId != null ? '?location_id=$locationId' : '';
      final response = await _dio.get('/issues$queryParams');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final issues = (data['data'] as List)
              .map((json) => Issue.fromJson(json))
              .toList();

          return {
            'success': true,
            'issues': issues,
            'total': data['total'] ?? issues.length,
            'message': data['message'] ?? 'Sorunlar başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Sorunlar getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Sorun detayı getir
  Future<Map<String, dynamic>> getIssue(int issueId) async {
    try {
      final response = await _dio.get('/issues/$issueId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'issue': Issue.fromJson(data['data']),
            'message': data['message'] ?? 'Sorun detayı başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Sorun detayı getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Sorun güncelle (sadece admin)
  Future<Map<String, dynamic>> updateIssue({
    required int issueId,
    String? status,
    String? priority,
    String? adminNotes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (status != null) data['status'] = status;
      if (priority != null) data['priority'] = priority;
      if (adminNotes != null) data['admin_notes'] = adminNotes;

      final response = await _dio.put('/issues/$issueId', data: data);

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return {
            'success': true,
            'issue': Issue.fromJson(responseData['data']),
            'message': responseData['message'] ?? 'Sorun başarıyla güncellendi',
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Sorun güncellenemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Sorun sil
  Future<Map<String, dynamic>> deleteIssue(int issueId) async {
    try {
      final response = await _dio.delete('/issues/$issueId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Sorun başarıyla silindi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Sorun silinemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // Sorun istatistikleri (sadece admin)
  Future<Map<String, dynamic>> getIssueStatistics() async {
    try {
      final response = await _dio.get('/issues/statistics');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'statistics': data['data'],
            'message': data['message'] ?? 'İstatistikler başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'İstatistikler getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // ==================== WORK SESSION ====================

  /// Aktif iş oturumunu getir
  Future<Map<String, dynamic>> getActiveWorkSession() async {
    try {
      final response = await _dio.get('/work-sessions/active');

      if (response.statusCode == 200) {
        final data = response.data;
        print('🔍 BACKEND RESPONSE (getActiveWorkSession):');
        print('   data.keys: ${data.keys}');
        print('   data[success]: ${data['success']}');
        if (data['data'] != null) {
          print('   data[data].keys: ${data['data'] is Map ? (data['data'] as Map).keys : 'NOT A MAP'}');
        }
        print('   location_logs: ${data['location_logs']}');
        print('   logs: ${data['logs']}');
        print('   data[data][logs]: ${data['data'] is Map ? (data['data'] as Map)['logs'] : 'N/A'}');
        print('   data[data][location_logs]: ${data['data'] is Map ? (data['data'] as Map)['location_logs'] : 'N/A'}');
        
        if (data['success'] == true) {
          // Log'ları farklı field'lardan da kontrol et
          List<dynamic> logs = [];
          if (data['location_logs'] != null && data['location_logs'] is List) {
            logs = data['location_logs'] as List;
          } else if (data['logs'] != null && data['logs'] is List) {
            logs = data['logs'] as List;
          } else if (data['data'] is Map) {
            final sessionData = data['data'] as Map;
            if (sessionData['location_logs'] != null && sessionData['location_logs'] is List) {
              logs = sessionData['location_logs'] as List;
            } else if (sessionData['logs'] != null && sessionData['logs'] is List) {
              logs = sessionData['logs'] as List;
            }
          }
          
          print('   ✅ Bulunan log sayısı: ${logs.length}');
          if (logs.isNotEmpty) {
            print('   İlk log örneği: ${logs.first}');
          }
          
          return {
            'success': true,
            'session': data['data'],
            'logs': logs,
            'message': data['message'] ?? 'Aktif oturum getirildi',
          };
        } else {
          // Aktif oturum yok
          return {
            'success': true,
            'session': null,
            'message': 'Aktif oturum yok',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      // 404 ise normal (aktif oturum yok)
      if (e.response?.statusCode == 404) {
        return {
          'success': true,
          'session': null,
          'message': 'Aktif oturum yok',
        };
      }
      
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// İş oturumu başlat
  Future<Map<String, dynamic>> startWorkSession({
    required int totalLocations,
    String? weatherNote,
  }) async {
    try {
      final requestData = {
        'notes': weatherNote ?? 'İş oturumu başlatıldı',
      };
      
      // DEBUG: Gönderilen veriyi konsola yazdır
      print('🔵 START WORK SESSION REQUEST:');
      print('URL: $_baseUrl/work-sessions');
      print('Method: POST');
      print('Token: ${_token != null ? "Var (${_token!.substring(0, 20)}...)" : "YOK!"}');
      print('Data: $requestData');
      
      final response = await _dio.post('/work-sessions', data: requestData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'session': data['data'],
            'message': data['message'] ?? 'İş oturumu başlatıldı',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'İş oturumu başlatılamadı',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      // DEBUG: Hata detaylarını yazdır
      print('🔴 START WORK SESSION ERROR:');
      print('Status Code: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      print('Error Type: ${e.type}');
      print('Error Message: ${e.message}');
      
      return {
        'success': false,
        'message': e.response?.data['message'] ?? _handleDioError(e),
        'error_details': e.response?.data,
      };
    } catch (e) {
      print('🔴 UNEXPECTED ERROR: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// İş oturumu bitir
  /// Toplu konum güncellemesi gönder (batch - 5 dakikalık veriler)
  Future<Map<String, dynamic>> sendBatchLocationUpdate({
    required String sessionId,
    required List<Map<String, dynamic>> locations,
  }) async {
    try {
      print('📤 Toplu konum gönderiliyor: ${locations.length} konum');
      
      final response = await _dio.post('/work-sessions/$sessionId/location-update/batch', data: {
        'locations': locations,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': true,
          'message': data['message'] ?? '${locations.length} konum güncellendi',
        };
      } else {
        print('🔴 Batch Location Update HTTP Error: ${response.statusCode}');
        print('Response Data: ${response.data}');
        return {
          'success': false,
          'message': 'Konum güncellenemedi: ${response.statusCode}',
          'error_details': response.data,
          'status_code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      // 422 hatası için detaylı log
      if (e.response?.statusCode == 422) {
        print('🔴 BATCH LOCATION UPDATE 422 VALIDATION ERROR:');
        print('Response Data: ${e.response?.data}');
        print('Request Data: ${locations.length} konum');
        if (locations.isNotEmpty) {
          print('İlk konum örneği: ${locations.first}');
          print('İlk konum keys: ${locations.first.keys}');
        }
      }
      
      return {
        'success': false,
        'message': _handleDioError(e),
        'error_details': e.response?.data,
        'status_code': e.response?.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Toplu konum güncelleme hatası: $e',
      };
    }
  }

  Future<Map<String, dynamic>> endWorkSession({
    required dynamic sessionId,  // String (UUID) veya int
    required int completedLocations,
    String? workNote,
  }) async {
    try {
      final response = await _dio.post('/work-sessions/$sessionId/end', data: {
        'notes': workNote ?? 'İş oturumu tamamlandı',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'session': data['data'],
            'message': data['message'] ?? 'İş oturumu tamamlandı',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'İş oturumu tamamlanamadı',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      // DEBUG: Hata detaylarını yazdır
      print('🔴 END WORK SESSION ERROR:');
      print('Status Code: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      
      // 422 hatası varsa özel mesaj
      String errorMessage = _handleDioError(e);
      if (e.response?.statusCode == 422) {
        errorMessage = e.response?.data['message'] ?? 'En az 1 lokasyona check-in/out yapmalısınız!';
      }
      
      return {
        'success': false,
        'message': errorMessage,
        'error_details': e.response?.data,
        'status_code': e.response?.statusCode,
      };
    } catch (e) {
      print('🔴 UNEXPECTED ERROR: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// Lokasyona check-in
  Future<Map<String, dynamic>> checkInLocation({
    required dynamic sessionId,  // String (UUID) veya int
    required int locationId,
    required String? assignmentId, // Backend assignment UUID
    required double lat,
    required double lng,
  }) async {
    try {
      final requestData = {
        'work_session_id': sessionId,
        'location_id': assignmentId ?? locationId, // Backend assignments.id bekliyor!
        'latitude': lat,
        'longitude': lng,
        'notes': 'Check-in yapıldı',
      };
      
      // DEBUG: Gönderilen veriyi konsola yazdır
      print('🔵 CHECK-IN REQUEST:');
      print('URL: $_baseUrl/location-logs/check-in');
      print('Method: POST');
      print('Data: $requestData');
      
      final response = await _dio.post('/location-logs/check-in', data: requestData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        print('✅ CHECK-IN SUCCESS: ${data['message']}');
        if (data['success'] == true) {
          return {
            'success': true,
            'log': data['data'],
            'message': data['message'] ?? 'Check-in başarılı',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Check-in başarısız',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      // DEBUG: Hata detaylarını yazdır
      print('🔴 CHECK-IN ERROR:');
      print('Status Code: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      print('Error Type: ${e.type}');
      
      return {
        'success': false,
        'message': e.response?.data['message'] ?? _handleDioError(e),
        'error_details': e.response?.data,
        'status_code': e.response?.statusCode,
      };
    } catch (e) {
      print('🔴 CHECK-IN UNEXPECTED ERROR: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// Lokasyondan check-out
  Future<Map<String, dynamic>> checkOutLocation({
    required dynamic logId,  // String (UUID) veya int
    required int durationMinutes,
    String? notes,
    double? lat,
    double? lng,
  }) async {
    try {
      double? latitude = lat;
      double? longitude = lng;
      
      // Check-out için mevcut konumu al (gerekirse)
      if (latitude == null || longitude == null) {
        try {
          final currentPosition = await Geolocator.getCurrentPosition();
          latitude = currentPosition.latitude;
          longitude = currentPosition.longitude;
        } catch (e) {
          print('⚠️ GPS alınamadı, mevcut değerler kullanılacak: $e');
        }
      }
      
      final requestData = {
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes ?? 'Check-out yapıldı',
      };
      
      // DEBUG: Gönderilen veriyi konsola yazdır
      print('🔵 CHECK-OUT REQUEST:');
      print('URL: $_baseUrl/location-logs/$logId/check-out');
      print('Method: POST');
      print('Log ID: $logId');
      print('Data: $requestData');
      
      final response = await _dio.post('/location-logs/$logId/check-out', data: requestData);

      if (response.statusCode == 200) {
        final data = response.data;
        print('✅ CHECK-OUT SUCCESS: ${data['message']}');
        if (data['success'] == true) {
          return {
            'success': true,
            'log': data['data'],
            'message': data['message'] ?? 'Check-out başarılı',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Check-out başarısız',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      // DEBUG: Hata detaylarını yazdır
      print('🔴 CHECK-OUT ERROR:');
      print('Status Code: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      print('Error Type: ${e.type}');
      
      return {
        'success': false,
        'message': e.response?.data['message'] ?? _handleDioError(e),
        'error_details': e.response?.data,
        'status_code': e.response?.statusCode,
      };
    } catch (e) {
      print('🔴 CHECK-OUT UNEXPECTED ERROR: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  // ==================== LOCATION DRAWINGS ====================

  /// Tüm çizimleri getir
  Future<Map<String, dynamic>> getAllDrawings({
    int? perPage,
    bool? visibleOnly,
    String? serviceType,
    int? page,
  }) async {
    try {
      final queryParams = <String>[];
      if (perPage != null) queryParams.add('per_page=$perPage');
      if (visibleOnly == true) queryParams.add('visible_only=1');
      if (serviceType != null && serviceType.isNotEmpty) {
        queryParams.add('service_type=${Uri.encodeQueryComponent(serviceType)}');
      }
      if (page != null) queryParams.add('page=$page');
      
      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final url = '/location-drawings$queryString';
      print('🔵 API Request: GET $url');
      
      final response = await _dio.get(url);

      print('🔵 API Response Status: ${response.statusCode}');
      print('🔵 API Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Backend'den gelen response formatını kontrol et
        // Eğer success field'ı yoksa ama data varsa, başarılı kabul et
        final hasSuccess = data['success'] == true;
        final hasData = data['data'] != null;
        
        print('🔵 Response check: hasSuccess=$hasSuccess, hasData=$hasData');
        
        if (hasSuccess || hasData) {
          final drawingsList = data['data'];
          print('🔵 Drawings data type: ${drawingsList.runtimeType}');
          print('🔵 Drawings count: ${drawingsList is List ? drawingsList.length : 'N/A'}');
          
          if (drawingsList is List) {
            final drawings = drawingsList
                .map((json) {
                  try {
                    return LocationDrawing.fromJson(json);
                  } catch (e) {
                    print('❌ Drawing parse hatası: $e');
                    print('❌ JSON: $json');
                    return null;
                  }
                })
                .whereType<LocationDrawing>()
                .toList();

            print('🔵 Parsed drawings count: ${drawings.length}');
            
            // Total değerini kontrol et - farklı field'larda olabilir
            int? total;
            if (data['total'] != null) {
              total = data['total'] is int ? data['total'] : int.tryParse(data['total'].toString());
            } else if (data['meta'] != null && data['meta']['total'] != null) {
              total = data['meta']['total'] is int ? data['meta']['total'] : int.tryParse(data['meta']['total'].toString());
            } else if (data['pagination'] != null && data['pagination']['total'] != null) {
              total = data['pagination']['total'] is int ? data['pagination']['total'] : int.tryParse(data['pagination']['total'].toString());
            }
            
            print('🔵 Total değeri: ${total ?? 'bulunamadı'} (data keys: ${data.keys.toList()})');
            
            return {
              'success': true,
              'drawings': drawings,
              'total': total,
              'message': data['message'] ?? 'Çizimler başarıyla getirildi',
            };
          } else {
            print('⚠️ Data is not a List: $drawingsList');
            return {
              'success': false,
              'message': 'Geçersiz veri formatı: data bir liste değil',
            };
          }
        } else {
          print('⚠️ API success=false ve data yok: ${data['message']}');
          return {
            'success': false,
            'message': data['message'] ?? 'Çizimler getirilemedi',
          };
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      print('❌ DioException: ${e.type}');
      print('❌ DioException message: ${e.message}');
      print('❌ DioException response: ${e.response?.data}');
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// Kullanıcıya atanmış çizimleri getir
  Future<Map<String, dynamic>> getUserAssignedDrawings({
    int? perPage,
    bool? visibleOnly,
    String? serviceType,
  }) async {
    try {
      final queryParams = <String>[];
      if (perPage != null) queryParams.add('per_page=$perPage');
      if (visibleOnly == true) queryParams.add('visible_only=1');
      if (serviceType != null && serviceType.isNotEmpty) {
        queryParams.add('service_type=${Uri.encodeQueryComponent(serviceType)}');
      }
      
      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final response = await _dio.get('/location-drawings/assigned$queryString');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final drawings = (data['data'] as List)
              .map((json) => LocationDrawing.fromJson(json))
              .toList();

          return {
            'success': true,
            'drawings': drawings,
            'total': data['total'] ?? drawings.length,
            'message': data['message'] ?? 'Çizimler başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Çizimler getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// Belirli bir lokasyonun çizimlerini getir
  Future<Map<String, dynamic>> getDrawingsByLocation(int locationId) async {
    try {
      final url = '/locations/$locationId/drawings';
      print('🔵 API Request: GET $url');
      
      final response = await _dio.get(url);

      print('🔵 API Response Status: ${response.statusCode}');
      print('🔵 API Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Backend'den gelen response formatını kontrol et
        // Eğer success field'ı yoksa ama data varsa, başarılı kabul et
        final hasSuccess = data['success'] == true;
        final hasData = data['data'] != null;
        
        print('🔵 Response check: hasSuccess=$hasSuccess, hasData=$hasData');
        
        if (hasSuccess || hasData) {
          final drawingsList = data['data'];
          print('🔵 Drawings data type: ${drawingsList.runtimeType}');
          
          if (drawingsList is List) {
            final drawings = drawingsList
                .map((json) {
                  try {
                    return LocationDrawing.fromJson(json);
                  } catch (e) {
                    print('❌ Drawing parse hatası: $e');
                    print('❌ JSON: $json');
                    return null;
                  }
                })
                .whereType<LocationDrawing>()
                .toList();

            print('🔵 Parsed drawings count: ${drawings.length}');
            return {
              'success': true,
              'drawings': drawings,
              'total': data['total'] ?? drawings.length,
              'message': data['message'] ?? 'Çizimler başarıyla getirildi',
            };
          } else {
            print('⚠️ Data is not a List: $drawingsList');
            return {
              'success': false,
              'message': 'Geçersiz veri formatı: data bir liste değil',
            };
          }
        } else {
          print('⚠️ API success=false ve data yok: ${data['message']}');
          return {
            'success': false,
            'message': data['message'] ?? 'Çizimler getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      print('❌ DioException: ${e.type}');
      print('❌ DioException message: ${e.message}');
      print('❌ DioException response: ${e.response?.data}');
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }

  /// Çizim detayı getir
  Future<Map<String, dynamic>> getDrawing(int id) async {
    try {
      final response = await _dio.get('/location-drawings/$id');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'drawing': LocationDrawing.fromJson(data['data']),
            'message': data['message'] ?? 'Çizim detayı başarıyla getirildi',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Çizim detayı getirilemedi',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Beklenmeyen hata: $e',
      };
    }
  }
}
