import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../services/offline_feature.dart';

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
        // "Online" here means the server can actually be reached, not merely
        // that a radio is up. A green pill over a queue that is not draining
        // is the one thing this widget must never show.
        final isOnline = offline.canReachServer;
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
                      color: AppColors.white,
                    ),
                  )
                else
                  Icon(
                    _getIcon(isOnline, failedCount),
                    size: widget.compact ? 14 : 16,
                    color: AppColors.white,
                  ),
                if (!widget.compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(isOnline, isSyncing, pendingCount, failedCount),
                    style: TextStyle(
                      color: AppColors.white,
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
                      color: AppColors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: TextStyle(
                        color: AppColors.white,
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
    if (isSyncing) return AppColors.info;
    if (failedCount > 0) return AppColors.error;
    if (isOnline) return AppColors.success;
    return AppColors.warning;
  }

  IconData _getIcon(bool isOnline, int failedCount) {
    if (failedCount > 0) return Icons.warning_amber_rounded;
    if (isOnline) return Icons.cloud_done_outlined;
    return Icons.cloud_off_outlined;
  }

  String _getStatusText(bool isOnline, bool isSyncing, int pendingCount, int failedCount) {
    if (isSyncing) return 'Uploading...';
    // Failures come first: a sale the server refused needs a person, and it
    // stays on screen whether or not the connection has since come back.
    if (failedCount > 0) return failedCount == 1 ? '1 failed' : '$failedCount failed';
    if (!isOnline) return pendingCount > 0 ? 'Offline - $pendingCount waiting' : 'Offline';
    if (pendingCount > 0) return '$pendingCount waiting';
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

/// Open the sync detail sheet from anywhere that has an OfflineProvider above
/// it. Kept as a function so a snackbar action or an app-bar tap does not each
/// have to know how the sheet is built.
void showSyncStatusSheet(BuildContext context) {
  final offline = context.read<OfflineProvider>();
  final connectivity = context.read<ConnectivityProvider>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.raised(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SyncStatusSheet(
      offlineProvider: offline,
      connectivityProvider: connectivity,
    ),
  );
}

/// Full-width status strip for the top of a screen.
///
/// Shows whenever the seller is not in the plain everything-is-fine state, and
/// it says which of three quite different situations they are in, because the
/// right response differs:
///
///   * no network at all -- expected, sales are being kept, carry on selling;
///   * network but the server is not answering -- also kept, but worth telling
///     someone if it lasts, because from the phone's own icons it looks fine;
///   * a sale the server refused -- nothing will fix itself, a person must look.
///
/// A queue nobody can see is worse than no queue: a seller who does not know a
/// sale never uploaded will not chase it. So the strip stays up, with a count,
/// for as long as anything is waiting -- online or not.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if offline mode is enabled for current client
    final client = ApiService.currentClient;
    if (client == null || !client.features.hasOfflineMode) {
      return const SizedBox.shrink();
    }

    return Consumer2<ConnectivityProvider, OfflineProvider>(
      builder: (context, connectivity, offline, child) {
        final pending = offline.pendingSaleCount;
        final failed = offline.failedSaleCount;
        // Expenses, receivings, banking, submissions, requests, people. Kept
        // separate from the sale counts in the wording -- telling a seller
        // "3 sales waiting" when two of them are expenses sends them looking
        // for receipts that were never missing.
        final otherPending = offline.pendingActionCount;
        final otherFailed = offline.failedActionCount;
        final noNetwork = connectivity.isOffline;
        final noServer = !noNetwork && !offline.serverReachable;

        // Everything is online, reachable and empty: say nothing.
        if (!noNetwork &&
            !noServer &&
            pending == 0 &&
            failed == 0 &&
            otherPending == 0 &&
            otherFailed == 0) {
          return const SizedBox.shrink();
        }

        final Color background;
        final IconData icon;
        final String title;
        final String detail;

        if (failed > 0 || otherFailed > 0) {
          background = AppColors.error;
          icon = Icons.report_problem_outlined;
          title = failed > 0
              ? (failed == 1
                  ? '1 sale could not be uploaded'
                  : '$failed sales could not be uploaded')
              : (otherFailed == 1
                  ? '1 record could not be uploaded'
                  : '$otherFailed records could not be uploaded');
          detail = 'The server refused it. Tap to see why.';
        } else if (noNetwork) {
          background = AppColors.warning;
          icon = Icons.cloud_off;
          // With queueing switched off this strip must not promise that work
          // is being kept: it is shown ON the sale screen, so a seller who
          // believes it serves the customer first and finds out afterwards.
          // What is already queued still uploads, which is why the counts are
          // still reported either way.
          final canKeepWorking = OfflineFeature.enabled;
          title = canKeepWorking
              ? 'No connection - you can keep working'
              : 'Hakuna mtandao / No connection';
          if (!canKeepWorking) {
            detail = (pending == 0 && otherPending == 0)
                ? 'Huwezi kuuza bila mtandao. Subiri mtandao urudi. / Sales need a connection - nothing can be recorded until it returns.'
                : '${_waitingWord(pending, otherPending)} saved earlier, uploading by itself when the network returns. New work needs a connection.';
          } else {
            detail = (pending == 0 && otherPending == 0)
                ? 'What you record is saved here and uploads by itself later.'
                : '${_waitingWord(pending, otherPending)} saved here, uploading by itself when the network returns.';
          }
        } else if (noServer) {
          background = AppColors.warning;
          icon = Icons.cloud_off;
          title = 'Cannot reach the server';
          detail = (pending == 0 && otherPending == 0)
              ? 'You have a connection but the server is not answering.'
              : '${_waitingWord(pending, otherPending)} waiting. Retrying by itself.';
        } else {
          background = AppColors.info;
          icon = Icons.cloud_upload_outlined;
          title = '${_waitingWord(pending, otherPending)} still uploading';
          detail = offline.isSyncing
              ? 'Uploading now.'
              : 'This happens by itself - nothing to press.';
        }

        return Material(
          color: background,
          child: InkWell(
            onTap: () => showSyncStatusSheet(context),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            detail,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (offline.isSyncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.white.withValues(alpha: 0.9),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _saleWord(int n) => n == 1 ? '1 sale' : '$n sales';

  /// "2 sales", "1 record", or "2 sales and 1 record" -- whichever is true.
  ///
  /// Naming both kinds matters: a clerk who queued an expense and is told only
  /// about sales has no way to know their expense is safe, and a seller told
  /// about "3 items" cannot tell whether a receipt is among them.
  static String _otherWord(int n) => n == 1 ? '1 record' : '$n records';

  static String _waitingWord(int sales, int others) {
    if (sales > 0 && others > 0) {
      return '${_saleWord(sales)} and ${_otherWord(others)}';
    }
    if (others > 0) return _otherWord(others);
    return _saleWord(sales);
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
                offlineProvider.canReachServer
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: offlineProvider.canReachServer
                    ? AppColors.success
                    : AppColors.warning,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offlineProvider.canReachServer
                          ? 'Connected'
                          : connectivityProvider.isOffline
                              ? 'No connection'
                              : 'Server not answering',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Connection: ${connectivityProvider.connectionTypeString}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted(context),
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
            context,
            icon: Icons.hourglass_empty,
            label: 'Waiting to upload',
            value: '${offlineProvider.pendingSyncCount}',
            color: offlineProvider.pendingSyncCount > 0
                ? AppColors.warning
                : AppColors.success,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            context,
            icon: Icons.error_outline,
            label: 'Refused by server',
            value: '${offlineProvider.failedSyncCount}',
            color: offlineProvider.failedSyncCount > 0
                ? AppColors.error
                : AppColors.success,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            context,
            icon: Icons.access_time,
            label: 'Last upload',
            value: offlineProvider.lastSyncTime != null
                ? _formatTime(offlineProvider.lastSyncTime!)
                : 'Never',
            color: AppColors.muted(context),
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
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  offlineProvider.isSyncing ? 'Uploading...' : 'Upload now',
                ),
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
                  label: const Text('Try refused sales again'),
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
                color: AppColors.sunken(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.muted(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sales are safe on this device. They upload by '
                      'themselves as soon as the network returns - there is '
                      'nothing you need to press.',
                      style: TextStyle(
                        color: AppColors.muted(context),
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
                    color: AppColors.muted(context),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: offlineProvider.masterDataSyncProgress,
                  backgroundColor: AppColors.track(context),
                ),
              ],
            ),
          ],

          // The sales themselves, not just a number. A seller chasing a
          // missing receipt needs to know WHICH sale is stuck and what the
          // server said about it -- a bare count sends them to the office
          // with nothing to go on.
          const SizedBox(height: 20),
          Text(
            'Sales not yet on the server',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: offlineProvider.getUnsyncedSales(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }

                final sales = snapshot.data ?? const [];
                if (sales.isEmpty) {
                  return Text(
                    'Everything has been uploaded.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted(context),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 12,
                    color: AppColors.hairline(context),
                  ),
                  itemBuilder: (context, i) => _buildQueuedSaleRow(context, sales[i]),
                );
              },
            ),
          ),

          // Everything else that is waiting -- expenses, receivings, banking,
          // submissions, requests, customers, suppliers. Listed apart from the
          // sales so a clerk chasing an expense is not reading a list of
          // receipts, and shown at all because a queue nobody can see is worse
          // than no queue.
          const SizedBox(height: 20),
          Text(
            'Other records not yet on the server',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: offlineProvider.getUnsyncedActions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }

                final actions = snapshot.data ?? const [];
                if (actions.isEmpty) {
                  return Text(
                    'Everything has been uploaded.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted(context),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: actions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 12,
                    color: AppColors.hairline(context),
                  ),
                  itemBuilder: (context, i) =>
                      _buildQueuedActionRow(context, actions[i]),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// One queued record: what kind it is, which one, and -- when it is stuck --
  /// the server's own words for why.
  Widget _buildQueuedActionRow(BuildContext context, Map<String, dynamic> row) {
    final isFailed = row['sync_status'] == DatabaseService.syncStatusFailed;
    final label = (row['label'] as String?)?.trim();
    final summary = (row['summary'] as String?)?.trim();
    final error = (row['sync_error'] ?? row['error_message']) as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isFailed ? Icons.error_outline : Icons.schedule,
          size: 18,
          color: isFailed ? AppColors.error : AppColors.warning,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary == null || summary.isEmpty
                    ? (label ?? 'Record')
                    : '${label ?? 'Record'}  -  $summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isFailed
                    ? (error?.trim().isNotEmpty == true
                        ? error!.trim()
                        : 'The server refused this record.')
                    : 'Waiting to upload.',
                style: TextStyle(
                  fontSize: 12,
                  color: isFailed ? AppColors.error : AppColors.muted(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One queued sale: when it was rung up, what it came to, and -- when it is
  /// stuck -- the server's own words for why.
  Widget _buildQueuedSaleRow(BuildContext context, Map<String, dynamic> sale) {
    final isFailed = sale['sync_status'] == DatabaseService.syncStatusFailed;
    final total = (sale['total'] as num?)?.toDouble() ?? 0;
    final error = (sale['sync_error'] ?? sale['error_message']) as String?;
    final saleTime = sale['sale_time'] as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isFailed ? Icons.error_outline : Icons.schedule,
          size: 18,
          color: isFailed ? AppColors.error : AppColors.warning,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatSaleTime(saleTime)}  -  ${total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isFailed
                    ? (error?.trim().isNotEmpty == true
                        ? error!.trim()
                        : 'The server refused this sale.')
                    : 'Waiting to upload.',
                style: TextStyle(
                  fontSize: 12,
                  color: isFailed ? AppColors.error : AppColors.muted(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sale time as the seller would recognise it, falling back to the raw value
  /// rather than hiding a row we could not parse.
  static String _formatSaleTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown time';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildStatusRow(
    BuildContext context, {
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
            color: AppColors.muted(context),
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
            color: offline.failedSyncCount > 0
                ? AppColors.error
                : AppColors.warning,
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
                color: AppColors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.white,
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
