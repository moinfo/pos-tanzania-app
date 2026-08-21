import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/update_provider.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';
import '../widgets/glassmorphic_card.dart';

/// The place in the app to update from.
///
/// Reachable two ways on purpose: from the drawer, where it carries a dot
/// while an update is waiting, and from Settings under APP UPDATE. That second
/// route is what makes "Later" safe — a deferred update is never lost, it is
/// sitting here for the next three days and after them.
///
/// This screen deliberately ignores the snooze. Snoozing silences the
/// unprompted sheet; it does not hide the update from someone who came looking
/// for it.
class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  DateTime? _snoozedUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final updates = context.read<UpdateProvider>();
      updates.loadInstalledVersion();
      // Re-check on open rather than trusting the sign-in check: someone who
      // navigates here is asking the question now.
      updates.check().then((_) => _refreshSnooze());
    });
  }

  Future<void> _refreshSnooze() async {
    final until = await context.read<UpdateProvider>().snoozedUntil();
    if (mounted) setState(() => _snoozedUntil = until);
  }

  Future<void> _openStore() async {
    final updates = context.read<UpdateProvider>();
    final opened = await updates.openStore();
    if (!mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the store. Search for this app in the store to update.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    _refreshSnooze();
  }

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<UpdateProvider>();

    return Scaffold(
      backgroundColor: AppColors.ground(context),
      appBar: AppBar(title: const Text('App Update')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _installedCard(context, updates),
          const SizedBox(height: 16),
          _statusCard(context, updates),
          if (_snoozedUntil != null && updates.updateAvailable) ...[
            const SizedBox(height: 12),
            _snoozeNote(context),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- installed

  Widget _installedCard(BuildContext context, UpdateProvider updates) {
    return GlassmorphicCard(
      isDark: AppColors.isDark(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.phone_android,
                  color: AppColors.brandPrimary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installed version',
                    style: TextStyle(
                      color: AppColors.muted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    updates.installedLabel,
                    style: TextStyle(
                      color: AppColors.ink(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ status

  Widget _statusCard(BuildContext context, UpdateProvider updates) {
    if (updates.isChecking) {
      return _shell(
        context,
        accent: AppColors.info,
        icon: Icons.sync,
        title: 'Checking for updates',
        body: 'Asking the server what the latest version is.',
        showSpinner: true,
      );
    }

    switch (updates.state) {
      case UpdateState.updateAvailable:
        final latest = updates.latest!;
        return _shell(
          context,
          accent: AppColors.success,
          icon: Icons.system_update,
          title: 'Update available',
          body: 'Version ${latest.versionName} (${latest.versionCode}) '
              'is available in the store.',
          notes: latest.releaseNotes,
          primaryLabel: 'Update Now',
          onPrimary: _openStore,
        );

      case UpdateState.upToDate:
        // No button at all here. A greyed-out "Update" that does nothing reads
        // as broken; the sentence is the whole answer.
        return _shell(
          context,
          accent: AppColors.success,
          icon: Icons.verified,
          title: 'You are up to date',
          body: 'This is the latest version available for your device.',
          secondaryLabel: 'Check Again',
          onSecondary: () => context.read<UpdateProvider>().check(),
        );

      case UpdateState.checkFailed:
      case UpdateState.unknown:
        return _shell(
          context,
          accent: AppColors.warning,
          icon: Icons.cloud_off,
          title: 'Could not check for updates',
          body: 'Check your connection and try again. You can keep using the '
              'app in the meantime.',
          secondaryLabel: 'Retry',
          onSecondary: () => context.read<UpdateProvider>().check(),
        );
    }
  }

  Widget _snoozeNote(BuildContext context) {
    final until = _snoozedUntil!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule, size: 16, color: AppColors.muted(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'You chose to update later. You will not be reminded again until '
            '${_shortDate(until)} — this screen always shows it in the meantime.',
            style: TextStyle(
              color: AppColors.muted(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime when) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${when.day} ${months[when.month - 1]}';
  }

  /// One card shape for every state, so the screen does not visibly change
  /// layout as the check resolves.
  Widget _shell(
    BuildContext context, {
    required Color accent,
    required IconData icon,
    required String title,
    required String body,
    String? notes,
    String? primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool showSpinner = false,
  }) {
    return GlassmorphicCard(
      isDark: AppColors.isDark(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: showSpinner
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(accent),
                          ),
                        )
                      : Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.ink(context),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                color: AppColors.muted(context),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (notes != null) ...[
              const SizedBox(height: 16),
              Text(
                "WHAT'S NEW",
                style: TextStyle(
                  color: AppColors.muted(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sunken(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline(context)),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    color: AppColors.ink(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (primaryLabel != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(primaryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onSecondary,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(secondaryLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
