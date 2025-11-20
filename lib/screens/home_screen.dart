import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_storage_service.dart';
import '../services/sync_service.dart';
import '../services/work_session_service.dart';
import '../services/background_location_service.dart';
import '../models/location.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_indicator.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/work_session_header.dart';
import 'locations_list_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';
import 'location_detail_screen.dart';
import 'my_issues_screen.dart';
import 'issue_report_screen.dart';
import '../utils/navigation_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Location> _locations = [];
  List<String> _clusters = [];
  String? _selectedCluster;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final syncService = Provider.of<SyncService>(context, listen: false);
    final workSessionService = Provider.of<WorkSessionService>(context, listen: false);
    
    if (authService.token != null) {
      _apiService.setToken(authService.token!);
      // Sync service'e de token ver
      syncService.setToken(authService.token!);
      // Work session service'e de token ver
      workSessionService.setToken(authService.token!);
    }
    
    // Admin/SuperAdmin ise sadece cluster'ları yükle
    if (authService.currentUser?.isAdmin == true) {
      await _loadClusters();
      // Admin için başlangıçta lokasyon yükleme - cluster seçilene kadar beklenir
    } else {
      // Normal user için lokasyonları yükle
      await _loadLocations();
    }
  }

  Future<void> _loadClusters() async {
    try {
      final result = await _apiService.getClusters();
      if (result['success'] == true && mounted) {
        setState(() {
          _clusters = result['clusters'] ?? [];
        });
      }
    } catch (e) {
      // Cluster yükleme hatası
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // AuthService'ten token'ı al ve API service'e set et
      final authService = Provider.of<AuthService>(context, listen: false);
      final workSessionService = Provider.of<WorkSessionService>(context, listen: false);
      
      if (authService.token != null) {
        _apiService.setToken(authService.token!);
        workSessionService.setToken(authService.token!);
      }
      
      // Connectivity kontrolü
      final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);
      
      if (connectivityService.isOnline) {
        // ONLINE - API'den çek
        Map<String, dynamic> result;
        if (authService.currentUser?.isAdmin == true) {
          // Admin/SuperAdmin - Cluster seçilmediyse lokasyon getirme
          if (_selectedCluster == null) {
            setState(() {
              _locations = [];
              _isLoading = false;
            });
            return;
          }
          // Admin/SuperAdmin - Seçilen cluster'ın lokasyonlarını getir
          result = await _apiService.getAllLocations(cluster: _selectedCluster);
        } else {
          // Normal user - Rotalanmış lokasyonları getir
          result = await _apiService.getUserAssignmentsRouted();
        }
        
        if (result['success'] == true) {
          final locations = result['locations'] ?? [];
          setState(() {
            _locations = locations;
          });
          
          // Offline storage'a kaydet
          await OfflineStorageService.saveLocations(locations);
          final l10n = AppLocalizations.of(context)!;
          print(l10n.locationsSavedToOffline.replaceAll('@count', '${locations.length}'));
        } else {
          setState(() {
            _errorMessage = result['message'] ?? AppLocalizations.of(context)!.locationsLoadFailed;
          });
        }
      } else {
        // OFFLINE - Cache'den yükle
        final l10n = AppLocalizations.of(context)!;
        print(l10n.offlineModeLoadingFromCache);
        final cachedLocations = await OfflineStorageService.getLocations();
        setState(() {
          _locations = cachedLocations;
          if (cachedLocations.isEmpty) {
            _errorMessage = l10n.noCachedData;
          }
        });
        
        print(l10n.locationsLoadedFromCache.replaceAll('@count', '${cachedLocations.length}'));
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      print(l10n.locationLoadingError.replaceAll('@error', e.toString()));
      
      // Hata durumunda offline'dan yüklemeyi dene
      try {
        final cachedLocations = await OfflineStorageService.getLocations();
        setState(() {
          _locations = cachedLocations;
          _errorMessage = l10n.loadedFromCache.replaceAll('@count', cachedLocations.length.toString());
        });
      } catch (cacheError) {
        setState(() {
          _errorMessage = l10n.unexpectedError.replaceAll('@error', e.toString());
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.logout();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? l10n.logoutSuccess),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Offline badge
          const OfflineBadge(),
          // Filter butonu - sadece admin/superadmin için
          Consumer<AuthService>(
            builder: (context, authService, child) {
              if (authService.currentUser?.isAdmin == true) {
                return IconButton(
                  icon: Icon(
                    _selectedCluster != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                  ),
                  onPressed: _showClusterFilter,
                  tooltip: l10n.filter,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
            tooltip: l10n.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: l10n.settings,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: l10n.logout,
          ),
        ],
      ),
      body: Consumer<AuthService>(
          builder: (context, authService, child) {
            return Column(
              children: [
                // Offline Indicator
                const OfflineIndicator(),
                // Kullanıcı Bilgileri
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.welcome,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        authService.currentUser?.fullName ?? AppLocalizations.of(context)!.user,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.assignedLocationsCount.replaceAll('@count', _locations.length.toString()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // İş Oturumu Başlat/Bitir Widget
                WorkSessionHeader(
                  locations: _locations,
                  onSessionStarted: () {
                    setState(() {});  // UI'ı güncelle
                  },
                  onSessionEnded: () {
                    setState(() {
                      // Tüm durumları sıfırla
                      _loadLocations();
                    });
                  },
                ),

                // Ana İçerik
                Expanded(
                  child: _buildContent(),
                ),
              ],
            );
          },
        ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    
    // Loading durumunda skeleton göster
    if (_isLoading) {
      return ListSkeleton(
        itemCount: 8,
        skeletonItem: const LocationCardSkeleton(),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLocations,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    if (_locations.isEmpty) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAdmin = authService.currentUser?.isAdmin == true;
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAdmin ? Icons.filter_alt_outlined : Icons.location_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isAdmin ? l10n.selectClusterToStart : l10n.noAssignedLocations,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showClusterFilter,
                icon: const Icon(Icons.filter_alt),
                label: Text(l10n.selectCluster),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Hızlı Erişim Butonları
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationsListScreen(
                          locations: _locations,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list),
                  label: Text(l10n.locationList),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapScreen(
                          locations: _locations,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: Text(l10n.map),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lokasyon Özeti
        Expanded(
          child: _isLoading
              ? const ListSkeleton(
                  itemCount: 8,
                  skeletonItem: LocationCardSkeleton(),
                )
              : Consumer2<AuthService, WorkSessionService>(
                  builder: (context, authService, workSessionService, child) {
                    final isAdmin = authService.currentUser?.isAdmin ?? false;
                    final isSessionActive = workSessionService.isSessionActive;
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final location = _locations[index];
                        return Slidable(
                          key: ValueKey(location.id),
                          startActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) => _reportIssue(location),
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                icon: Icons.report_problem,
                                label: l10n.reportIssue,
                              ),
                            ],
                          ),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              NavigationHelper.buildNavigationAction(
                                context: context,
                                location: location,
                                onPressed: () => NavigationHelper.showNavigationBottomSheet(context, location),
                                isEnabled: isSessionActive,
                              ),
                            ],
                          ),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1976D2),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        location.displayAddress,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l10n.cluster}: ${location.clusterLabel}'),
                          // Sadece admin/superadmin için customer ve alan bilgileri
                          if (isAdmin) ...[
                            if (location.customer != null)
                              Text('${l10n.customer}: ${location.customer!.name}'),
                            Text(
                              l10n.totalArea.replaceAll('@area', location.relevantArea.toStringAsFixed(2)),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Lokasyon detayına git
                        _showLocationDetails(location);
                      },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showClusterFilter() {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filterByCluster),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(
            maxHeight: 500,
            minHeight: 200,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _clusters.length,
            itemBuilder: (context, index) {
              final cluster = _clusters[index];
              return ListTile(
                leading: Radio<String?>(
                  value: cluster,
                  groupValue: _selectedCluster,
                  onChanged: (value) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCluster = value;
                    });
                    _loadLocations();
                  },
                ),
                title: Text(
                  cluster,
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedCluster = cluster;
                  });
                  _loadLocations();
                },
              );
            },
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: 'Kapat',
          ),
          if (_selectedCluster != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCluster = null;
                });
                _loadLocations();
              },
              child: const Text('Tümünü Göster'),
            ),
        ],
      ),
    );
  }

  void _showLocationDetails(Location location) {
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

  void _reportIssue(Location location) {
    final l10n = AppLocalizations.of(context)!;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueReportScreen(
          location: location,
          apiService: _apiService,
        ),
      ),
    ).then((success) {
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.issueReportedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }



  Widget _buildWorkAreaItem(String label, double value) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${value.toStringAsFixed(2)} ${l10n.m2}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
