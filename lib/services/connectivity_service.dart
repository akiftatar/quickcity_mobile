import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Connectivity service'i başlat
  Future<void> initialize() async {
    // İlk durumu kontrol et
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result.first);

    // Değişiklikleri dinle
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results.first);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    // Durum değiştiyse bildir
    if (wasOnline != _isOnline) {
      _connectionStatusController.add(_isOnline);
      print('📡 Connection status changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
