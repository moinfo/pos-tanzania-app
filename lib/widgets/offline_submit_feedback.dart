import 'package:flutter/material.dart';

import '../services/offline_submit.dart';
import '../utils/constants.dart';
import 'offline_indicator.dart';

/// Tell the person what happened, in the same words everywhere.
///
/// Deliberately one function rather than a snackbar per screen: "it is on the
/// device and will upload itself" is a promise the app makes, and a promise
/// phrased eleven different ways is not one people learn to trust.
void showOfflineSubmitFeedback(
  BuildContext context,
  OfflineSubmitResult<dynamic> result,
) {
  if (result.isSent) return; // the screen shows its own success

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  switch (result.outcome) {
    case OfflineSubmitOutcome.sent:
      return;

    case OfflineSubmitOutcome.queued:
      messenger.showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Details',
          textColor: AppColors.white,
          onPressed: () => showSyncStatusSheet(context),
        ),
      ));
      return;

    case OfflineSubmitOutcome.lost:
      messenger.showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 8),
      ));
      return;

    case OfflineSubmitOutcome.rejected:
      messenger.showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ));
      return;
  }
}
