import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/location.dart';
import '../services/tomtom_navigation_service.dart';
import '../utils/app_constants.dart';

class TomTomNavigationScreen extends StatefulWidget {
  const TomTomNavigationScreen({super.key, required this.location});

  final Location location;

  @override
  State<TomTomNavigationScreen> createState() => _TomTomNavigationScreenState();
}

class _TomTomNavigationScreenState extends State<TomTomNavigationScreen> {
  late final TomTomNavigationService _navigationService;
  final Distance _distance = const Distance();
  StreamSubscription<Position>? _positionSubscription;

  bool _isLoading = true;
  bool _isNavigating = false;
  String? _errorMessage;
  TomTomRouteResult? _routeResult;
  LatLng? _userPosition;
  double _progress = 0;
  int _currentInstructionIndex = 0;
  List<LatLng?> _instructionPoints = [];
  double? _liveDistanceMeters;
  int? _liveEtaSeconds;
  double? _nextInstructionDistance;
  bool _isSummaryCollapsed = false;

  @override
  void initState() {
    super.initState();
    _navigationService = TomTomNavigationService(
      apiKey: AppConstants.tomTomApiKey,
    );
    _loadRoute();
  }

  @override
  void dispose() {
    _stopNavigation();
    _navigationService.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    _stopNavigation();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progress = 0;
      _currentInstructionIndex = 0;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Konum izni gerekli');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni kalÄ±cÄ± olarak reddedildi');
      }

      final position = await Geolocator.getCurrentPosition();
      final result = await _navigationService.calculateRoute(
        startLat: position.latitude,
        startLng: position.longitude,
        destinationLat: widget.location.lat,
        destinationLng: widget.location.lng,
      );

      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _routeResult = result;
        _instructionPoints = _mapInstructionPoints(result);
        _liveDistanceMeters = null;
        _liveEtaSeconds = null;
        _nextInstructionDistance = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleNavigation() {
    if (_isNavigating) {
      _stopNavigation();
    } else {
      _startNavigation();
    }
  }

  Future<void> _startNavigation() async {
    if (_routeResult == null) return;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni gerekli');
      }

      setState(() {
        _isNavigating = true;
        _isSummaryCollapsed = true;
      });

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen(_handlePositionUpdate);
    } catch (e) {
      setState(() {
        _isNavigating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _stopNavigation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!mounted) {
      _isNavigating = false;
      _liveDistanceMeters = null;
      _liveEtaSeconds = null;
      _nextInstructionDistance = null;
      return;
    }
    setState(() {
      _isNavigating = false;
      _liveDistanceMeters = null;
      _liveEtaSeconds = null;
      _nextInstructionDistance = null;
      _isSummaryCollapsed = false;
    });
  }

  void _handlePositionUpdate(Position position) {
    if (_routeResult == null) return;

    final current = LatLng(position.latitude, position.longitude);
    final polyline = _routeResult!.polyline;
    if (polyline.isEmpty) return;

    final closestIndex = _findClosestPolylineIndex(current, polyline);
    final progress =
        polyline.length <= 1 ? 1.0 : closestIndex / (polyline.length - 1);

    final instructions = _routeResult!.instructions;
    int newInstructionIndex = _currentInstructionIndex;
    for (int i = 0; i < instructions.length; i++) {
      final instruction = instructions[i];
      final pointIndex = instruction.pointIndex ?? 0;
      if (closestIndex >= pointIndex) {
        newInstructionIndex = i.clamp(0, instructions.length - 1);
      } else {
        break;
      }
    }

    final destination = polyline.last;
    final distanceToDestination = _distance.as(
      LengthUnit.Meter,
      current,
      destination,
    );

    final etaSeconds =
        _routeResult!.lengthInMeters > 0
            ? (distanceToDestination /
                    _routeResult!.lengthInMeters *
                    _routeResult!.totalTimeInSeconds)
                .clamp(0, 86400)
                .round()
            : null;

    double? nextInstructionDistance;
    if (_instructionPoints.isNotEmpty &&
        newInstructionIndex < _instructionPoints.length) {
      final nextPoint = _instructionPoints[newInstructionIndex];
      if (nextPoint != null) {
        nextInstructionDistance = _distance.as(
          LengthUnit.Meter,
          current,
          nextPoint,
        );
      }
    }

    setState(() {
      _userPosition = current;
      _progress = progress.clamp(0, 1);
      _currentInstructionIndex = newInstructionIndex;
      _liveDistanceMeters = distanceToDestination;
      _liveEtaSeconds = etaSeconds;
      _nextInstructionDistance = nextInstructionDistance;
    });

    if (distanceToDestination < 20) {
      _stopNavigation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tomTomArrived),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  int _findClosestPolylineIndex(LatLng current, List<LatLng> polyline) {
    int closestIndex = 0;
    double closestDistance = double.infinity;

    for (int i = 0; i < polyline.length; i++) {
      final point = polyline[i];
      final distance = _distance.as(LengthUnit.Meter, current, point);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  List<LatLng?> _mapInstructionPoints(TomTomRouteResult result) {
    return result.instructions.map((instruction) {
      final idx = instruction.pointIndex;
      if (idx != null &&
          idx >= 0 &&
          idx < result.polyline.length &&
          result.polyline.isNotEmpty) {
        return result.polyline[idx];
      }
      return result.polyline.isNotEmpty ? result.polyline.last : null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tomTomNavigation),
        backgroundColor: const Color(0xFF0A3D62),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRoute,
            tooltip: l10n.refreshRoute,
          ),
        ],
      ),
      body: SafeArea(
        child:
            _isNavigating
                ? _buildFullScreenNavigation(l10n)
                : Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildBody(l10n),
                ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, color: Colors.orange[600], size: 48),
          const SizedBox(height: 12),
          Text(
            l10n.tomTomRouteError,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadRoute,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refreshRoute),
          ),
        ],
      );
    }

    if (_routeResult == null || _routeResult!.polyline.isEmpty) {
      return Center(child: Text(l10n.tomTomNoRoute));
    }

    return Column(
      children: [
        _buildSummaryCard(l10n),
        const SizedBox(height: 12),
        _buildNavigationControls(l10n),
        const SizedBox(height: 12),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildMap(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(flex: 2, child: _buildInstructionsList(l10n)),
      ],
    );
  }

  Widget _buildFullScreenNavigation(AppLocalizations l10n) {
    final nextInstruction =
        _routeResult?.instructions.isNotEmpty == true
            ? _routeResult!.instructions[_currentInstructionIndex].message
            : null;
    final nextInstructionDistance =
        _nextInstructionDistance != null
            ? _formatDistance(_nextInstructionDistance!)
            : null;

    final liveDistanceText =
        _liveDistanceMeters != null
            ? _formatDistance(_liveDistanceMeters!)
            : '—';
    final liveEtaText =
        _liveEtaSeconds != null ? _formatDuration(_liveEtaSeconds!) : '—';

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildCollapsibleSummary(l10n),
                if (nextInstruction != null) ...[
                  const SizedBox(height: 12),
                  _buildInstructionOverlay(
                    title: l10n.tomTomNextInstruction,
                    description:
                        nextInstructionDistance != null
                            ? '$nextInstruction ($nextInstructionDistance)'
                            : nextInstruction,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildInstructionOverlay(
              title: l10n.tomTomNavigationActive,
              description:
                  nextInstructionDistance != null
                      ? '$liveDistanceText • $liveEtaText'
                      : liveDistanceText,
              trailing: ElevatedButton.icon(
                onPressed: _toggleNavigation,
                icon: const Icon(Icons.stop),
                label: Text(l10n.stopNavigation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n) {
    final route = _routeResult!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D62),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.location.displayAddress,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.navigationProgress.replaceAll(
              '@percent',
              '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            ),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.straighten,
                  label: l10n.distance,
                  value: _formatDistance(route.lengthInMeters.toDouble()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.access_time,
                  label: l10n.estimatedTime,
                  value: _formatDuration(route.totalTimeInSeconds),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.traffic,
                  label: l10n.trafficDelayLabel,
                  value: _formatDuration(route.trafficDelayInSeconds),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_routeResult!.instructions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _routeResult!
                          .instructions[_currentInstructionIndex]
                          .message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSummary(AppLocalizations l10n) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState:
          _isSummaryCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
      firstChild: _buildCollapsedSummaryBar(),
      secondChild: Stack(
        children: [
          _buildSummaryCard(l10n),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withOpacity(0.2),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.expand_less, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSummaryCollapsed = true;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D62),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.location.displayAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.navigationProgress.replaceAll(
                    '@percent',
                    '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.expand_more, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSummaryCollapsed = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls(AppLocalizations l10n) {
    final hasRoute = _routeResult != null;
    if (!hasRoute) {
      return const SizedBox.shrink();
    }

    final nextInstruction =
        _routeResult!.instructions.isNotEmpty
            ? _routeResult!.instructions[_currentInstructionIndex].message
            : null;
    final nextInstructionDistance =
        _nextInstructionDistance != null
            ? _formatDistance(_nextInstructionDistance!)
            : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _toggleNavigation,
                icon: Icon(_isNavigating ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isNavigating ? l10n.stopNavigation : l10n.startNavigation,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isNavigating
                          ? Colors.redAccent
                          : const Color(0xFF0A3D62),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_liveDistanceMeters != null || _liveEtaSeconds != null)
            Row(
              children: [
                if (_liveDistanceMeters != null)
                  Expanded(
                    child: _buildLiveStat(
                      icon: Icons.place,
                      label: l10n.tomTomLiveDistance,
                      value: _formatDistance(_liveDistanceMeters!),
                    ),
                  ),
                if (_liveEtaSeconds != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLiveStat(
                      icon: Icons.timer,
                      label: l10n.tomTomLiveEta,
                      value: _formatDuration(_liveEtaSeconds!),
                    ),
                  ),
                ],
              ],
            ),
          if (nextInstruction != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.tomTomNextInstruction,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextInstructionDistance != null
                  ? '$nextInstruction ($nextInstructionDistance)'
                  : nextInstruction,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0A3D62)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final destination = LatLng(widget.location.lat, widget.location.lng);
    final polyline = _routeResult!.polyline;

    return FlutterMap(
      options: MapOptions(
        initialCenter: polyline.isNotEmpty ? polyline.first : destination,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=${AppConstants.tomTomApiKey}',
          userAgentPackageName: 'com.quickcity.mobile',
          maxZoom: 18,
          minZoom: 3,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: polyline,
              strokeWidth: 6,
              color: const Color(0xFF00A8E8),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (_userPosition != null)
              Marker(
                point: _userPosition!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.navigation, color: Colors.blue),
                ),
              ),
            Marker(
              point: destination,
              width: 40,
              height: 40,
              child: const Icon(Icons.flag, color: Colors.red, size: 32),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructionOverlay({
    required String title,
    required String description,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsList(AppLocalizations l10n) {
    final instructions = _routeResult!.instructions;

    if (instructions.isEmpty) {
      return Center(child: Text(l10n.tomTomNoInstructions));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.directions, color: Color(0xFF0A3D62)),
                const SizedBox(width: 8),
                Text(
                  l10n.tomTomInstructions,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                final step = instructions[index];
                final isCurrent = index == _currentInstructionIndex;
                final subtitleParts = <String>[
                  _formatDistance(step.lengthInMeters),
                  _formatDuration(step.travelTimeInSeconds.toInt()),
                  if (step.street != null && step.street!.isNotEmpty)
                    step.street!,
                ];

                return ListTile(
                  tileColor:
                      isCurrent ? const Color(0xFFE3F2FD) : Colors.transparent,
                  leading: CircleAvatar(
                    backgroundColor:
                        isCurrent ? Colors.green : const Color(0xFF0A3D62),
                    foregroundColor: Colors.white,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    step.message,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(subtitleParts.join(' • ')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) {
      return '0 dk';
    }

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours == 0) {
      return '$minutes dk';
    }

    return '${hours}s ${minutes}dk';
  }
}
