import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';
import '../models/location_drawing.dart';
import '../services/auth_service.dart';
import '../services/work_session_service.dart';
import '../services/api_service.dart';
import '../utils/navigation_helper.dart';
import '../utils/geojson_helper.dart';

class MapScreen extends StatefulWidget {
  final List<Location> locations;

  const MapScreen({super.key, required this.locations});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  LatLng? _center;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  List<LocationDrawing> _drawings = [];
  bool _isLoadingDrawings = false;
  late ApiService _apiService;
  bool _showMarkers = true; // Marker'ları göster/gizle
  bool _isSatelliteMode = false; // Uydu görünümü toggle
  Timer? _locationUpdateTimer; // Konum güncelleme timer'ı

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _apiService = ApiService();
    _calculateCenter();
    _getCurrentLocation();
    _loadDrawings();
    _startLocationUpdateTimer();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  /// Her 30 saniyede bir konum güncelleme timer'ını başlat
  void _startLocationUpdateTimer() {
    _locationUpdateTimer?.cancel();
    // Her 30 saniyede bir konumu güncelle
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _getCurrentLocation();
    });
  }

  Future<void> _loadDrawings() async {
    setState(() {
      _isLoadingDrawings = true;
    });

    try {
      // AuthService'ten token'ı al ve API service'e set et
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.token != null) {
        _apiService.setToken(authService.token!);
      }

      // Eğer lokasyon yoksa çizim yükleme
      if (widget.locations.isEmpty) {
        setState(() {
          _drawings = [];
          _isLoadingDrawings = false;
        });
        print('⚠️ Lokasyon yok, çizim yüklenmedi');
        return;
      }

      // Lokasyon ID'lerini topla
      final locationIds = widget.locations.map((loc) => loc.id).toSet();
      print('📍 ${locationIds.length} lokasyon için çizimler yükleniyor...');

      // ÖNCE: Lokasyon bazlı paralel yükleme (ÇOK DAHA HIZLI!)
      print('⚡ HIZLI YÜKLEME: Lokasyon bazlı paralel yükleme başlatılıyor...');
      final List<LocationDrawing> allDrawings = [];
      
      // Tüm lokasyonlar için paralel API çağrıları yap
      final List<Future<void>> locationFutures = locationIds.map((locationId) async {
        try {
          final result = await _apiService.getDrawingsByLocation(locationId);
          if (result['success'] == true) {
            final drawings = result['drawings'] ?? [];
            if (drawings.isNotEmpty) {
              allDrawings.addAll(drawings);
              print('✅ Lokasyon $locationId: ${drawings.length} çizim yüklendi');
            }
          }
        } catch (e) {
          print('⚠️ Lokasyon $locationId yükleme hatası: $e');
        }
      }).toList();
      
      // Tüm paralel çağrıları bekle
      await Future.wait(locationFutures);
      
      print('⚡ Paralel yükleme tamamlandı: ${allDrawings.length} çizim yüklendi');
      
      // Eğer çok az çizim yüklendiyse, sayfalama ile yedek yükleme yap
      if (allDrawings.length < locationIds.length * 2) {
        print('⚠️ Az çizim yüklendi, sayfalama ile yedek yükleme yapılıyor...');

        int page = 1;
        const int perPage = 200;
        const int maxPages = 5; // Maksimum 5 sayfa (1000 çizim) - hız için sınırlı
        int? totalDrawings;
        bool hasMorePages = true;
        final Set<int> foundLocationIds = allDrawings.map((d) => d.locationId).toSet();
        
        while (hasMorePages && page <= maxPages) {
          try {
            final pageResult = await _apiService.getAllDrawings(
              perPage: perPage,
              visibleOnly: true,
              page: page,
            );

            if (pageResult['success'] == true) {
              final drawings = pageResult['drawings'] ?? [];
              
              // Sadece ilgili lokasyonların çizimlerini ekle
              for (final drawing in drawings) {
                if (locationIds.contains(drawing.locationId) && 
                    !foundLocationIds.contains(drawing.locationId)) {
                  allDrawings.add(drawing);
                  foundLocationIds.add(drawing.locationId);
                }
              }
              
              // İlk sayfada total'i al
              if (totalDrawings == null && pageResult['total'] != null) {
                final totalValue = pageResult['total'];
                if (totalValue is int) {
                  totalDrawings = totalValue;
                } else if (totalValue is String) {
                  totalDrawings = int.tryParse(totalValue);
                }
              }
              
              // Sayfalama kontrolü
              if (drawings.length < perPage || page >= maxPages) {
                hasMorePages = false;
              } else {
                page++;
              }
            } else {
              hasMorePages = false;
            }
          } catch (e) {
            print('⚠️ Sayfa $page yükleme hatası: $e');
            hasMorePages = false;
          }
        }
        
        print('✅ Yedek yükleme tamamlandı: Toplam ${allDrawings.length} çizim');
      }

      setState(() {
        _drawings = allDrawings;
        _isLoadingDrawings = false;
      });

      print('✅ Toplam ${_drawings.length} çizim yüklendi');
    } catch (e) {
      print('❌ Çizim yükleme hatası: $e');
      setState(() {
        _isLoadingDrawings = false;
      });
    }
  }

  void _calculateCenter() {
    if (widget.locations.isEmpty) {
      // Berlin koordinatları (varsayılan)
      _center = const LatLng(52.5200, 13.4050);
      return;
    }

    double totalLat = 0;
    double totalLng = 0;

    for (final location in widget.locations) {
      totalLat += location.lat;
      totalLng += location.lng;
    }

    _center = LatLng(
      totalLat / widget.locations.length,
      totalLng / widget.locations.length,
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Konum izinlerini kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Konum izni reddedildi');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Konum izni kalıcı olarak reddedildi');
        return;
      }

      // Mevcut konumu al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      print(
        '📍 Kullanıcı konumu alındı: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('❌ Konum alınamadı: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.map),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Uydu/Normal harita toggle butonu
          IconButton(
            icon: Icon(_isSatelliteMode ? Icons.satellite : Icons.map),
            onPressed: () {
              setState(() {
                _isSatelliteMode = !_isSatelliteMode;
              });
            },
            tooltip: _isSatelliteMode ? 'Normal Harita' : 'Uydu Görünümü',
          ),
          // Marker göster/gizle toggle butonu
          IconButton(
            icon: Icon(_showMarkers ? Icons.location_on : Icons.location_off),
            onPressed: () {
              setState(() {
                _showMarkers = !_showMarkers;
              });
            },
            tooltip:
                _showMarkers ? 'Marker\'ları Gizle' : 'Marker\'ları Göster',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUserLocation,
            tooltip: l10n.myLocation,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnLocations,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body:
          _center == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center!,
                  initialZoom: 12.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        _isSatelliteMode
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.quickcity.mobile',
                    maxZoom: 18,
                  ),
                  // Çizimler (Polygon ve Polyline)
                  ..._buildDrawingLayers(),
                  // Marker'lar (toggle ile göster/gizle)
                  if (_showMarkers) MarkerLayer(markers: _buildMarkers()),
                  // Kullanıcı konumu marker'ı
                  if (_userLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _userLocation!,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnLocations,
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.center_focus_strong, color: Colors.white),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final l10n = AppLocalizations.of(context)!;
    final workSessionService = Provider.of<WorkSessionService>(
      context,
      listen: false,
    );

    return widget.locations.asMap().entries.map((entry) {
      final index = entry.key;
      final location = entry.value;

      // Lokasyon durumuna göre renk belirle
      final status = workSessionService.getLocationStatus(location.id);
      Color markerColor;
      IconData markerIcon;

      switch (status) {
        case 'completed':
          markerColor = const Color(0xFF4CAF50); // Koyu yeşil (tamamlanan)
          markerIcon = Icons.check_circle;
          break;
        case 'in_progress':
          markerColor = Colors.orange; // Turuncu (devam eden)
          markerIcon = Icons.radio_button_checked;
          break;
        default:
          // Cluster türüne göre renk ve ikon
          switch (location.clusterLabel.toUpperCase()) {
            case 'MFILE':
              markerColor = Colors.red; // Kırmızı
              markerIcon = Icons.cleaning_services;
              break;
            case 'HFILE':
              markerColor = Colors.green; // Yeşil
              markerIcon = Icons.home_work;
              break;
            case 'UFILE':
              markerColor = Colors.blue; // Mavi
              markerIcon = Icons.business;
              break;
            default:
              markerColor = Colors.purple; // Tamamlanan lokasyonlar için mor
              markerIcon = Icons.location_on;
          }
      }

      return Marker(
        point: LatLng(location.lat, location.lng),
        width: 70,
        height: 70,
        child: GestureDetector(
          onTap: () => _showLocationInfo(location, index + 1),
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: markerColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(markerIcon, color: Colors.white, size: 20),
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _centerOnLocations() {
    if (_center != null) {
      _mapController.move(_center!, 12.0);
    }
  }

  void _centerOnUserLocation() {
    final l10n = AppLocalizations.of(context)!;
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16.0);
    } else {
      // Konum yoksa tekrar almaya çalış
      _getCurrentLocation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.locationPermissionRequired),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showLocationInfo(Location location, int index) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final workSessionService = Provider.of<WorkSessionService>(
      context,
      listen: false,
    );
    final isAdmin = authService.currentUser?.isAdmin ?? false;
    final isSessionActive = workSessionService.isSessionActive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  '$index',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.displayAddress,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.cluster}: ${location.clusterLabel}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Customer info (Sadece Admin/SuperAdmin)
                        if (isAdmin && location.customer != null) ...[
                          Text(
                            '${l10n.customer}: ${location.customer!.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Work areas (Sadece Admin/SuperAdmin)
                        if (isAdmin) ...[
                          Text(
                            l10n.workAreas,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildWorkAreaItem(
                            l10n.sidewalks1m,
                            location.workAreas.gehwege1,
                          ),
                          _buildWorkAreaItem(
                            l10n.sidewalks1_5m,
                            location.workAreas.gehwege15,
                          ),
                          _buildWorkAreaItem(
                            l10n.parkingSpaces,
                            location.workAreas.parkingSpacesSurface,
                          ),
                          _buildWorkAreaItem(
                            l10n.vehiclePaths,
                            location.workAreas.parkingSpacesPaths,
                          ),
                          _buildWorkAreaItem(
                            l10n.manualCleaning,
                            location.workAreas.handreinigung,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.total,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  l10n.totalArea.replaceAll(
                                    '@area',
                                    location.workAreas.totalArea
                                        .toStringAsFixed(2),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _centerOnLocation(location);
                                },
                                icon: const Icon(Icons.center_focus_strong),
                                label: Text(l10n.refresh),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: NavigationHelper.buildNavigationButton(
                                context: context,
                                location: location,
                                onPressed: () {
                                  Navigator.pop(context);
                                  NavigationHelper.showNavigationBottomSheet(
                                    context,
                                    location,
                                  );
                                },
                                isEnabled: isSessionActive,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildWorkAreaItem(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${value.toStringAsFixed(2)} m²',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _centerOnLocation(Location location) {
    _mapController.move(LatLng(location.lat, location.lng), 15.0);
  }

  /// Çizimler için layer'ları oluştur
  List<Widget> _buildDrawingLayers() {
    final List<Widget> layers = [];

    // Polygon çizimleri
    final polygonDrawings =
        _drawings.where((drawing) {
          if (!GeoJsonHelper.canDraw(drawing)) return false;
          final geometryType = GeoJsonHelper.getGeometryType(drawing);
          return geometryType == 'polygon' || geometryType == 'multipolygon';
        }).toList();

    if (polygonDrawings.isNotEmpty) {
      layers.add(
        PolygonLayer(
          polygons:
              polygonDrawings.map((drawing) {
                final coordinates = GeoJsonHelper.extractCoordinates(
                  drawing.geojson,
                );
                // Polygon için minimum 3 nokta gerekli
                if (coordinates.length < 3) {
                  print('⚠️ Polygon atlandı: yetersiz koordinat (${coordinates.length} nokta)');
                  return null;
                }
                final colorInt = GeoJsonHelper.hexToColorInt(drawing.color);
                final color = Color(colorInt).withOpacity(drawing.opacity);

                return Polygon(
                  points: coordinates,
                  color: color,
                  borderColor: Color(colorInt),
                  borderStrokeWidth: drawing.strokeWidth,
                  isFilled: true,
                );
              }).where((polygon) => polygon != null).cast<Polygon>().toList(),
        ),
      );
    }

    // Polyline çizimleri (LineString ve MultiLineString)
    final polylineDrawings =
        _drawings.where((drawing) {
          if (!GeoJsonHelper.canDraw(drawing)) return false;
          final geometryType = GeoJsonHelper.getGeometryType(drawing);
          return geometryType == 'linestring' ||
              geometryType == 'multilinestring';
        }).toList();

    if (polylineDrawings.isNotEmpty) {
      // Tüm polyline'ları bir layer'da topla
      final List<Polyline> allPolylines = [];

      for (final drawing in polylineDrawings) {
        final geometryType = GeoJsonHelper.getGeometryType(drawing);
        final colorInt = GeoJsonHelper.hexToColorInt(drawing.color);
        final color = Color(colorInt).withOpacity(drawing.opacity);

        if (geometryType == 'multilinestring') {
          // MultiLineString için her bir LineString'i ayrı polyline yap
          final lineStrings = GeoJsonHelper.extractMultiLineStringCoordinates(
            drawing.geojson,
          );
          for (final lineString in lineStrings) {
            if (lineString.length >= 2) {
              allPolylines.add(
                Polyline(
                  points: lineString,
                  strokeWidth: drawing.strokeWidth,
                  color: color,
                ),
              );
            }
          }
        } else {
          // LineString için tek polyline
          final coordinates = GeoJsonHelper.extractCoordinates(drawing.geojson);
          if (coordinates.length >= 2) {
            allPolylines.add(
              Polyline(
                points: coordinates,
                strokeWidth: drawing.strokeWidth,
                color: color,
              ),
            );
          }
        }
      }

      if (allPolylines.isNotEmpty) {
        layers.add(PolylineLayer(polylines: allPolylines));
      }
    }

    return layers;
  }
}
