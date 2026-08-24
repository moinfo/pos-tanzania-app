import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pending_upload.dart';
import '../providers/offline_provider.dart';
import '../screens/pending_uploads_screen.dart';
import '../utils/constants.dart';

/// Makes a rejected record impossible to miss.
///
/// WHY A DIALOG, AND WHY IT COMES BACK
///
/// A rejected record is the one place in this app where data dies without
/// anybody being told. The upload machinery will never move it: the server
/// looked at it and refused, so every retry replays the same refusal. The
/// goods have already left the shop, or the money has already been paid out.
/// The only thing that can save it is a person finding out.
///
/// So the bar this has to clear is not "is it displayed somewhere" -- a count
/// in Settings is displayed somewhere, and a seller who never opens Settings
/// will never see it. The bar is: *the app must not be usable for long by
/// somebody who has not been told.* That rules out a badge, a snackbar (gone
/// in four seconds), a banner on one screen (invisible from every other), and
/// a notification (this build has no FCM on four of five clients and the
/// notification tray is where things go to be swiped away).
///
/// What is left is a modal that:
///
///   * appears over whatever screen the person is on, since it is mounted
///     above the Navigator rather than inside any one route;
///   * cannot be dismissed by tapping outside it or by the back button -- only
///     by choosing one of two named buttons, so it cannot be cleared by
///     accident while the phone is in a pocket;
///   * is answered by reading the record, not by closing a box: "Later" brings
///     it back next time the app starts, because the fact that it was seen
///     lives in SQLite (`rejection_ack_at`) rather than in memory. Killing the
///     app is not an acknowledgement. Neither is a crash, a battery death, or
///     handing the phone to the next shift.
///
/// It is deliberately possible to say "Later", because a modal that traps a
/// seller mid-sale would get the app put down instead of the record fixed.
/// What is not possible is saying "Later" once and never hearing about it
/// again.
class RejectionAlertHost extends StatefulWidget {
  const RejectionAlertHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The app's navigator. This widget sits ABOVE it, so it has no Navigator of
  /// its own to push a dialog into -- the key is how it reaches the one that
  /// covers every screen.
  final GlobalKey<NavigatorState> navigatorKey;

  final Widget child;

  @override
  State<RejectionAlertHost> createState() => _RejectionAlertHostState();
}

class _RejectionAlertHostState extends State<RejectionAlertHost> {
  /// A dialog is on screen right now. Without this, a rebuild while the dialog
  /// is open stacks a second one on top of the first.
  bool _showing = false;

  /// The person said "Later" for the refusals they had at that moment. Held in
  /// memory ONLY, so it lasts exactly as long as this run of the app.
  bool _snoozed = false;

  /// The count the last check saw. A rise means a NEW refusal has happened
  /// since the person said "Later", and a new one has not been snoozed.
  int _lastCount = 0;

  @override
  Widget build(BuildContext context) {
    final count = context.watch<OfflineProvider>().unreadRejectionCount;

    if (count > _lastCount) _snoozed = false;
    _lastCount = count;

    if (count > 0 && !_snoozed && !_showing) {
      // After the frame: this runs during build, and a route cannot be pushed
      // while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) => _raise());
    }

    return widget.child;
  }

  Future<void> _raise() async {
    if (_showing || _snoozed) return;

    final navigator = widget.navigatorKey.currentState;
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigator == null || navigatorContext == null) return;

    final offline = context.read<OfflineProvider>();
    if (offline.unreadRejectionCount == 0) return;

    _showing = true;
    try {
      final action = await showDialog<_AlertAction>(
        context: navigatorContext,
        // Neither of these may be relaxed. A tap on the dark area outside a
        // dialog, or a back swipe, is exactly the accidental dismissal this
        // has to survive.
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: _RejectionDialog(count: offline.unreadRejectionCount),
        ),
      );

      if (action == _AlertAction.open) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const PendingUploadsScreen(),
          ),
        );
      } else {
        // Quiet until the app is restarted or another record is refused.
        _snoozed = true;
      }
    } finally {
      _showing = false;
    }
  }
}

enum _AlertAction { open, later }

class _RejectionDialog extends StatelessWidget {
  const _RejectionDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.raised(context),
      icon: const Icon(Icons.report_problem, color: AppColors.error, size: 34),
      title: Text(
        count == 1
            ? 'One record was refused'
            : '$count records were refused',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.error, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1
                ? 'The server looked at it and would not take it. It will '
                    'never upload on its own, no matter how long you wait.'
                : 'The server looked at them and would not take them. They '
                    'will never upload on their own, no matter how long you '
                    'wait.',
            style: TextStyle(fontSize: 14, color: AppColors.ink(context)),
          ),
          const SizedBox(height: 12),
          // The names, not just a number. "3 records" sends somebody hunting;
          // "Expense - Fuel" tells them straight away whether it is theirs.
          const _RejectionNames(),
          const SizedBox(height: 12),
          Text(
            'Nothing has been deleted. Open the list to read why, try again, '
            'or copy the details.',
            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_AlertAction.later),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_AlertAction.open),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Show me'),
        ),
      ],
    );
  }
}

/// Up to three of the refused records by name, so the warning is about
/// something rather than about a number.
class _RejectionNames extends StatelessWidget {
  const _RejectionNames();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PendingUpload>>(
      future: context.read<OfflineProvider>().loadPendingUploads(),
      builder: (context, snapshot) {
        final rejected = (snapshot.data ?? const <PendingUpload>[])
            .where((i) => i.isUnreadRejection)
            .toList();
        if (rejected.isEmpty) return const SizedBox.shrink();

        final shown = rejected.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(
                        _name(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (rejected.length > shown.length)
              Text(
                'and ${rejected.length - shown.length} more',
                style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
              ),
          ],
        );
      },
    );
  }

  static String _name(PendingUpload item) {
    final bits = <String>[
      item.kind,
      if (item.detail != null) item.detail!,
      if (item.amount != null) item.amount!.toStringAsFixed(0),
    ];
    return bits.join('  -  ');
  }
}
