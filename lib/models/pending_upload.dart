import '../services/database_service.dart';

/// Where one unsent record stands, in the only three terms that change what a
/// person should do about it.
///
/// The app already knew the difference internally -- `sync_service.dart`
/// classifies every failure into unreachable / in-flight / retryable /
/// rejected -- but it showed only two things on screen: a pending count and a
/// failed count, with "failed" quietly covering both "the server was busy" and
/// "the server refused this and never will not". Those two need opposite
/// responses, so they are separated here and never drawn the same way.
enum UploadState {
  /// Nothing has been attempted, or the attempts never reached the server at
  /// all. Nothing is wrong and there is nothing for anybody to do; it goes up
  /// on its own when there is a network.
  waiting,

  /// The server answered, and the answer was one that may pass later -- it was
  /// busy, the token had expired, it hit a 500. It will be attempted again.
  /// Worth watching, not worth acting on.
  trying,

  /// The server looked at this record and refused it. Every retry replays the
  /// same refusal, so it will NEVER go up on its own.
  ///
  /// This is the state that loses data. It is the reason this screen exists.
  rejected,
}

/// One thing sitting on the phone that the server has not got.
///
/// Sales and everything-else live in two different tables with two different
/// shapes, but the question being asked of them is identical -- what is it,
/// when was it made, how much, and is it stuck? -- so they are read into one
/// type here and the screen renders one list.
class PendingUpload {
  /// Which table this came from, in the words the sync queue files it under:
  /// [DatabaseService.saleEntity] or [DatabaseService.pendingActionEntity].
  /// Carried so a retry or a discard can find the row again.
  final String entityType;

  /// The row's local id. Local, not the server's -- an unsent record has no
  /// server id by definition.
  final int localId;

  /// What kind of thing this is, in a person's words: "Sale", "Expense",
  /// "Bank deposit".
  final String kind;

  /// A short identifying description -- the expense's note, the customer's
  /// name. Null when the record never carried one.
  final String? detail;

  /// The money on it, when the record has an amount at all. A customer record
  /// does not.
  final double? amount;

  /// When the person made it. Not when it was last attempted.
  final DateTime? createdAt;

  final UploadState state;

  /// How many times the server has answered and refused to take it. Zero for
  /// anything that has never got a reply, which is why a phone that spent the
  /// week out of coverage does not look like a phone with a problem.
  final int attempts;

  /// The last thing the server said, in the server's own words. This is what a
  /// rejected record is really carrying -- without it, "refused" is a dead end
  /// for whoever has to fix it.
  final String? reason;

  /// Whether a person has confirmed they have SEEN this refusal. Only
  /// meaningful when [state] is [UploadState.rejected].
  final bool acknowledged;

  /// The idempotency key. Shown on the detail sheet, because when a record is
  /// refused for a reason that looks like a duplicate, this is the one string
  /// that lets somebody check what actually happened server-side.
  final String? requestId;

  const PendingUpload({
    required this.entityType,
    required this.localId,
    required this.kind,
    required this.state,
    this.detail,
    this.amount,
    this.createdAt,
    this.attempts = 0,
    this.reason,
    this.acknowledged = false,
    this.requestId,
  });

  bool get isSale => entityType == DatabaseService.saleEntity;

  /// A refusal nobody has read yet. What the alert counts.
  bool get isUnreadRejection =>
      state == UploadState.rejected && !acknowledged;

  /// Decide the state of one row from `sales` or `pending_actions` joined to
  /// its queue row.
  ///
  /// The discriminator between waiting and trying is `retry_count`, and that
  /// is not an arbitrary choice: `recordSyncQueueAttempt` deliberately does
  /// NOT increment it when the server never answered, precisely so a week out
  /// of coverage cannot burn a good record's retries. So a non-zero count is
  /// exactly "the server has answered about this and would not take it", which
  /// is what "trying" means to a person.
  static UploadState stateOf({
    required int? syncStatus,
    required int? retryCount,
  }) {
    if (syncStatus == DatabaseService.syncStatusFailed) {
      return UploadState.rejected;
    }
    return (retryCount ?? 0) > 0 ? UploadState.trying : UploadState.waiting;
  }

  /// One row from [DatabaseService.getUnsyncedSales].
  factory PendingUpload.fromSaleRow(Map<String, dynamic> row) {
    return PendingUpload(
      entityType: DatabaseService.saleEntity,
      localId: row['id'] as int,
      kind: 'Sale',
      amount: (row['total'] as num?)?.toDouble(),
      createdAt: _parseTime(row['sale_time'] ?? row['created_at']),
      state: stateOf(
        syncStatus: row['sync_status'] as int?,
        retryCount: row['retry_count'] as int?,
      ),
      attempts: (row['retry_count'] as int?) ?? 0,
      reason: _firstNonEmpty([
        row['sync_error'] as String?,
        row['error_message'] as String?,
      ]),
      acknowledged: (row['rejection_ack_at'] as String?)?.isNotEmpty ?? false,
      requestId: row['request_id'] as String?,
    );
  }

  /// One row from [DatabaseService.getUnsyncedActions].
  factory PendingUpload.fromActionRow(Map<String, dynamic> row) {
    return PendingUpload(
      entityType: DatabaseService.pendingActionEntity,
      localId: row['id'] as int,
      // The label was written when the record was queued, by the screen that
      // created it. Falling back to the raw action type rather than to
      // "Record" keeps a row from an older build identifiable.
      kind: _firstNonEmpty([
            row['label'] as String?,
            row['action_type'] as String?,
          ]) ??
          'Record',
      detail: _firstNonEmpty([row['summary'] as String?]),
      createdAt: _parseTime(row['created_at']),
      state: stateOf(
        syncStatus: row['sync_status'] as int?,
        retryCount: row['retry_count'] as int?,
      ),
      attempts: (row['retry_count'] as int?) ?? 0,
      reason: _firstNonEmpty([
        row['sync_error'] as String?,
        row['error_message'] as String?,
      ]),
      acknowledged: (row['rejection_ack_at'] as String?)?.isNotEmpty ?? false,
      requestId: row['request_id'] as String?,
    );
  }

  /// Both queues as one list, newest first.
  ///
  /// Interleaved rather than shown as two sections: a person asking "what has
  /// not gone up?" is asking about their afternoon, not about which table the
  /// app chose. The kind is on every row, so a receipt is still tellable from
  /// an expense at a glance.
  static List<PendingUpload> merge({
    required List<Map<String, dynamic>> sales,
    required List<Map<String, dynamic>> actions,
  }) {
    final all = <PendingUpload>[
      for (final row in sales) PendingUpload.fromSaleRow(row),
      for (final row in actions) PendingUpload.fromActionRow(row),
    ];

    all.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      // A row with no usable timestamp sorts last rather than being dropped or
      // crashing the sort -- it is still something that has not gone up.
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return all;
  }

  static DateTime? _parseTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}

/// Counts for the three states, so a header can be written without walking the
/// list three times.
class PendingUploadTally {
  final int waiting;
  final int trying;
  final int rejected;
  final int unreadRejections;

  const PendingUploadTally({
    this.waiting = 0,
    this.trying = 0,
    this.rejected = 0,
    this.unreadRejections = 0,
  });

  factory PendingUploadTally.of(List<PendingUpload> items) {
    var waiting = 0;
    var trying = 0;
    var rejected = 0;
    var unread = 0;
    for (final item in items) {
      switch (item.state) {
        case UploadState.waiting:
          waiting++;
        case UploadState.trying:
          trying++;
        case UploadState.rejected:
          rejected++;
          if (!item.acknowledged) unread++;
      }
    }
    return PendingUploadTally(
      waiting: waiting,
      trying: trying,
      rejected: rejected,
      unreadRejections: unread,
    );
  }

  int get total => waiting + trying + rejected;
  bool get isEmpty => total == 0;
}
