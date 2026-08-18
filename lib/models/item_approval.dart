// Models for the item add/edit/inventory approval workflow.
//
// Backend: application/controllers/api/Item_approvals.php, engine in
// application/libraries/Item_change_lib.php. A staged change is created
// whenever an employee without the `items_approve` grant saves an item;
// see ApiResponse.isPending for how the staging response is detected.

/// One before/after row of a staged change.
///
/// The server sends `before`/`after` untyped — they may be strings, numbers,
/// booleans or null depending on the column — so they are kept as dynamic and
/// rendered as text. `changed` is computed server-side with type-aware
/// comparison (see Item_change_lib::build_field_diffs), which is why we trust
/// it rather than re-comparing here: "55000.00" and 55000 are equal there and
/// would not be with a naive client-side compare.
class ApprovalDiff {
  final String field;
  final dynamic before;
  final dynamic after;
  final bool changed;

  ApprovalDiff({
    required this.field,
    this.before,
    this.after,
    required this.changed,
  });

  factory ApprovalDiff.fromJson(Map<String, dynamic> json) {
    return ApprovalDiff(
      field: json['field']?.toString() ?? '',
      before: json['before'],
      after: json['after'],
      changed: json['changed'] == true,
    );
  }

  String get beforeLabel => _label(before);
  String get afterLabel => _label(after);

  static String _label(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }
}

/// The inventory-change variant: a single stock adjustment at one location.
class InventoryDiff {
  final String location;
  final String? transComment;
  final double delta;
  final double? beforeQty;
  final double? afterQty;

  InventoryDiff({
    required this.location,
    this.transComment,
    required this.delta,
    this.beforeQty,
    this.afterQty,
  });

  factory InventoryDiff.fromJson(Map<String, dynamic> json) {
    return InventoryDiff(
      location: json['location']?.toString() ?? '',
      transComment: json['trans_comment']?.toString(),
      delta: _toDouble(json['delta']),
      beforeQty: json['before_qty'] == null ? null : _toDouble(json['before_qty']),
      afterQty: json['after_qty'] == null ? null : _toDouble(json['after_qty']),
    );
  }
}

class ItemApproval {
  final int requestId;

  /// 'add' | 'edit' | 'inventory' — set by Item_change_lib::stage_item_change.
  /// Note 'add', not 'item': an added item has no row to join against yet.
  final String changeType;

  /// NULL for an 'add' — the item does not exist yet, so there is nothing to
  /// point at. Its name lives in the field diffs, available only on detail.
  final int? itemId;
  final String? itemName;

  final String status;
  final int requestedBy;
  final String? requesterName;
  final String? createdAt;

  /// Detail-only. Empty on list responses.
  final List<ApprovalDiff> fieldDiffs;
  final List<ApprovalDiff> quantityDiffs;
  final InventoryDiff? inventoryDiff;

  ItemApproval({
    required this.requestId,
    required this.changeType,
    this.itemId,
    this.itemName,
    required this.status,
    required this.requestedBy,
    this.requesterName,
    this.createdAt,
    this.fieldDiffs = const [],
    this.quantityDiffs = const [],
    this.inventoryDiff,
  });

  factory ItemApproval.fromJson(Map<String, dynamic> json) {
    return ItemApproval(
      requestId: _toInt(json['request_id']),
      changeType: json['change_type']?.toString() ?? '',
      itemId: json['item_id'] == null ? null : _toInt(json['item_id']),
      itemName: json['item_name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      requestedBy: _toInt(json['requested_by']),
      requesterName: (json['requester_name']?.toString().trim().isEmpty ?? true)
          ? null
          : json['requester_name'].toString().trim(),
      createdAt: json['created_at']?.toString(),
      fieldDiffs: _diffList(json['field_diffs']),
      quantityDiffs: _diffList(json['quantity_diffs']),
      inventoryDiff: json['diff'] is Map<String, dynamic>
          ? InventoryDiff.fromJson(json['diff'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isAdd => changeType == 'add';
  bool get isEdit => changeType == 'edit';
  bool get isInventory => changeType == 'inventory';
  bool get isPending => status == 'pending';

  /// What to show as the heading. An 'add' has no item row yet, so the name
  /// only becomes available on the detail response via the field diffs —
  /// the list genuinely cannot name it.
  String get displayName {
    if (itemName != null && itemName!.isNotEmpty) return itemName!;
    final named = fieldDiffs.where((d) => d.field == 'name');
    if (named.isNotEmpty) {
      final name = named.first.after?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return isAdd ? 'New item' : 'Item #${itemId ?? requestId}';
  }

  String get changeTypeLabel {
    switch (changeType) {
      case 'add':
        return 'New item';
      case 'edit':
        return 'Item edit';
      case 'inventory':
        return 'Stock adjustment';
      default:
        return changeType;
    }
  }

  /// Only the rows an approver needs to look at.
  List<ApprovalDiff> get changedFields =>
      fieldDiffs.where((d) => d.changed).toList();
  List<ApprovalDiff> get unchangedFields =>
      fieldDiffs.where((d) => !d.changed).toList();
  List<ApprovalDiff> get changedQuantities =>
      quantityDiffs.where((d) => d.changed).toList();

  static List<ApprovalDiff> _diffList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ApprovalDiff.fromJson)
        .toList();
  }
}

class ItemApprovalListResponse {
  final List<ItemApproval> requests;
  final int total;

  ItemApprovalListResponse({required this.requests, required this.total});

  factory ItemApprovalListResponse.fromJson(Map<String, dynamic> json) {
    return ItemApprovalListResponse(
      requests: (json['requests'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ItemApproval.fromJson)
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

double _toDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
