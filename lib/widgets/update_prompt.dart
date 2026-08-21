import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/update_provider.dart';
import '../screens/app_update_screen.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';

/// Tell the user a new version exists, without trapping them in it.
///
/// This is a bottom sheet and not a dialog, and it is dismissible by every
/// route out: the Later button, tapping the scrim, dragging it down, and the
/// system back gesture. There is no barrier the user cannot get past and no
/// gate in front of the app — a seller who is mid-sale swipes it away and
/// carries on, and the sale state is untouched because nothing here reads or
/// writes it.
///
/// Every one of those exits means the same thing and is recorded the same way:
/// deferred for [UpdateService.snoozeDuration]. Treating a swipe as "ask me
/// again next launch" is precisely the nagging the brief rules out.
Future<void> maybeShowUpdatePrompt(BuildContext context) async {
  final updates = context.read<UpdateProvider>();

  if (!await updates.shouldPrompt()) return;
  if (!context.mounted) return;

  // Nothing should land on top of a pushed screen or an open dialog. If the
  // user has already navigated somewhere since the check started, the update
  // keeps: it is on the update screen, and the next sign-in will offer it
  // again once the snooze lapses.
  if (ModalRoute.of(context)?.isCurrent != true) return;

  updates.markPrompted();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _UpdateSheet(updates: updates),
  );

  // Reached however the sheet closed, including a swipe or a back gesture.
  await updates.snooze();
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({required this.updates});

  final UpdateProvider updates;

  @override
  Widget build(BuildContext context) {
    final latest = updates.latest;
    if (latest == null) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.raised(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The drag handle is not decoration: it is the affordance that
            // says this sheet can be pushed away.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.system_update,
                      color: AppColors.brandPrimary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update available',
                        style: TextStyle(
                          color: AppColors.ink(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${latest.versionName} '
                        '• you have ${updates.installedVersionName}',
                        style: TextStyle(
                          color: AppColors.muted(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (latest.releaseNotes != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sunken(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline(context)),
                ),
                child: Text(
                  latest.releaseNotes!,
                  style: TextStyle(
                    color: AppColors.ink(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.muted(context),
                      side: BorderSide(color: AppColors.hairline(context)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final opened = await updates.openStore();
                      navigator.pop();
                      if (!opened) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open the store. Search for this app '
                              'in the store to update.',
                            ),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Update Now'),
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
            ),
            const SizedBox(height: 12),
            // Says out loud that Later is safe, and where the update went.
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppUpdateScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 15, color: AppColors.muted(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No rush — you can update any time from '
                        'Settings › App Update.',
                        style: TextStyle(
                          color: AppColors.muted(context),
                          fontSize: 12,
                        ),
                      ),
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
}
