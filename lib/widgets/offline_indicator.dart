import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectivityService = Provider.of<ConnectivityService>(context);
    final syncService = Provider.of<SyncService>(context);

    return StreamBuilder<bool>(
      stream: connectivityService.connectionStatus,
      initialData: connectivityService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (isOnline && syncService.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isOnline ? Colors.orange[100] : Colors.red[100],
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.sync : Icons.cloud_off,
                size: 20,
                color: isOnline ? Colors.orange[900] : Colors.red[900],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? l10n.pendingIssues.replaceAll('@count', syncService.pendingCount.toString())
                      : l10n.offlineMode,
                  style: TextStyle(
                    fontSize: 13,
                    color: isOnline ? Colors.orange[900] : Colors.red[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isOnline && syncService.pendingCount > 0 && !syncService.isSyncing)
                TextButton(
                  onPressed: () => syncService.syncPendingIssues(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.synchronize,
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (syncService.isSyncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOnline ? Colors.orange[900]! : Colors.red[900]!,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Basit offline badge (AppBar için)
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectivityService = Provider.of<ConnectivityService>(context);

    return StreamBuilder<bool>(
      stream: connectivityService.connectionStatus,
      initialData: connectivityService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red[700],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                l10n.offline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
