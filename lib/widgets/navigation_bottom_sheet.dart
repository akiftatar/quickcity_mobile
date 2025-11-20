import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import 'dart:math' as math;
import '../models/location.dart';
import '../screens/tomtom_navigation_screen.dart';
import '../utils/navigation_helper.dart';

class NavigationBottomSheet extends StatefulWidget {
  final Location location;

  const NavigationBottomSheet({super.key, required this.location});

  @override
  State<NavigationBottomSheet> createState() => _NavigationBottomSheetState();
}

class _NavigationBottomSheetState extends State<NavigationBottomSheet> {
  Position? _currentPosition;
  double? _distance;
  String? _estimatedTime;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndCalculate();
  }

  Future<void> _getCurrentLocationAndCalculate() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _distance = _calculateDistance(
          position.latitude,
          position.longitude,
          widget.location.lat,
          widget.location.lng,
        );
        _estimatedTime = _calculateEstimatedTime(_distance!);
        _isLoading = false;
      });
    } catch (e) {
      print('Konum alınamadı: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000; // metre
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  String _calculateEstimatedTime(double distanceInMeters) {
    // Şehir içi ortalama hız: 30 km/s
    final distanceInKm = distanceInMeters / 1000;
    final timeInHours = distanceInKm / 30;
    final timeInMinutes = (timeInHours * 60).round();

    if (timeInMinutes < 1) {
      return '< 1 dk';
    } else if (timeInMinutes < 60) {
      return '$timeInMinutes dk';
    } else {
      final hours = timeInMinutes ~/ 60;
      final minutes = timeInMinutes % 60;
      return '${hours}s ${minutes}dk';
    }
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.4, // Başlangıçta ekranın %40'ı
      minChildSize: 0.25, // Minimum %25
      maxChildSize: 0.7, // Maximum %70
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Sürükle çubuğu
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Başlık ve Kapat butonu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: Color(0xFF1976D2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navigation,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.navigationInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: l10n.close,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Adres bilgisi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.blue[100]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.location.displayAddress,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.location.clusterLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.location.clusterLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Mesafe ve süre bilgisi
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_distance != null && _estimatedTime != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.straighten,
                        label: l10n.distance,
                        value: _formatDistance(_distance!),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.access_time,
                        label: l10n.estimatedTime,
                        value: _estimatedTime!,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Koordinat bilgisi (sürüklenince görünür)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.coordinates,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.location.lat.toStringAsFixed(6)}, ${widget.location.lng.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Navigasyon seçenekleri
              Text(
                l10n.chooseNavigationOption,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // GOOGLE MAPS'TE AÇ butonu (BÜYÜK ve DİKKAT ÇEKİCİ)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    NavigationHelper.openInMaps(context, widget.location);
                  },
                  icon: const Icon(Icons.directions_car, size: 28),
                  label: Text(
                    '🚗 ${l10n.openInGoogleMaps.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34A853), // Google yeşili
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                l10n.googleMapsNavigationSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 12),

              // TOMTOM uygulama içi navigasyon
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => TomTomNavigationScreen(
                              location: widget.location,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 28),
                  label: Text(
                    '🧭 ${l10n.openInTomTom.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A3D62),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                l10n.tomTomNavigationSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 16),

              // Koordinatları kopyala (İkincil buton)
              OutlinedButton.icon(
                onPressed: () {
                  final coords =
                      '${widget.location.lat},${widget.location.lng}';
                  Clipboard.setData(ClipboardData(text: coords));

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📋 ${l10n.coordinatesCopied}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l10n.copyCoordinates),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
