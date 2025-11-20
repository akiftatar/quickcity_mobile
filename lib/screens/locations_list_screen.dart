import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../models/location.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/work_session_service.dart';
import '../utils/navigation_helper.dart';
import '../utils/time_estimation_helper.dart';
import 'location_detail_screen.dart';
import 'issue_report_screen.dart';

// Lokasyon durumu için enum
enum LocationStatus {
  notStarted,
  inProgress,
  completed,
}

// Sıralama tipi için enum
enum SortType {
  route,        // Rota sırası (waypoint_index)
  areaAsc,      // Alan (küçükten büyüğe)
  areaDesc,     // Alan (büyükten küçüğe)
  nearest,      // En yakın
  status,       // Durum (tamamlanmayanlar önce)
  manual,       // Manuel sıralama
}

class LocationsListScreen extends StatefulWidget {
  final List<Location> locations;

  const LocationsListScreen({
    super.key,
    required this.locations,
  });

  @override
  State<LocationsListScreen> createState() => _LocationsListScreenState();
}

class _LocationsListScreenState extends State<LocationsListScreen> {
  final ApiService _apiService = ApiService();
  List<Location> _sortedLocations = [];
  Map<int, LocationStatus> _locationStatuses = {};
  Map<int, String> _locationNotes = {};
  Map<int, DateTime?> _startTimes = {};
  Map<int, DateTime?> _endTimes = {};
  
  String _searchQuery = '';
  SortType _currentSortType = SortType.route;
  Position? _currentPosition;
  
  // QuickCity GmbH ofis koordinatları
  static const double officeLatitude = 52.5616;
  static const double officeLongitude = 13.4783;
  
  // PERFORMANS: Hesaplamaları cache'le
  int? _cachedTotalMinutes;
  int? _cachedRemainingMinutes;
  bool _needsRecalculation = true;

  @override
  void initState() {
    super.initState();
    _sortedLocations = List.from(widget.locations);
    _initializeApiService();
    _loadWorkSessionState();
    _applySorting();
    _getCurrentLocation();
  }

  /// API Service'e token ver
  void _initializeApiService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.token != null) {
      _apiService.setToken(authService.token!);
    }
  }

  /// Work session durumlarını yükle
  Future<void> _loadWorkSessionState() async {
    final sessionService = Provider.of<WorkSessionService>(context, listen: false);
    
    if (sessionService.isSessionActive) {
      // Aktif oturum varsa, durumları work session'dan al
      for (var location in widget.locations) {
        final status = sessionService.getLocationStatus(location.id);
        
        if (status == 'in_progress') {
          _locationStatuses[location.id] = LocationStatus.inProgress;
          
          // Log'dan zamanları al
          final log = sessionService.locationLogs[location.id];
          if (log != null) {
            _startTimes[location.id] = log.checkedInAt;
            if (log.notes != null && log.notes!.isNotEmpty) {
              _locationNotes[location.id] = log.notes!;
            }
          }
        } else if (status == 'completed') {
          _locationStatuses[location.id] = LocationStatus.completed;
          
          // Log'dan zamanları ve notları al
          final log = sessionService.locationLogs[location.id];
          if (log != null) {
            _startTimes[location.id] = log.checkedInAt;
            _endTimes[location.id] = log.checkedOutAt;
            if (log.notes != null && log.notes!.isNotEmpty) {
              _locationNotes[location.id] = log.notes!;
            }
          }
        }
      }
      
      setState(() {});
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
    setState(() {
        _currentPosition = position;
      });
      if (_currentSortType == SortType.nearest) {
        _applySorting();
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      print(l10n.locationNotFound.replaceAll('@error', e.toString()));
    }
  }

  void _applySorting() {
    // PERFORMANS: Cache'i temizle
    _invalidateCache();
    
    // Önce filtreleme yap (sadece arama)
    var filteredList = widget.locations.where((location) {
        final matchesSearch = _searchQuery.isEmpty ||
            location.displayAddress.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (location.customer?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
      return matchesSearch;
      }).toList();
    
    // Sonra sıralama yap
    switch (_currentSortType) {
      case SortType.route:
        filteredList.sort((a, b) {
          if (a.waypointIndex == null && b.waypointIndex == null) return 0;
          if (a.waypointIndex == null) return 1;
          if (b.waypointIndex == null) return -1;
          return a.waypointIndex!.compareTo(b.waypointIndex!);
        });
        break;
        
        case SortType.areaAsc:
          filteredList.sort((a, b) => 
            a.relevantArea.compareTo(b.relevantArea));
          break;
          
        case SortType.areaDesc:
          filteredList.sort((a, b) => 
            b.relevantArea.compareTo(a.relevantArea));
          break;
        
      case SortType.nearest:
        if (_currentPosition != null) {
          filteredList.sort((a, b) {
            final distA = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              a.lat,
              a.lng,
            );
            final distB = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              b.lat,
              b.lng,
            );
            return distA.compareTo(distB);
          });
        }
        break;
        
      case SortType.status:
        filteredList.sort((a, b) {
          final statusA = _locationStatuses[a.id] ?? LocationStatus.notStarted;
          final statusB = _locationStatuses[b.id] ?? LocationStatus.notStarted;
          
          if (statusA == statusB) return 0;
          if (statusA == LocationStatus.completed) return 1;
          if (statusB == LocationStatus.completed) return -1;
          if (statusA == LocationStatus.inProgress) return -1;
          return 1;
        });
        break;
        
      case SortType.manual:
        // Manuel sıralama - kullanıcı drag & drop ile ayarlayacak
        break;
    }
    
    setState(() {
      _sortedLocations = filteredList;
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  int get _completedCount {
    return _locationStatuses.values
        .where((status) => status == LocationStatus.completed)
        .length;
  }

  int get _inProgressCount {
    return _locationStatuses.values
        .where((status) => status == LocationStatus.inProgress)
        .length;
  }

  // Cluster'a göre doğru toplam alan (relevantArea kullan)
  double get _totalArea {
    if (_sortedLocations.isEmpty) return 0.0;
    return _sortedLocations.fold(0.0, (sum, loc) => sum + loc.relevantArea);
  }

  // Tamamlanan lokasyonların toplam alanı (relevantArea kullan)
  double get _completedArea {
    if (_sortedLocations.isEmpty) return 0.0;
    return _sortedLocations
        .where((loc) => _locationStatuses[loc.id] == LocationStatus.completed)
        .fold(0.0, (sum, loc) => sum + loc.relevantArea);
  }

  // Tek lokasyon için tahmini süre (Yol + Temizleme + Sabitler)
  int _estimateLocationMinutes(Location location, double distanceKm) {
    return TimeEstimationHelper.estimateTotalMinutes(
      location: location,
      distanceKm: distanceKm,
      includeVariance: true,  // Standart sapma dahil
    );
  }

  // Sadece temizleme süresi (Alan için)
  int _estimateWorkMinutes(Location location) {
    return TimeEstimationHelper.estimateWorkMinutes(
      location,
      includeVariance: false,  // Toplam hesaplamada varyans yeterli
    );
  }

  // PERFORMANS: Cache'lenmiş toplam tahmini süre
  int get _totalEstimatedMinutes {
    if (_cachedTotalMinutes != null && !_needsRecalculation) {
      return _cachedTotalMinutes!;
    }
    
    if (_sortedLocations.isEmpty) return 0;
    
    int totalMinutes = 0;
    
    for (int i = 0; i < _sortedLocations.length; i++) {
      final location = _sortedLocations[i];
      
      // Mesafeyi hesapla
      double distanceKm;
      if (i == 0) {
        // İlk lokasyon: Ofisten
        distanceKm = _calculateDistance(
          officeLatitude, 
          officeLongitude,
          location.lat, 
          location.lng,
        ) / 1000;
      } else {
        // Sonraki lokasyonlar: Önceki lokasyondan
        final prevLocation = _sortedLocations[i - 1];
        distanceKm = _calculateDistance(
          prevLocation.lat, 
          prevLocation.lng,
          location.lat, 
          location.lng,
        ) / 1000;
      }
      
      totalMinutes += _estimateLocationMinutes(location, distanceKm);
    }
    
    _cachedTotalMinutes = totalMinutes;
    return totalMinutes;
  }

  // PERFORMANS: Cache'lenmiş kalan tahmini süre
  int get _remainingEstimatedMinutes {
    if (_cachedRemainingMinutes != null && !_needsRecalculation) {
      return _cachedRemainingMinutes!;
    }
    
    if (_sortedLocations.isEmpty) return 0;
    
    int remainingMinutes = 0;
    Location? lastCompletedLocation;
    
    for (int i = 0; i < _sortedLocations.length; i++) {
      final location = _sortedLocations[i];
      final status = _locationStatuses[location.id];
      
      // Tamamlanmış lokasyonu geç
      if (status == LocationStatus.completed) {
        lastCompletedLocation = location;
        continue;
      }
      
      // Mesafeyi hesapla
      double distanceKm;
      if (lastCompletedLocation != null) {
        // Son tamamlanan lokasyondan
        distanceKm = _calculateDistance(
          lastCompletedLocation.lat,
          lastCompletedLocation.lng,
          location.lat,
          location.lng,
        ) / 1000;
      } else if (_currentPosition != null) {
        // Mevcut konumdan
        distanceKm = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          location.lat,
          location.lng,
        ) / 1000;
      } else {
        // Ofisten (varsayılan)
        distanceKm = _calculateDistance(
          officeLatitude,
          officeLongitude,
          location.lat,
          location.lng,
        ) / 1000;
      }
      
      remainingMinutes += _estimateLocationMinutes(location, distanceKm);
    }
    
    _cachedRemainingMinutes = remainingMinutes;
    return remainingMinutes;
  }
  
  // Cache'i temizle (durumlar değiştiğinde)
  void _invalidateCache() {
    _needsRecalculation = true;
    _cachedTotalMinutes = null;
    _cachedRemainingMinutes = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('📋 ${l10n.workPlan}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Sıralama butonu
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sorting,
            onSelected: (SortType type) {
              setState(() {
                _currentSortType = type;
                _applySorting();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortType.route,
                child: Row(
                  children: [
                    Icon(_currentSortType == SortType.route ? Icons.check : Icons.route),
                    const SizedBox(width: 8),
                    Text(l10n.sortByRoute),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortType.areaAsc,
                child: Row(
                  children: [
                    Icon(_currentSortType == SortType.areaAsc ? Icons.check : Icons.arrow_upward),
                    const SizedBox(width: 8),
                    Text(l10n.sortByAreaAsc),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortType.areaDesc,
                child: Row(
                  children: [
                    Icon(_currentSortType == SortType.areaDesc ? Icons.check : Icons.arrow_downward),
                    const SizedBox(width: 8),
                    Text(l10n.sortByAreaDesc),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortType.nearest,
                child: Row(
                  children: [
                    Icon(_currentSortType == SortType.nearest ? Icons.check : Icons.my_location),
                    const SizedBox(width: 8),
                    Text(l10n.sortByNearest),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortType.status,
                child: Row(
                  children: [
                    Icon(_currentSortType == SortType.status ? Icons.check : Icons.check_circle),
                    const SizedBox(width: 8),
                    Text(l10n.sortByStatus),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistik Dashboard
          _buildStatisticsDashboard(l10n),
          
          // Arama Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchLocation,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                            _searchQuery = '';
                          _applySorting();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                  _searchQuery = value;
                _applySorting();
              },
            ),
          ),

          // Sıralama Bilgisi
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                Icon(_getSortIcon(), size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _getSortLabel(l10n),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (_searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: () {
                        _searchQuery = '';
                      _applySorting();
                    },
                    child: Text(l10n.clearFilters),
                  ),
                ],
              ),
            ),

          // Lokasyon Listesi
          Expanded(
            child: Consumer<WorkSessionService>(
              builder: (context, sessionService, child) {
                return _sortedLocations.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                              l10n.noLocationsFound,
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                      )
                    : _currentSortType == SortType.manual
                        ? ReorderableListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sortedLocations.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = _sortedLocations.removeAt(oldIndex);
                                _sortedLocations.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              final location = _sortedLocations[index];
                              return _buildLocationCard(location, index, l10n, sessionService, key: ValueKey(location.id));
                            },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                            itemCount: _sortedLocations.length,
                        itemBuilder: (context, index) {
                              final location = _sortedLocations[index];
                              return _buildLocationCard(location, index, l10n, sessionService, key: ValueKey(location.id));
                        },
                      );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildStatisticsDashboard(AppLocalizations l10n) {
    final progress = _sortedLocations.isEmpty ? 0.0 : _completedCount / _sortedLocations.length;
    
    // PERFORMANS: Cache'den al
    final remainingMinutes = _remainingEstimatedMinutes;
    _needsRecalculation = false;  // Cache artık aktif
    
    // Kalan süreyi daha iyi formatlayalım
    String remainingTimeText;
    if (remainingMinutes < 60) {
      remainingTimeText = l10n.minutes.replaceAll('@minutes', '$remainingMinutes');
    } else {
      final hours = remainingMinutes ~/ 60;
      final mins = remainingMinutes % 60;
      remainingTimeText = l10n.hoursMinutes.replaceAll('@hours', '$hours').replaceAll('@mins', '$mins');
    }
    
    final estimatedFinishTime = DateTime.now().add(Duration(minutes: remainingMinutes));
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎯 ${l10n.dailyProgress}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            l10n.locationsCompleted.replaceAll('@count', '$_completedCount / ${_sortedLocations.length}'),
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
          ),
          
          const SizedBox(height: 16),
          
          // İstatistikler
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '📍',
                  '${_sortedLocations.length}',
                  l10n.totalLocations,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '📏',
                  '${_totalArea.toStringAsFixed(0)} ${l10n.m2}',
                  l10n.totalAreaLabel,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '⏱️',
                  remainingTimeText,
                  l10n.remainingTime,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '🎯',
                  l10n.time.replaceAll('@hour', '${estimatedFinishTime.hour}').replaceAll('@minute', '${estimatedFinishTime.minute.toString().padLeft(2, '0')}'),
                  l10n.estimatedFinish,
                ),
              ),
            ],
          ),
          
          // Motivasyon mesajı
          if (progress > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getMotivationMessage(progress, l10n),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _getMotivationMessage(double progress, AppLocalizations l10n) {
    if (progress >= 1.0) return '🎉 ${l10n.motivationPerfect}';
    if (progress >= 0.75) return '💪 ${l10n.motivationAlmostDone}';
    if (progress >= 0.50) return '⚡ ${l10n.motivationHalfway}';
    if (progress >= 0.25) return '🔥 ${l10n.motivationQuarter}';
    return '🚀 ${l10n.motivationStart}';
  }

  Widget _buildLocationCard(Location location, int index, AppLocalizations l10n, WorkSessionService sessionService, {required Key key}) {
    final status = _locationStatuses[location.id] ?? LocationStatus.notStarted;
    final note = _locationNotes[location.id];
    
    // Tahmini iş süresi (sadece temizleme, yol dahil değil)
    final estimatedMinutes = _estimateWorkMinutes(location);
    
    final startTime = _startTimes[location.id];
    final endTime = _endTimes[location.id];
    
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLocationDetailDialog(location),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve Durum
              Row(
                children: [
                  // Sıra numarası / Durum ikonu
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: status == LocationStatus.completed
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : status == LocationStatus.inProgress
                              ? const Icon(Icons.play_arrow, color: Colors.white, size: 24)
                              : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Adres bilgisi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.displayAddress,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: status == LocationStatus.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                        Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getClusterColor(location.clusterLabel).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            location.clusterLabel,
                            style: TextStyle(
                              color: _getClusterColor(location.clusterLabel),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                            const SizedBox(width: 8),
                            Text(
                              '${location.relevantArea.toStringAsFixed(0)} ${l10n.m2}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Durum değiştirme butonu
                  Consumer<WorkSessionService>(
                    builder: (context, sessionService, child) {
                      return PopupMenuButton<LocationStatus>(
                        icon: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                        tooltip: l10n.changeStatus,
                        onSelected: (LocationStatus newStatus) async {
                          await _changeLocationStatus(location, newStatus, sessionService);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: LocationStatus.notStarted,
                            child: Row(
                              children: [
                                const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(l10n.notStarted),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: LocationStatus.inProgress,
                            child: Row(
                  children: [
                                const Icon(Icons.play_circle, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(l10n.inProgress),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: LocationStatus.completed,
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                                Text(l10n.completed),
                              ],
                      ),
                    ),
                  ],
                      );
                    },
                ),
              ],
              ),

              const SizedBox(height: 12),

              // Tahmini süre ve gerçek süre
                Row(
                  children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '~${l10n.minutes.replaceAll('@minutes', '$estimatedMinutes')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  
                  if (startTime != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.play_arrow, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      l10n.time.replaceAll('@hour', '${startTime.hour}').replaceAll('@minute', '${startTime.minute.toString().padLeft(2, '0')}'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  
                  if (endTime != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.stop, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      l10n.time.replaceAll('@hour', '${endTime.hour}').replaceAll('@minute', '${endTime.minute.toString().padLeft(2, '0')}'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (startTime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${l10n.duration.replaceAll('@duration', '${endTime.difference(startTime).inMinutes}')})',
                      style: const TextStyle(
                          fontSize: 12,
                        color: Colors.green,
                          fontWeight: FontWeight.bold,
                      ),
                    ),
                    ],
                  ],
                  ],
                ),
              
              // Not varsa göster
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Aksiyon butonları
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showLocationDetailDialog(location),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: Text(l10n.detail, style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showNoteDialog(location),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: Text(l10n.note, style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: sessionService.isSessionActive
                          ? () => NavigationHelper.showNavigationBottomSheet(context, location)
                          : null,
                      icon: const Icon(Icons.navigation, size: 16),
                      label: Text(l10n.go, style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sessionService.isSessionActive ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(LocationStatus status) {
    switch (status) {
      case LocationStatus.notStarted:
        return Colors.grey;
      case LocationStatus.inProgress:
      return Colors.orange;
      case LocationStatus.completed:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(LocationStatus status) {
    switch (status) {
      case LocationStatus.notStarted:
        return Icons.radio_button_unchecked;
      case LocationStatus.inProgress:
        return Icons.play_circle;
      case LocationStatus.completed:
        return Icons.check_circle;
    }
  }

  Color _getClusterColor(String clusterLabel) {
    final hash = clusterLabel.hashCode;
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[hash % colors.length];
  }

  IconData _getSortIcon() {
    switch (_currentSortType) {
      case SortType.route:
        return Icons.route;
      case SortType.areaAsc:
        return Icons.arrow_upward;
      case SortType.areaDesc:
        return Icons.arrow_downward;
      case SortType.nearest:
        return Icons.my_location;
      case SortType.status:
        return Icons.check_circle;
      case SortType.manual:
        return Icons.drag_handle;
    }
  }

  String _getSortLabel(AppLocalizations l10n) {
    switch (_currentSortType) {
      case SortType.route:
        return l10n.sortLabelRoute;
      case SortType.areaAsc:
        return l10n.sortLabelAreaAsc;
      case SortType.areaDesc:
        return l10n.sortLabelAreaDesc;
      case SortType.nearest:
        return l10n.sortLabelNearest;
      case SortType.status:
        return l10n.sortLabelStatus;
      case SortType.manual:
        return l10n.sortLabelManual;
    }
  }

  void _showLocationDetailDialog(Location location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationDetailScreen(
          location: location,
          apiService: _apiService,
        ),
      ),
    );
  }

  void _showNoteDialog(Location location) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _locationNotes[location.id] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addNote),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.noteHint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _locationNotes[location.id] = controller.text;
              });
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return FloatingActionButton(
      heroTag: 'manual_sort',
      backgroundColor: _currentSortType == SortType.manual ? Colors.orange : Colors.grey,
      onPressed: () {
        setState(() {
          _currentSortType = SortType.manual;
        });
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📝 ${l10n.manualSortActive}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: const Icon(Icons.drag_handle),
    );
  }

  /// Lokasyon durumunu değiştir (Work Session ile entegre)
  Future<void> _changeLocationStatus(
    Location location,
    LocationStatus newStatus,
    WorkSessionService sessionService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentStatus = _locationStatuses[location.id] ?? LocationStatus.notStarted;

    // İş oturumu aktif değilse uyarı ver
    if (!sessionService.isSessionActive && newStatus != LocationStatus.notStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${l10n.mustStartWorkSession}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Devam ediyor yapılıyorsa - Check-in
    if (newStatus == LocationStatus.inProgress && currentStatus == LocationStatus.notStarted) {
      await _handleCheckIn(location, sessionService, l10n);
    }
    // Tamamlandı yapılıyorsa - Check-out
    else if (newStatus == LocationStatus.completed && currentStatus == LocationStatus.inProgress) {
      await _handleCheckOut(location, sessionService, l10n);
    }
    // Direkt tamamlandı - Önce check-in sonra check-out
    else if (newStatus == LocationStatus.completed && currentStatus == LocationStatus.notStarted) {
      // Önce check-in yap
      await _handleCheckIn(location, sessionService, l10n);
      // Hemen check-out yap
      await Future.delayed(const Duration(milliseconds: 500));
      await _handleCheckOut(location, sessionService, l10n);
    }
    // Geri alma (completed -> in_progress gibi)
    else {
      setState(() {
        _locationStatuses[location.id] = newStatus;
        _invalidateCache();  // PERFORMANS: Cache'i temizle
      });
    }
  }

  /// Check-in işlemi
  Future<void> _handleCheckIn(
    Location location,
    WorkSessionService sessionService,
    AppLocalizations l10n,
  ) async {
    try {
      // GPS konumunu al
      final position = await Geolocator.getCurrentPosition();

      // Work session service'e check-in
      final result = await sessionService.checkInLocation(
        location: location,
        position: position,
      );

      if (result['success'] == true) {
        setState(() {
          _locationStatuses[location.id] = LocationStatus.inProgress;
          _startTimes[location.id] = DateTime.now();
          _invalidateCache();  // PERFORMANS: Cache'i temizle
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${l10n.checkInSuccess}: ${location.displayAddress}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          // Backend'den gelen detaylı hata mesajını göster
          final errorDetails = result['error_details'];
          String errorMessage = result['message'] ?? l10n.checkInFailed;
          
          // Validation hatalarını göster
          if (errorDetails != null && errorDetails is Map) {
            if (errorDetails.containsKey('errors')) {
              final errors = errorDetails['errors'];
              if (errors is Map) {
                errorMessage += '\n\n${l10n.details}\n';
                errors.forEach((field, messages) {
                  if (messages is List) {
                    errorMessage += '• $field: ${messages.join(', ')}\n';
                  }
                });
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${l10n.checkInError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check-out işlemi
  Future<void> _handleCheckOut(
    Location location,
    WorkSessionService sessionService,
    AppLocalizations l10n,
  ) async {
    // Not dialogunu göster
    final note = await _showCheckoutNoteDialog(location);
    
    try {
      // Work session service'e check-out
      final result = await sessionService.checkOutLocation(
        location: location,
        notes: note,
      );

      if (result['success'] == true) {
        setState(() {
          _locationStatuses[location.id] = LocationStatus.completed;
          _endTimes[location.id] = DateTime.now();
          if (note != null && note.isNotEmpty) {
            _locationNotes[location.id] = note;
          }
          _invalidateCache();  // PERFORMANS: Cache'i temizle
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${l10n.checkOutSuccess}: ${location.displayAddress}'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Tüm lokasyonlar tamamlandı mı?
          _checkIfAllCompleted();
        }
      } else {
        if (mounted) {
          // Backend'den gelen detaylı hata mesajını göster
          final errorDetails = result['error_details'];
          String errorMessage = result['message'] ?? l10n.checkOutFailed;
          
          // Validation hatalarını göster
          if (errorDetails != null && errorDetails is Map) {
            if (errorDetails.containsKey('errors')) {
              final errors = errorDetails['errors'];
              if (errors is Map) {
                errorMessage += '\n\n${l10n.details}\n';
                errors.forEach((field, messages) {
                  if (messages is List) {
                    errorMessage += '• $field: ${messages.join(', ')}\n';
                  }
                });
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${l10n.checkOutError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check-out not dialogu
  Future<String?> _showCheckoutNoteDialog(Location location) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ ${l10n.completingWork}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              location.displayAddress,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                hintText: l10n.example,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.complete),
          ),
        ],
      ),
    );
    
    return result;
  }

  /// Tüm lokasyonlar tamamlandı mı kontrol et
  void _checkIfAllCompleted() {
    final completed = _locationStatuses.values
        .where((s) => s == LocationStatus.completed)
        .length;
    
    if (completed == _sortedLocations.length) {
      // Tüm lokasyonlar tamamlandı!
      _showAllCompletedDialog();
    }
  }

  /// Tüm lokasyonlar tamamlandı dialogu
  Future<void> _showAllCompletedDialog() async {
    final l10n = AppLocalizations.of(context)!;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.congratulations),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              l10n.allLocationsCompleted,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.locationsSuccessfullyCompleted.replaceAll('@count', '${_sortedLocations.length}'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.wantToEndWorkSession,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.continueAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Ana ekrana dön ve iş oturumunu bitir
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.endWork),
          ),
        ],
      ),
    );
  }

}
