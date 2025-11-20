import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/work_session_service.dart';
import '../services/geofencing_service.dart';
import '../services/background_location_service.dart';
import '../services/auth_service.dart';
import '../models/location.dart';
import '../models/auto_checkin_settings.dart';

class WorkSessionHeader extends StatelessWidget {
  final List<Location> locations;
  final VoidCallback onSessionStarted;
  final VoidCallback onSessionEnded;

  const WorkSessionHeader({
    super.key,
    required this.locations,
    required this.onSessionStarted,
    required this.onSessionEnded,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkSessionService>(
      builder: (context, sessionService, child) {
        if (sessionService.isSessionActive) {
          return _buildActiveSession(context, sessionService);
        } else {
          return _buildStartButton(context, sessionService);
        }
      },
    );
  }

  // İş oturumu aktif değil - Başlat butonu
  Widget _buildStartButton(BuildContext context, WorkSessionService sessionService) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () => _showStartConfirmation(context, sessionService),
        icon: const Icon(Icons.play_arrow, size: 28),
        label: Text(
          '❄️ ${l10n.startWork}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // İş oturumu aktif - Durum kartı
  Widget _buildActiveSession(BuildContext context, WorkSessionService sessionService) {
    final l10n = AppLocalizations.of(context)!;
    final session = sessionService.currentSession!;
    final duration = DateTime.now().difference(session.startedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '🛰️ ${l10n.workSessionActive}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // İstatistikler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '⏱️',
                '${hours}s ${minutes}dk',
                l10n.duration,
              ),
              _buildStatItem(
                '✅',
                '${sessionService.completedCount}/${session.totalAssignedLocations}',
                l10n.completed,
              ),
              _buildStatItem(
                '📍',
                '${session.remainingLocations}',
                l10n.remaining,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Bitir butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEndConfirmation(context, sessionService),
              icon: const Icon(Icons.stop),
              label: Text(
                l10n.endWork,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // İşe başlama onay dialogu
  Future<void> _showStartConfirmation(
    BuildContext context,
    WorkSessionService sessionService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // Önce backend'den aktif oturum kontrol et
    await sessionService.loadActiveSession();
    
    if (sessionService.isSessionActive && context.mounted) {
      // Aktif oturum var, devam etmek ister misin sor
      final continueSession = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('⚠️ ${AppLocalizations.of(context)!.activeWorkSessionFound}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.previousSessionFound,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('✅ ${AppLocalizations.of(context)!.completed}: ${sessionService.completedCount}'),
              Text('📍 ${AppLocalizations.of(context)!.remaining}: ${sessionService.currentSession!.remainingLocations}'),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.continueQuestion),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.continueWork),
            ),
          ],
        ),
      );
      
      if (continueSession == true && context.mounted) {
        // GPS'i tekrar başlat
        final geofencingService = GeofencingService();
        await geofencingService.startTracking(
          locations: locations.where((loc) {
            final status = sessionService.getLocationStatus(loc.id);
            return status != 'completed';
          }).toList(),
          onArrival: (location, position) async {
            // Otomatik ayarları kontrol et
            final autoSettings = await AutoCheckInSettings.load();
            
            // Otomatik check-in aktifse dialog gösterme
            if (autoSettings.autoCheckInEnabled) {
              print('🤖 Otomatik check-in aktif - Manuel dialog gösterilmiyor');
              return;
            }
            
            // Otomatik check-in kapalıysa manuel dialog göster
            _showArrivalDialog(context, location, position, sessionService);
          },
        );
        
        onSessionStarted();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${l10n.continueWorkSession}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    
    // Aktif oturum yok, yeni başlat
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('❄️ ${AppLocalizations.of(context)!.startWorkSessionTitle}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.snowClearingWork,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('📍 ${l10n.totalLocations.replaceAll('@count', '${locations.length}')}'),
            const SizedBox(height: 8),
            Text('🛰️ ${l10n.gpsTrackingEnabled}'),
            Text('📱 ${l10n.proximityNotifications}'),
            Text('⏱️ ${l10n.canStopAnytime}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.start),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _startWorkSession(context, sessionService);
    }
  }

  // İş oturumu başlat
  Future<void> _startWorkSession(
    BuildContext context,
    WorkSessionService sessionService,
  ) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 0. Token'ı set et (önemli!)
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.token != null) {
        sessionService.setToken(authService.token!);
      }
      
      // 1. İş oturumunu başlat
      final result = await sessionService.startWorkSession(
        totalLocations: locations.length,
        locations: locations,
      );

      if (context.mounted) {
        Navigator.pop(context); // Loading kapat
        final l10n = AppLocalizations.of(context)!;

        if (result['success'] == true) {
          // 2. Background GPS tracking'i başlat (Uygulama arka plana alınsa bile çalışır)
          final locationsToTrack = locations.where((loc) {
            // Sadece tamamlanmamış lokasyonları izle
            final status = sessionService.getLocationStatus(loc.id);
            return status != 'completed';
          }).toList();
          
          // Background service için lokasyon listesi hazırla
          final trackingLocations = locationsToTrack.map((location) => {
            'id': location.id,
            'lat': location.lat,
            'lng': location.lng,
            'address': location.displayAddress,
          }).toList();
          
          // Background service'i başlat
          await BackgroundLocationService.startService(trackingLocations);
          print('🛰️ Background GPS tracking başlatıldı - ${trackingLocations.length} lokasyon');
          
          // 3. Foreground GPS tracking'i başlat (Uygulama açıkken)
          final geofencingService = GeofencingService();
          await geofencingService.startTracking(
            locations: locationsToTrack,
            onArrival: (location, position) async {
              // Otomatik ayarları kontrol et
              final autoSettings = await AutoCheckInSettings.load();
              
              // Otomatik check-in aktifse dialog gösterme
              if (autoSettings.autoCheckInEnabled) {
                print('🤖 Otomatik check-in aktif - Manuel dialog gösterilmiyor');
                return;
              }
              
              // Otomatik check-in kapalıysa manuel dialog göster
              _showArrivalDialog(context, location, position, sessionService);
            },
          );

          // Callback çağır
          onSessionStarted();

          // Başarı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${l10n.workSessionStarted}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Hata mesajı - Detaylı göster
          final errorDetails = result['error_details'];
          String errorMessage = result['message'] ?? l10n.unknownError;
          
          print('🔴 Backend Error: $errorMessage');
          if (errorDetails != null) {
            print('🔴 Error Details: $errorDetails');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Dialog ile detaylı hata göster
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('🔴 ${l10n.errorDetails}'),
              content: SingleChildScrollView(
                child: SelectableText(errorDetails?.toString() ?? errorMessage),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Loading kapat
        final l10n = AppLocalizations.of(context)!;
        print('🔴 CATCH ERROR: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${l10n.error.replaceAll('@error', e.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // İş bitirme onay dialogu
  Future<void> _showEndConfirmation(
    BuildContext context,
    WorkSessionService sessionService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final session = sessionService.currentSession!;
    final remaining = session.remainingLocations;
    final completed = sessionService.completedCount;
    
    // Hiç lokasyona check-in yapılmamışsa uyar (ama yine de bitirmesine izin ver)
    if (completed == 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('⚠️ ${l10n.attention}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                l10n.noCheckInYet,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(l10n.stillEndSession),
              const SizedBox(height: 8),
              Text(
                l10n.forTestOrCancel,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.yesEnd),
            ),
          ],
        ),
      );
      
      if (proceed != true) {
        return; // Kullanıcı hayır dedi, iptal et
      }
      // Evet dedi, devam et (aşağıdaki normal bitirme dialogu açılacak)
    }
    
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📊 ${l10n.endWorkSession}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⏱️ ${l10n.startTime.replaceAll('@time', '${session.startedAt.hour}:${session.startedAt.minute.toString().padLeft(2, '0')}')}',
              ),
              Text(
                '⏱️ ${l10n.currentTime.replaceAll('@time', '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}')}',
              ),
              const SizedBox(height: 8),
              Text(
                '✅ ${l10n.locationsCompleted.replaceAll('@completed', '${sessionService.completedCount}').replaceAll('@total', '${session.totalAssignedLocations}')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (remaining > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.locationsNotCompleted.replaceAll('@remaining', '$remaining'),
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                  hintText: 'Örn: Ağır kar yağışı, zor şartlar',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.endWork),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _endWorkSession(context, sessionService, noteController.text);
    }
  }

  // İş oturumu bitir
  Future<void> _endWorkSession(
    BuildContext context,
    WorkSessionService sessionService,
    String? note,
  ) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 1. GPS tracking'i durdur
      final geofencingService = GeofencingService();
      await geofencingService.stopTracking();

      // 2. İş oturumunu bitir
      final result = await sessionService.endWorkSession(
        workNote: note,
      );

      if (context.mounted) {
        Navigator.pop(context); // Loading kapat

        if (result['success'] == true) {
          // Callback çağır
          onSessionEnded();

          // Başarı mesajı
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${l10n.workSessionCompletedGpsStopped}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          final l10n = AppLocalizations.of(context)!;
          // Hata mesajı - Detaylı göster
          final errorDetails = result['error_details'];
          String errorMessage = result['message'] ?? l10n.unknownError;
          
          // 422 hatası varsa özel mesaj
          if (errorDetails != null && errorDetails.toString().contains('422')) {
            errorMessage = 'İş oturumunu bitirmek için en az 1 lokasyona check-in/out yapmalısınız!';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Açıklayıcı dialog göster
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('⚠️ ${l10n.operationFailed}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(errorMessage),
                  const SizedBox(height: 16),
                  Text(l10n.whyThisError),
                  const SizedBox(height: 8),
                  Text('• ${l10n.noCheckInYetBullet}'),
                  Text('• ${l10n.orNotCompletedLocation}'),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.understood),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Loading kapat
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${l10n.error.replaceAll('@error', e.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Lokasyona varış dialogu
  void _showArrivalDialog(
    BuildContext context,
    Location location,
    dynamic position,
    WorkSessionService sessionService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📍 ${l10n.arrivedAtLocation}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.displayAddress,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text('Cluster: ${location.clusterLabel}'),
            const SizedBox(height: 16),
            Text(l10n.doYouWantToStartWork),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.no),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkInLocation(context, location, position, sessionService);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.yesIStarted),
          ),
        ],
      ),
    );
  }

  // Lokasyona check-in
  Future<void> _checkInLocation(
    BuildContext context,
    Location location,
    dynamic position,
    WorkSessionService sessionService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await sessionService.checkInLocation(
        location: location,
        position: position,
      );

      if (context.mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${l10n.checkInSuccess}: ${location.displayAddress}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${l10n.error.replaceAll('@error', e.toString())}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

