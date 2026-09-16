import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/api_response.dart';
import '../providers/offline_provider.dart';
import 'offline_actions.dart';
import 'offline_feature.dart';

/// What became of one attempt to create something.
enum OfflineSubmitOutcome {
  /// The server took it. [OfflineSubmitResult.response] is its answer.
  sent,

  /// The server never answered, and it is now waiting on the device. It WILL
  /// be uploaded, exactly once, without anybody pressing anything.
  queued,

  /// The server never answered and it could not be kept either. Nothing was
  /// recorded and the person has to be told so.
  lost,

  /// The server answered and refused. [OfflineSubmitResult.response] carries
  /// its words, which are better than anything invented here.
  rejected,
}

class OfflineSubmitResult<T> {
  final OfflineSubmitOutcome outcome;
  final ApiResponse<T>? response;

  /// What to show a person. Always populated, always in English, never a raw
  /// SocketException.
  final String message;

  /// How many creates are waiting on this device, counted after this one was
  /// queued. Zero for every other outcome.
  final int pendingCount;

  const OfflineSubmitResult({
    required this.outcome,
    required this.message,
    this.response,
    this.pendingCount = 0,
  });

  bool get isSent => outcome == OfflineSubmitOutcome.sent;
  bool get isQueued => outcome == OfflineSubmitOutcome.queued;

  /// True when the person can be told their work is safe -- either the server
  /// has it or the device does. The two are different facts and screens that
  /// print a document number must still branch on [isSent]; but for closing a
  /// form and clearing its fields they are the same.
  bool get isKept => isSent || isQueued;

  T? get data => response?.data;
}

/// Submits a CREATE, and keeps it if the server cannot be reached.
///
/// One instance per form, held as a field on the State so it survives rebuilds.
/// It exists to hold the idempotency key ACROSS attempts, which is the part
/// that cannot be done with a local variable:
///
///   * the key is derived from the payload, so tapping Save again after a
///     timeout reuses it and the server replays its original answer instead of
///     writing a second record;
///   * an EDITED form produces a different payload and therefore a new key, so
///     a genuinely different record is never suppressed as a replay;
///   * once an attempt is either accepted or queued the key is released, so the
///     next deliberate, identical entry -- two 5,000/= fuel expenses on the
///     same day really do happen -- is not swallowed as a duplicate of the
///     first.
class OfflineSubmitter {
  String? _requestId;
  String? _payloadKey;

  /// The key the next attempt at [payload] will use.
  ///
  /// Visible for the screens that have to pass the id into a typed API method
  /// themselves, and for tests.
  String idFor(Map<String, dynamic> payload) {
    final key = jsonEncode(payload);
    if (_payloadKey == key && _requestId != null) return _requestId!;
    _payloadKey = key;
    _requestId = const Uuid().v4();
    return _requestId!;
  }

  /// Forget the current key. Called after an attempt is settled -- accepted by
  /// the server, or handed to the queue, which now owns the key.
  void release() {
    _requestId = null;
    _payloadKey = null;
  }

  /// Try [send], and queue [payload] if the server never answered.
  ///
  /// [send] is given the key and must post it. Keeping the send in the caller's
  /// hands means the live path stays the screen's own typed API call rather
  /// than a second, parallel way of making the same request.
  ///
  /// [summary] is one short line naming this particular record -- "Fuel,
  /// 12,000/=" -- shown in the sync sheet so a person can tell their three
  /// queued expenses apart.
  Future<OfflineSubmitResult<T>> submit<T>({
    required BuildContext context,
    required OfflineAction action,
    required Map<String, dynamic> payload,
    required Future<ApiResponse<T>> Function(String requestId) send,
    String? summary,
  }) async {
    final offlineProvider = context.read<OfflineProvider>();
    final requestId = idFor(payload);

    final response = await send(requestId);

    if (response.isSuccess) {
      // Consumed. The next entry is a new record and mints its own key.
      release();
      return OfflineSubmitResult<T>(
        outcome: OfflineSubmitOutcome.sent,
        response: response,
        message: response.message,
      );
    }

    if (response.statusCode != null) {
      // The server answered and refused. Queueing would only replay the
      // refusal, so the person sees it now while the form is still on screen
      // and can do something about it. The key is deliberately KEPT: if they
      // fix nothing and simply tap again, the same payload must not become two
      // records should the retry time out.
      return OfflineSubmitResult<T>(
        outcome: OfflineSubmitOutcome.rejected,
        response: response,
        message: response.message,
      );
    }

    // No status code means we never got a reply -- no network, no route, or a
    // timeout. Note that this attempt may in fact have reached the server and
    // been written; we simply never heard back. Queueing it under THIS
    // attempt's key is what makes the upload replay that record instead of
    // creating a second one.
    if (!offlineProvider.isInitialized || !OfflineFeature.enabled) {
      // No local database for this client, or offline mode switched off on the
      // server: either way there is nowhere this may be kept, and saying so
      // plainly beats pretending.
      return OfflineSubmitResult<T>(
        outcome: OfflineSubmitOutcome.lost,
        response: response,
        message: OfflineFeature.refusal(action.label.toLowerCase()),
      );
    }

    final queued = await offlineProvider.queueAction(
      action: action,
      payload: payload,
      requestId: requestId,
      summary: summary,
    );

    if (!queued) {
      return OfflineSubmitResult<T>(
        outcome: OfflineSubmitOutcome.lost,
        response: response,
        message: 'This ${action.label.toLowerCase()} could not be saved on the '
            'device and was NOT recorded. Please try again.',
      );
    }

    // The key now belongs to the queued row. Releasing it here means the next
    // entry mints its own -- without this, a deliberate second identical
    // record would reuse the key and be swallowed as a replay of the one just
    // queued.
    release();

    final pending = offlineProvider.pendingActionCount;
    return OfflineSubmitResult<T>(
      outcome: OfflineSubmitOutcome.queued,
      response: response,
      pendingCount: pending,
      message: 'Saved on this device - no connection. It will upload by itself '
          'when the network returns. '
          '${pending == 1 ? '1 item is' : '$pending items are'} waiting.',
    );
  }
}
