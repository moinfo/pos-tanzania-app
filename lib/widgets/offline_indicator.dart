import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_provider.dart';
import '../services/api_service.dart';

/// Widget to display offline/online status in the app bar
class OfflineIndicator extends StatefulWidget {
  final bool showSyncCount;
  final bool compact;
  final VoidCallback? onTap;

  const OfflineIndicator({
    super.key,
    this.showSyncCount = true,
    this.compact = false,
    this.onTap,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  bool _isOfflineModeEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOfflineMode();
  }

  Future<void> _checkOfflineMode() async {
    final client = await ApiService.getCurrentClient();
    debugPrint('OfflineIndicator: Client=${client.displayName}, hasOfflineMode=${client.features.hasOfflineMode}');
    if (mounted) {
      setState(() {
        _isOfflineModeEnabled = client.features.hasOfflineMode;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still loading or offline mode disabled
    if (_isLoading || !_isOfflineModeEnabled) {
      return const SizedBox.shrink();
    }

    return Consumer2<ConnectivityProvider, OfflineProvider>(
      builder: (context, connectivity, offline, child) {
        final isOnline = connectivity.isOnline;
        final pendingCount = offline.pendingSyncCount;
        final failedCount = offline.failedSyncCount;
        final isSyncing = offline.isSyncing;

        return GestureDetector(
          onTap: widget.onTap ?? () => _showSyncDialog(context, offline, connectivity),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: widget.compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: _getBackgroundColor(isOnline, isSyncing, failedCount),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: widget.compact ? 14 : 16,
                    height: widget.compact ? 14 : 16,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    _getIcon(isOnline, failedCount),
                    size: widget.compact ? 14 : 16,
                    color: Colors.white,
                  ),
                if (!widget.compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(isOnline, isSyncing, pendingCount, failedCount),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.compact ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (widget.showSyncCount && pendingCount > 0 && !isSyncing) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.compact ? 10 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(bool isOnline, bool isSyncing, int failedCount) {
    if (isSyncing) return Colors.blue;
    if (failedCount > 0) return Colors.orange;
    if (isOnline) return Colors.green;
    return Colors.grey.shade700;
  }

  IconData _getIcon(bool isOnline, int failedCount) {
    if (failedCount > 0) return Icons.warning_amber_rounded;
    if (isOnline) return Icons.cloud_done_outlined;
    return Icons.cloud_off_outlined;
  }

  String _getStatusText(bool isOnline, bool isSyncing, int pendingCount, int failedCount) {
    if (isSyncing) return 'Syncing...';
    if (failedCount > 0) return 'Sync Failed';
    if (!isOnline) return 'Offline';
    if (pendingCount > 0) return 'Pending';
    return 'Online';
  }

  void _showSyncDialog(BuildContext context, OfflineProvider offline, ConnectivityProvider connectivity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SyncStatusSheet(
        offlineProvider: offline,
        connectivityProvider: connectivity,
      ),
    );
  }
}

/// Full-width offline banner for showing at the top of screens
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if offline mode is enabled for current client
    final client = ApiService.currentClient;
    if (client == null || !client.features.hasOfflineMode) {
      return const SizedBox.shrink();
    }

    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, child) {
        if (connectivity.isOnline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange.shade700,
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You are offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Changes will sync when connection is restored',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet showing sync status and controls
class SyncStatusSheet extends StatelessWidget {
  final OfflineProvider offlineProvider;
  final ConnectivityProvider connectivityProvider;

  const SyncStatusSheet({
    super.key,
    required this.offlineProvider,
    required this.connectivityProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                connectivityProvider.isOnline
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: connectivityProvider.isOnline ? Colors.green : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectivityProvider.isOnline ? 'Connected' : 'Offline Mode',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Connection: ${connectivityProvider.connectionTypeString}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),

          // Sync Status
          _buildStatusRow(
            icon: Icons.hourglass_empty,
            label: 'Pending Sync',
            value: '${offlineProvider.pendingSyncCount} items',
            color: offlineProvider.pendingSyncCount > 0 ? Colors.orange : Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            icon: Icons.error_outline,
            label: 'Failed Sync',
            value: '${offlineProvider.failedSyncCount} items',
            color: offlineProvider.failedSyncCount > 0 ? Colors.red : Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            icon: Icons.access_time,
            label: 'Last Sync',
            value: offlineProvider.lastSyncTime != null
                ? _formatTime(offlineProvider.lastSyncTime!)
                : 'Never',
            color: Colors.grey.shade700,
          ),

          const SizedBox(height: 20),

          // Sync button
          if (connectivityProvider.isOnline) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: offlineProvider.isSyncing
                    ? null
                    : () async {
                        await offlineProvider.triggerSync();
                      },
                icon: offlineProvider.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(offlineProvider.isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (offlineProvider.failedSyncCount > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: offlineProvider.isSyncing
                      ? null
                      : () async {
                          await offlineProvider.retryFailedSync();
                        },
                  icon: const Icon(Icons.replay),
                  label: const Text('Retry Failed Items'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connect to the internet to sync your data',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Master data sync progress
          if (offlineProvider.isSyncingMasterData) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offlineProvider.masterDataSyncStatus ?? 'Syncing...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: offlineProvider.masterDataSyncProgress,
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Small sync status badge for compact display
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if offline mode is enabled for current client
    final client = ApiService.currentClient;
    if (client == null || !client.features.hasOfflineMode) {
      return const SizedBox.shrink();
    }

    return Consumer<OfflineProvider>(
      builder: (context, offline, child) {
        final count = offline.pendingSyncCount + offline.failedSyncCount;

        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: offline.failedSyncCount > 0 ? Colors.red : Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                offline.isSyncing
                    ? Icons.sync
                    : (offline.failedSyncCount > 0 ? Icons.error : Icons.cloud_upload),
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
