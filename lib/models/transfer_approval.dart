// Models for the stock-transfer approval workflow.
//
// Backend: application/controllers/api/Transfer_approvals.php, engine in
// application/libraries/Transfer_change_lib.php. A staged request is created
// whenever a tenant has "Require approval for stock transfers" turned on
// (Appconfig transfer_approval_enabled) and someone submits a transfer;
// see ApiResponse.isPending for how the staging response is detected.

/// The staged move itself: one item/quantity moving from a source to a
/// destination. Sent on both list and detail responses.
///
/// `source == 'api'` (a mobile-submitted transfer) and `source == 'web'`
/// carry genuinely different shapes: the web request already knows both
/// item ids and quantities on both sides, while a mobile request only picks
/// a parent item + CTN count and lets the server resolve the destination
/// child at approval time -- so `toItem`/`toQty` are frequently unknown
/// until then. Render defensively rather than assuming either side is full.
class TransferDiff {
  final int fromItemId;
  final String fromItem;
  final dynamic fromQty;
  final dynamic fromBefore;

  final int? toItemId;
  final String? toItem;
  final dynamic toQty;
  final dynamic toBefore;

  /// Present only for `source == 'api'` -- explains why the destination
  /// side is incomplete.
  final String? note;

  TransferDiff({
    required this.fromItemId,
    required this.fromItem,
    this.fromQty,
    this.fromBefore,
    this.toItemId,
    this.toItem,
    this.toQty,
    this.toBefore,
    this.note,
  });

  factory TransferDiff.fromJson(Map<String, dynamic> json) {
    return TransferDiff(
      fromItemId: _toInt(json['from_item_id']),
      fromItem: json['from_item']?.toString() ?? '',
      fromQty: json['from_qty'],
      fromBefore: json['from_before'],
      toItemId: json['to_item_id'] == null ? null : _toInt(json['to_item_id']),
      toItem: json['to_item']?.toString(),
      toQty: json['to_qty'],
      toBefore: json['to_before'],
      note: json['note']?.toString(),
    );
  }

  static String label(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    return value.toString();
  }
}

class TransferApproval {
  final int requestId;

  /// 'web' | 'api' -- which controller staged this, so the review UI knows
  /// which of the two payload shapes to expect on detail.
  final String source;

  final String status;
  final int requestedBy;
  final String? requesterName;
  final String? createdAt;
  final int? approvedBy;
  final String? approverName;
  final String? approvedAt;
  final String? reason;

  final TransferDiff? transfer;

  TransferApproval({
    required this.requestId,
    required this.source,
    required this.status,
    required this.requestedBy,
    this.requesterName,
    this.createdAt,
    this.approvedBy,
    this.approverName,
    this.approvedAt,
    this.reason,
    this.transfer,
  });

  factory TransferApproval.fromJson(Map<String, dynamic> json) {
    return TransferApproval(
      requestId: _toInt(json['request_id']),
      source: json['source']?.toString() ?? 'web',
      status: json['status']?.toString() ?? 'pending',
      requestedBy: _toInt(json['requested_by']),
      requesterName: (json['requester_name']?.toString().trim().isEmpty ?? true)
          ? null
          : json['requester_name'].toString().trim(),
      createdAt: json['created_at']?.toString(),
      approvedBy:
          json['approved_by'] == null ? null : _toInt(json['approved_by']),
      approverName: (json['approver_name']?.toString().trim().isEmpty ?? true)
          ? null
          : json['approver_name'].toString().trim(),
      approvedAt: json['approved_at']?.toString(),
      reason: json['reason']?.toString(),
      transfer: json['transfer'] is Map<String, dynamic>
          ? TransferDiff.fromJson(json['transfer'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isFromApp => source == 'api';

  String get sourceLabel => isFromApp ? 'App transfer' : 'Web transfer';

  /// "From item → To item", for the list card and detail header. The API
  /// sends `transfer` on every request now, list included, precisely so a
  /// reviewer can see what's being moved without opening each row -- falls
  /// back defensively rather than assuming that forever.
  String get displayTitle {
    final t = transfer;
    if (t == null) return 'Stock transfer request';
    return '${t.fromItem} → ${t.toItem ?? 'Unknown'}';
  }

  /// "1 CTN → 30 PC", or just "1 CTN" when the destination quantity isn't
  /// resolved (see TransferDiff's doc on api-sourced requests).
  String get qtySummary {
    final t = transfer;
    if (t == null) return '';
    final from = TransferDiff.label(t.fromQty);
    final to = TransferDiff.label(t.toQty);
    return to == '—' ? from : '$from → $to';
  }
}

class TransferApprovalListResponse {
  final List<TransferApproval> requests;
  final int total;

  TransferApprovalListResponse({required this.requests, required this.total});

  factory TransferApprovalListResponse.fromJson(Map<String, dynamic> json) {
    return TransferApprovalListResponse(
      requests: (json['requests'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(TransferApproval.fromJson)
              .toList() ??
          [],
      total: _toInt(json['total']),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
