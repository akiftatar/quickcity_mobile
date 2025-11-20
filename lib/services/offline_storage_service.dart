import 'package:hive_flutter/hive_flutter.dart';
import '../models/location.dart';
import '../models/issue.dart';

class OfflineStorageService {
  static const String _locationsBoxName = 'locations';
  static const String _issuesBoxName = 'issues';
  static const String _pendingIssuesBoxName = 'pending_issues';
  static const String _metadataBoxName = 'metadata';
  static const String _pendingCheckActionsKey = 'pending_check_actions';

  static Box<dynamic>? _locationsBox;
  static Box<dynamic>? _issuesBox;
  static Box<dynamic>? _pendingIssuesBox;
  static Box<dynamic>? _metadataBox;

  static bool _isHiveInitialized = false;
  static String _currentUserKey = 'default';

  static Map<String, dynamic> _normalizeMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  static List<Map<String, dynamic>> _normalizeMapList(dynamic data) {
    final result = <Map<String, dynamic>>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          result.add(_normalizeMap(item));
        }
      }
    }
    return result;
  }

  /// Hive'ı başlat ve varsayılan kullanıcı için box'ları aç
  static Future<void> initialize() async {
    if (!_isHiveInitialized) {
      await Hive.initFlutter();
      _isHiveInitialized = true;
    }
    
    await _openBoxesForUser(_currentUserKey);
  }

  /// Kullanıcıya özel context ayarla (her kullanıcı için ayrı box'lar)
  static Future<void> setUserContext(String? userId) async {
    if (!_isHiveInitialized) {
      await initialize();
    }
    
    final newKey = (userId != null && userId.isNotEmpty) ? 'user_$userId' : 'default';
    if (newKey == _currentUserKey && _locationsBox != null) {
      return;
    }
    
    await _closeBoxes();
    await _openBoxesForUser(newKey);
  }

  static Future<void> _openBoxesForUser(String key) async {
    _currentUserKey = key;
    _locationsBox = await Hive.openBox<dynamic>('${_locationsBoxName}_$key');
    _issuesBox = await Hive.openBox<dynamic>('${_issuesBoxName}_$key');
    _pendingIssuesBox = await Hive.openBox<dynamic>('${_pendingIssuesBoxName}_$key');
    _metadataBox = await Hive.openBox<dynamic>('${_metadataBoxName}_$key');
  }

  static Future<void> _closeBoxes() async {
    await _locationsBox?.close();
    await _issuesBox?.close();
    await _pendingIssuesBox?.close();
    await _metadataBox?.close();
    _locationsBox = null;
    _issuesBox = null;
    _pendingIssuesBox = null;
    _metadataBox = null;
  }

  // ==================== LOCATIONS ====================

  /// Lokasyonları kaydet
  static Future<void> saveLocations(List<Location> locations) async {
    if (_locationsBox == null) await initialize();
    
    await _locationsBox!.clear();
    for (var location in locations) {
      await _locationsBox!.put(location.id, location.toJson());
    }
    
    // Son güncelleme zamanını kaydet
    await _metadataBox!.put('locations_last_sync', DateTime.now().toIso8601String());
  }

  /// Tüm lokasyonları getir
  static Future<List<Location>> getLocations() async {
    if (_locationsBox == null) await initialize();
    
    final locations = <Location>[];
    for (var locationMap in _locationsBox!.values) {
      try {
        locations.add(Location.fromJson(Map<String, dynamic>.from(locationMap)));
      } catch (e) {
        print('Location parse error: $e');
      }
    }
    
    return locations;
  }

  /// Tek bir lokasyon getir
  static Future<Location?> getLocation(int id) async {
    if (_locationsBox == null) await initialize();
    
    final locationMap = _locationsBox!.get(id);
    if (locationMap == null) return null;
    
    try {
      return Location.fromJson(Map<String, dynamic>.from(locationMap));
    } catch (e) {
      print('Location parse error: $e');
      return null;
    }
  }

  /// Lokasyon sayısı
  static Future<int> getLocationsCount() async {
    if (_locationsBox == null) await initialize();
    return _locationsBox!.length;
  }

  // ==================== ISSUES ====================

  /// Sorunları kaydet
  static Future<void> saveIssues(List<Issue> issues) async {
    if (_issuesBox == null) await initialize();
    
    for (var issue in issues) {
      if (issue.id != null) {
        await _issuesBox!.put(issue.id, issue.toJson());
      }
    }
    
    await _metadataBox!.put('issues_last_sync', DateTime.now().toIso8601String());
  }

  /// Tüm sorunları getir
  static Future<List<Issue>> getIssues() async {
    if (_issuesBox == null) await initialize();
    
    final issues = <Issue>[];
    for (var issueMap in _issuesBox!.values) {
      try {
        issues.add(Issue.fromJson(Map<String, dynamic>.from(issueMap)));
      } catch (e) {
        print('Issue parse error: $e');
      }
    }
    
    return issues;
  }

  // ==================== PENDING ISSUES (Offline Bildirilen) ====================

  /// Offline sorun bildir (henüz sync edilmemiş)
  static Future<String> savePendingIssue(Map<String, dynamic> issueData) async {
    if (_pendingIssuesBox == null) await initialize();
    
    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    issueData['temp_id'] = tempId;
    issueData['created_offline'] = true;
    issueData['offline_timestamp'] = DateTime.now().toIso8601String();
    
    await _pendingIssuesBox!.put(tempId, issueData);
    
    return tempId;
  }

  /// Bekleyen sorunları getir
  static Future<List<Map<String, dynamic>>> getPendingIssues() async {
    if (_pendingIssuesBox == null) await initialize();
    
    final pendingIssues = <Map<String, dynamic>>[];
    for (var issueMap in _pendingIssuesBox!.values) {
      pendingIssues.add(Map<String, dynamic>.from(issueMap));
    }
    
    return pendingIssues;
  }

  /// Bekleyen sorunu sil (sync edildikten sonra)
  static Future<void> deletePendingIssue(String tempId) async {
    if (_pendingIssuesBox == null) await initialize();
    await _pendingIssuesBox!.delete(tempId);
  }

  /// Bekleyen sorun sayısı
  static Future<int> getPendingIssuesCount() async {
    if (_pendingIssuesBox == null) await initialize();
    return _pendingIssuesBox!.length;
  }

  // ==================== METADATA ====================

  /// Son sync zamanını getir
  static Future<DateTime?> getLastSyncTime(String key) async {
    if (_metadataBox == null) await initialize();
    
    final timestamp = _metadataBox!.get('${key}_last_sync');
    if (timestamp == null) return null;
    
    try {
      return DateTime.parse(timestamp.toString());
    } catch (e) {
      return null;
    }
  }

  /// Cache'i temizle
  static Future<void> clearCache() async {
    if (_locationsBox == null) await initialize();
    
    await _locationsBox!.clear();
    await _issuesBox!.clear();
    // Pending issues'ı temizleme - sync edilmemiş olabilir
    await _metadataBox!.clear();
  }

  /// Tüm verileri temizle (logout için)
  static Future<void> clearAll() async {
    if (_locationsBox == null) await initialize();
    
    await _locationsBox!.clear();
    await _issuesBox!.clear();
    await _pendingIssuesBox!.clear();
    await _metadataBox!.clear();
  }

  /// Box'ları kapat
  static Future<void> close() async {
    await _closeBoxes();
  }

  // ==================== WORK SESSION ====================

  /// Aktif iş oturumunu kaydet
  static Future<void> saveActiveWorkSession(Map<String, dynamic> sessionData) async {
    if (_metadataBox == null) await initialize();
    await _metadataBox!.put('active_work_session', sessionData);
  }

  /// Aktif iş oturumunu getir
  static Future<Map<String, dynamic>?> getActiveWorkSession() async {
    if (_metadataBox == null) await initialize();
    final data = _metadataBox!.get('active_work_session');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Aktif iş oturumunu temizle
  static Future<void> clearActiveWorkSession() async {
    if (_metadataBox == null) await initialize();
    await _metadataBox!.delete('active_work_session');
  }

  // ==================== PENDING CHECK ACTIONS ====================

  static Future<List<Map<String, dynamic>>> getPendingCheckActions() async {
    if (_metadataBox == null) await initialize();
    final data = _metadataBox!.get(_pendingCheckActionsKey);
    if (data == null) return [];
    try {
      return _normalizeMapList(data);
    } catch (e) {
      print('❌ Pending check actions parse hatası: $e');
      return [];
    }
  }

  static Future<void> addPendingCheckAction(Map<String, dynamic> action) async {
    if (_metadataBox == null) await initialize();
    final actions = await getPendingCheckActions();
    actions.add(action);
    await _metadataBox!.put(_pendingCheckActionsKey, actions);
  }

  static Future<void> removePendingCheckAction(String actionId) async {
    if (_metadataBox == null) await initialize();
    final actions = await getPendingCheckActions();
    actions.removeWhere((action) => action['id'] == actionId);
    await _metadataBox!.put(_pendingCheckActionsKey, actions);
  }

  static Future<void> updatePendingActionsForLog(String oldLogId, String? newLogId) async {
    if (_metadataBox == null) await initialize();
    final actions = await getPendingCheckActions();
    bool updated = false;
    for (final action in actions) {
      if (action['local_log_id'] == oldLogId) {
        action['log_id'] = newLogId;
        updated = true;
      }
    }
    if (updated) {
      await _metadataBox!.put(_pendingCheckActionsKey, actions);
    }
  }

  static Future<void> clearPendingCheckActions() async {
    if (_metadataBox == null) await initialize();
    await _metadataBox!.delete(_pendingCheckActionsKey);
  }

  // ==================== PENDING LOCATION UPDATES ====================

  /// Offline GPS verilerini kaydet (henüz sync edilmemiş)
  static Future<void> savePendingLocationUpdates({
    required String sessionId,
    required List<Map<String, dynamic>> locations,
  }) async {
    if (_metadataBox == null) await initialize();
    
    // Mevcut bekleyen verileri al
    final existing = await getPendingLocationUpdates(sessionId);
    
    // Yeni verileri ekle
    existing.addAll(locations);
    
    // Kaydet
    await _metadataBox!.put('pending_locations_$sessionId', existing);
    
    print('💾 ${locations.length} GPS verisi offline kayıt edildi (Toplam: ${existing.length})');
  }

  /// Bekleyen GPS verilerini getir
  static Future<List<Map<String, dynamic>>> getPendingLocationUpdates(String sessionId) async {
    if (_metadataBox == null) await initialize();
    
    final data = _metadataBox!.get('pending_locations_$sessionId');
    if (data == null) return [];
    
    try {
      return _normalizeMapList(data);
    } catch (e) {
      print('❌ Pending locations parse hatası: $e');
      return [];
    }
  }

  /// Tüm bekleyen GPS verilerini getir (tüm session'lar)
  static Future<Map<String, List<Map<String, dynamic>>>> getAllPendingLocationUpdates() async {
    if (_metadataBox == null) await initialize();
    
    final result = <String, List<Map<String, dynamic>>>{};
    
    // Tüm pending_locations_ ile başlayan key'leri bul
    for (var key in _metadataBox!.keys) {
      if (key.toString().startsWith('pending_locations_')) {
        final sessionId = key.toString().replaceFirst('pending_locations_', '');
        final locations = await getPendingLocationUpdates(sessionId);
        if (locations.isNotEmpty) {
          result[sessionId] = locations;
        }
      }
    }
    
    return result;
  }

  /// Bekleyen GPS verilerini sil (sync edildikten sonra)
  static Future<void> deletePendingLocationUpdates(String sessionId) async {
    if (_metadataBox == null) await initialize();
    await _metadataBox!.delete('pending_locations_$sessionId');
    print('✅ Session $sessionId için pending GPS verileri temizlendi');
  }

  /// Bekleyen GPS verisi sayısı
  static Future<int> getPendingLocationUpdatesCount(String sessionId) async {
    final locations = await getPendingLocationUpdates(sessionId);
    return locations.length;
  }

  /// Tüm bekleyen GPS verisi sayısı (tüm session'lar)
  static Future<int> getTotalPendingLocationUpdatesCount() async {
    final allPending = await getAllPendingLocationUpdates();
    return allPending.values.fold<int>(0, (sum, list) => sum + list.length);
  }

  // ==================== STATISTICS ====================

  /// Offline storage istatistikleri
  static Future<Map<String, dynamic>> getStatistics() async {
    if (_locationsBox == null) await initialize();
    
    return {
      'locations_count': _locationsBox!.length,
      'issues_count': _issuesBox!.length,
      'pending_issues_count': _pendingIssuesBox!.length,
      'pending_location_updates_count': await getTotalPendingLocationUpdatesCount(),
      'locations_last_sync': await getLastSyncTime('locations'),
      'issues_last_sync': await getLastSyncTime('issues'),
    };
  }
}
