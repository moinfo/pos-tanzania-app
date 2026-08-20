/// Models for the request-and-approval workflows: one-time discounts and
/// customer credit limits.
///
/// The API hands numbers back as strings (the MySQL driver stringifies
/// DECIMAL and INT alike), so every field goes through the parse helpers
/// rather than a bare cast.
library;

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double _asDouble(dynamic v, [double fallback = 0.0]) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? fallback;
}

String? _asString(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// What kind of thing is being approved.
enum ApprovalKind { discount, creditLimit, unknown }

ApprovalKind approvalKindFrom(String? modelType) {
  switch (modelType) {
    case 'One_time_discount':
      return ApprovalKind.discount;
    case 'Customer_credit_limit':
      return ApprovalKind.creditLimit;
    default:
      return ApprovalKind.unknown;
  }
}

/// One row in the approval queue, or one of my own submitted requests.
///
/// [detail] carries the underlying record (the discount or the credit limit)
/// already joined server-side, so a list never needs a second round trip.
class Approval {
  final int approvalId;
  final String modelType;
  final int modelId;

  /// draft | submitted | in_progress | completed | rejected | returned | discarded
  ///
  /// Note the terminal success value is `completed`, not `approved` — the
  /// enum has an `approved` member the engine never writes.
  final String status;

  final String? flowName;
  final int? currentStepId;
  final int? submittedBy;
  final String? submittedAt;
  final String? completedAt;
  final ApprovalDetail? detail;

  Approval({
    required this.approvalId,
    required this.modelType,
    required this.modelId,
    required this.status,
    this.flowName,
    this.currentStepId,
    this.submittedBy,
    this.submittedAt,
    this.completedAt,
    this.detail,
  });

  ApprovalKind get kind => approvalKindFrom(modelType);

  bool get isOpen => status == 'submitted' || status == 'in_progress';
  bool get isApproved => status == 'completed';
  bool get isRejected => status == 'rejected';

  factory Approval.fromJson(Map<String, dynamic> json) {
    final rawDetail = json['detail'];
    return Approval(
      approvalId: _asInt(json['approval_id']),
      modelType: json['model_type']?.toString() ?? '',
      modelId: _asInt(json['model_id']),
      status: json['status']?.toString() ?? '',
      flowName: _asString(json['flow_name']),
      currentStepId: _asIntOrNull(json['current_step_id']),
      submittedBy: _asIntOrNull(json['submitted_by']),
      submittedAt: _asString(json['submitted_at']),
      completedAt: _asString(json['completed_at']),
      detail: rawDetail is Map<String, dynamic>
          ? ApprovalDetail.fromJson(rawDetail, json['model_type']?.toString())
          : null,
    );
  }
}

/// The business record behind an approval, flattened across both kinds so one
/// list widget can render either.
class ApprovalDetail {
  final ApprovalKind kind;
  final String? documentNumber;
  final int customerId;
  final String? customerName;
  final String? reason;
  final String? recordStatus;

  // Discount-only
  final String? itemName;
  final String? locationName;
  final int? stockLocationId;
  final double? quantity;
  final double? discountAmount;
  final String? validDate;

  // Credit-limit-only
  final double? creditAmount;
  final double? previousAmount;
  final double? currentBalance;
  final String? effectiveDate;
  final String? expiryDate;

  ApprovalDetail({
    required this.kind,
    required this.customerId,
    this.documentNumber,
    this.customerName,
    this.reason,
    this.recordStatus,
    this.itemName,
    this.locationName,
    this.stockLocationId,
    this.quantity,
    this.discountAmount,
    this.validDate,
    this.creditAmount,
    this.previousAmount,
    this.currentBalance,
    this.effectiveDate,
    this.expiryDate,
  });

  /// The single number that matters for this record, for the list row.
  double get headlineAmount =>
      kind == ApprovalKind.discount ? (discountAmount ?? 0) : (creditAmount ?? 0);

  factory ApprovalDetail.fromJson(Map<String, dynamic> json, String? modelType) {
    return ApprovalDetail(
      kind: approvalKindFrom(modelType),
      documentNumber: _asString(json['document_number']),
      customerId: _asInt(json['customer_id']),
      customerName: _asString(json['customer_name']),
      reason: _asString(json['reason']),
      recordStatus: _asString(json['record_status']),
      itemName: _asString(json['item_name']),
      locationName: _asString(json['location_name']),
      stockLocationId: _asIntOrNull(json['stock_location_id']),
      quantity: json['quantity'] == null ? null : _asDouble(json['quantity']),
      discountAmount:
          json['discount_amount'] == null ? null : _asDouble(json['discount_amount']),
      validDate: _asString(json['valid_date']),
      creditAmount:
          json['credit_amount'] == null ? null : _asDouble(json['credit_amount']),
      previousAmount:
          json['previous_amount'] == null ? null : _asDouble(json['previous_amount']),
      currentBalance:
          json['current_balance'] == null ? null : _asDouble(json['current_balance']),
      effectiveDate: _asString(json['effective_date']),
      expiryDate: _asString(json['expiry_date']),
    );
  }
}

/// One action taken on an approval — who did what, when, and why.
class ApprovalHistoryEntry {
  final String action; // submitted | approved | rejected | returned | discarded
  final String? comment;
  final String? actorName;
  final String? roleName;
  final int? stepOrder;
  final String? createdAt;

  ApprovalHistoryEntry({
    required this.action,
    this.comment,
    this.actorName,
    this.roleName,
    this.stepOrder,
    this.createdAt,
  });

  factory ApprovalHistoryEntry.fromJson(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    final name = '$first $last'.trim();

    return ApprovalHistoryEntry(
      action: json['action']?.toString() ?? '',
      comment: _asString(json['comment']) ?? _asString(json['comments']),
      actorName: name.isEmpty ? null : name,
      roleName: _asString(json['role_name']),
      stepOrder: _asIntOrNull(json['step_order']),
      createdAt: _asString(json['created_at']),
    );
  }
}

/// An approval plus its trail and what I am allowed to do with it.
class ApprovalWithHistory {
  final Approval approval;
  final List<ApprovalHistoryEntry> history;
  final bool canApprove;
  final bool canReject;

  ApprovalWithHistory({
    required this.approval,
    required this.history,
    required this.canApprove,
    required this.canReject,
  });

  factory ApprovalWithHistory.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    return ApprovalWithHistory(
      approval: Approval.fromJson(json['approval'] as Map<String, dynamic>),
      history: rawHistory is List
          ? rawHistory
              .whereType<Map<String, dynamic>>()
              .map(ApprovalHistoryEntry.fromJson)
              .toList()
          : const [],
      canApprove: json['can_approve'] == true,
      canReject: json['can_reject'] == true,
    );
  }
}

/// A discount request I raised, as returned by my_requests.
class MyDiscountRequest {
  final int discountId;
  final String documentNumber;
  final String? customerName;
  final String? itemName;
  final String? locationName;
  final double quantity;
  final double discountAmount;
  final String? reason;
  final String validDate;

  /// pending | active | used | rejected
  final String status;
  final String? approvalStatus;
  final String? createdAt;
  final String? approvedAt;
  final int? saleId;

  MyDiscountRequest({
    required this.discountId,
    required this.documentNumber,
    required this.quantity,
    required this.discountAmount,
    required this.validDate,
    required this.status,
    this.customerName,
    this.itemName,
    this.locationName,
    this.reason,
    this.approvalStatus,
    this.createdAt,
    this.approvedAt,
    this.saleId,
  });

  factory MyDiscountRequest.fromJson(Map<String, dynamic> json) {
    return MyDiscountRequest(
      discountId: _asInt(json['discount_id']),
      documentNumber: json['document_number']?.toString() ?? '',
      customerName: _asString(json['customer_name']),
      itemName: _asString(json['item_name']),
      locationName: _asString(json['location_name']),
      quantity: _asDouble(json['quantity']),
      discountAmount: _asDouble(json['discount_amount']),
      reason: _asString(json['reason']),
      validDate: json['valid_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      approvalStatus: _asString(json['approval_status']),
      createdAt: _asString(json['created_at']),
      approvedAt: _asString(json['approved_at']),
      saleId: _asIntOrNull(json['sale_id']),
    );
  }
}

/// A credit-limit request I raised.
class MyCreditLimitRequest {
  final int creditLimitId;
  final String documentNumber;
  final String? customerName;
  final double creditAmount;
  final double? previousAmount;
  final double? currentBalance;
  final String? reason;
  final String status;
  final String? approvalStatus;
  final String? createdAt;
  final String? approvedAt;

  MyCreditLimitRequest({
    required this.creditLimitId,
    required this.documentNumber,
    required this.creditAmount,
    required this.status,
    this.customerName,
    this.previousAmount,
    this.currentBalance,
    this.reason,
    this.approvalStatus,
    this.createdAt,
    this.approvedAt,
  });

  factory MyCreditLimitRequest.fromJson(Map<String, dynamic> json) {
    return MyCreditLimitRequest(
      creditLimitId: _asInt(json['credit_limit_id']),
      documentNumber: json['document_number']?.toString() ?? '',
      customerName: _asString(json['customer_name']),
      creditAmount: _asDouble(json['credit_amount']),
      previousAmount:
          json['previous_amount'] == null ? null : _asDouble(json['previous_amount']),
      currentBalance:
          json['current_balance'] == null ? null : _asDouble(json['current_balance']),
      reason: _asString(json['reason']),
      status: json['status']?.toString() ?? '',
      approvalStatus: _asString(json['approval_status']),
      createdAt: _asString(json['created_at']),
      approvedAt: _asString(json['approved_at']),
    );
  }
}

/// A customer's live credit position — what the seller needs to see before
/// deciding whether to ask for more.
class CustomerCreditPosition {
  final int customerId;
  final String isAllowedCredit;
  final double creditLimit;
  final double currentBalance;
  final double remainingCredit;
  final bool hasOneTimeCredit;
  final double oneTimeLimit;
  final double oneTimeRemaining;
  final MyCreditLimitRequest? pendingRequest;

  CustomerCreditPosition({
    required this.customerId,
    required this.isAllowedCredit,
    required this.creditLimit,
    required this.currentBalance,
    required this.remainingCredit,
    required this.hasOneTimeCredit,
    required this.oneTimeLimit,
    required this.oneTimeRemaining,
    this.pendingRequest,
  });

  bool get creditAllowed => isAllowedCredit.toUpperCase() == 'ACTIVE';
  bool get hasPendingRequest => pendingRequest != null;

  factory CustomerCreditPosition.fromJson(Map<String, dynamic> json) {
    final pending = json['pending_request'];
    return CustomerCreditPosition(
      customerId: _asInt(json['customer_id']),
      isAllowedCredit: json['is_allowed_credit']?.toString() ?? '',
      creditLimit: _asDouble(json['credit_limit']),
      currentBalance: _asDouble(json['current_balance']),
      remainingCredit: _asDouble(json['remaining_credit']),
      hasOneTimeCredit: json['has_one_time_credit'] == true,
      oneTimeLimit: _asDouble(json['one_time_limit']),
      oneTimeRemaining: _asDouble(json['one_time_remaining']),
      pendingRequest: pending is Map<String, dynamic>
          ? MyCreditLimitRequest.fromJson(pending)
          : null,
    );
  }
}

/// Options for the discount request form, already narrowed to what this
/// employee may pick.
class DiscountFormOptions {
  final List<ScopedLocation> locations;
  final List<ScopedCustomer> customers;
  final bool canSetDate;
  final bool canRequest;
  final String today;

  DiscountFormOptions({
    required this.locations,
    required this.customers,
    required this.canSetDate,
    required this.canRequest,
    required this.today,
  });

  factory DiscountFormOptions.fromJson(Map<String, dynamic> json) {
    final locs = json['locations'];
    final custs = json['customers'];
    return DiscountFormOptions(
      locations: locs is List
          ? locs.whereType<Map<String, dynamic>>().map(ScopedLocation.fromJson).toList()
          : const [],
      customers: custs is List
          ? custs.whereType<Map<String, dynamic>>().map(ScopedCustomer.fromJson).toList()
          : const [],
      canSetDate: json['can_set_date'] == true,
      canRequest: json['can_request'] == true,
      today: json['today']?.toString() ?? '',
    );
  }
}

class ScopedLocation {
  final int locationId;
  final String locationName;

  ScopedLocation({required this.locationId, required this.locationName});

  factory ScopedLocation.fromJson(Map<String, dynamic> json) => ScopedLocation(
        locationId: _asInt(json['location_id']),
        locationName: json['location_name']?.toString() ?? '',
      );
}

class ScopedCustomer {
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final int sortOrder;

  ScopedCustomer({
    required this.customerId,
    required this.customerName,
    this.phoneNumber,
    required this.sortOrder,
  });

  factory ScopedCustomer.fromJson(Map<String, dynamic> json) => ScopedCustomer(
        customerId: _asInt(json['customer_id']),
        customerName: (json['customer_name']?.toString() ?? '').trim(),
        phoneNumber: _asString(json['phone_number']),
        sortOrder: _asInt(json['sort_order']),
      );
}

/// An item eligible for a discount request.
class DiscountEligibleItem {
  final int itemId;
  final String name;
  final String? itemNumber;
  final double unitPrice;
  final double costPrice;
  final double discountLimit;

  DiscountEligibleItem({
    required this.itemId,
    required this.name,
    this.itemNumber,
    required this.unitPrice,
    required this.costPrice,
    required this.discountLimit,
  });

  factory DiscountEligibleItem.fromJson(Map<String, dynamic> json) =>
      DiscountEligibleItem(
        itemId: _asInt(json['item_id']),
        name: json['name']?.toString() ?? '',
        itemNumber: _asString(json['item_number']),
        unitPrice: _asDouble(json['unit_price']),
        costPrice: _asDouble(json['cost_price']),
        discountLimit: _asDouble(json['discount_limit']),
      );
}
