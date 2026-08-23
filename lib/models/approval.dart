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

  /// Who raised it. On a manager's queue the location is usually the same on
  /// every row; the seller's name is what tells them apart.
  final String? submittedByName;

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
    this.submittedByName,
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
      submittedByName: _asString(json['submitted_by_name']),
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

  /// What the item sells for, and the most that may be taken off it.
  ///
  /// Here so an approver can judge a request rather than only read it: "200
  /// off" means nothing until you know whether the item is 5,700 or 38,000.
  ///
  /// discountLimit is 0 on all but twelve of the 1,283 items, so 0 means "no
  /// limit has been set", not "no discount allowed". Anything reading it must
  /// treat those differently or it will flag every request on the system.
  final double? unitPrice;
  final double? discountLimit;
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
    this.unitPrice,
    this.discountLimit,
    this.validDate,
    this.creditAmount,
    this.previousAmount,
    this.currentBalance,
    this.effectiveDate,
    this.expiryDate,
  });

  /// The number the decision actually turns on.
  ///
  /// For a discount that is the TOTAL being given away, not the per-unit
  /// figure the record stores: 500 off reads as small until it is multiplied
  /// by a hundred cartons. The requester's own screen has always shown the
  /// total; the approver was seeing the per-unit amount and deciding on it.
  double get headlineAmount => kind == ApprovalKind.discount
      ? (discountAmount ?? 0) * (quantity ?? 1)
      : (creditAmount ?? 0);

  /// The per-unit discount, kept for the detail view where both belong.
  double? get perUnitAmount =>
      kind == ApprovalKind.discount ? discountAmount : null;

  /// What the customer would pay per unit if this were approved.
  double? get priceAfterDiscount => (unitPrice == null || unitPrice! <= 0)
      ? null
      : unitPrice! - (discountAmount ?? 0);

  /// The discount as a share of the price -- the one number an approver can
  /// judge at a glance. 3.5% and 8.8% are different decisions; "200 off" and
  /// "500 off" on their own are not.
  double? get discountPercent => (unitPrice == null || unitPrice! <= 0)
      ? null
      : (discountAmount ?? 0) / unitPrice! * 100;

  /// A limit worth showing. Zero means nobody set one.
  double? get effectiveDiscountLimit =>
      (discountLimit != null && discountLimit! > 0) ? discountLimit : null;

  /// True only when a limit exists AND this request is over it.
  bool get exceedsDiscountLimit {
    final limit = effectiveDiscountLimit;
    return limit != null && (discountAmount ?? 0) > limit;
  }

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
      unitPrice: json['unit_price'] == null ? null : _asDouble(json['unit_price']),
      discountLimit:
          json['discount_limit'] == null ? null : _asDouble(json['discount_limit']),
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

/// A customer this employee may raise a credit request for, with enough of
/// their credit position to choose between them.
class CreditScopedCustomer {
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final int sortOrder;

  /// The standing, recurring limit. Carried but deliberately NOT led with:
  /// this module never writes it, and it is 0 for 3,307 of the 3,677
  /// customers here, so a picker built around it says "0" on nine rows in
  /// ten. Use [currentBalance] and [oneTimeCreditLimit] instead.
  final double creditLimit;

  /// What the customer owes right now — the figure the approver weighs.
  final double currentBalance;

  /// The one-time allowance amount on the customer record.
  final double oneTimeCreditLimit;

  /// True while an allowance is granted and not yet spent. Both halves have
  /// to hold: 57 customers carry the flag with a zero amount, which grants
  /// nothing.
  final bool hasOneTimeCredit;

  final String isAllowedCredit;

  CreditScopedCustomer({
    required this.customerId,
    required this.customerName,
    required this.sortOrder,
    required this.creditLimit,
    required this.currentBalance,
    required this.oneTimeCreditLimit,
    required this.hasOneTimeCredit,
    required this.isAllowedCredit,
    this.phoneNumber,
  });

  bool get creditAllowed => isAllowedCredit.toUpperCase() == 'ACTIVE';

  /// An allowance that is actually worth something.
  bool get holdsAllowance => hasOneTimeCredit && oneTimeCreditLimit > 0;

  factory CreditScopedCustomer.fromJson(Map<String, dynamic> json) =>
      CreditScopedCustomer(
        customerId: _asInt(json['customer_id']),
        customerName: (json['customer_name']?.toString() ?? '').trim(),
        phoneNumber: _asString(json['phone_number']),
        sortOrder: _asInt(json['sort_order']),
        creditLimit: _asDouble(json['credit_limit']),
        currentBalance: _asDouble(json['current_balance']),
        oneTimeCreditLimit: _asDouble(json['one_time_credit_limit']),
        hasOneTimeCredit: _asInt(json['one_time_credit']) == 1,
        isAllowedCredit: json['is_allowed_credit']?.toString() ?? '',
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

/* -------------------------------------------------------------------------
 * Customer credit limits: the module, not just the request form
 * ---------------------------------------------------------------------- */

/// What actually happened to a credit-limit record.
///
/// NOT the `status` column. That column cannot be trusted on this database:
/// until 21 Aug 2026 two triggers stopped the approval from ever writing
/// `active` back, and its enum has no `rejected` member at all — so 1,891 of
/// 1,892 records read "pending" whatever became of them. The server derives
/// this from the approval row instead and sends it as `effective_status`.
enum CreditLimitOutcome {
  /// Granted — the one-time allowance was written to the customer.
  approved,

  /// Sitting in someone's approval queue right now.
  awaiting,

  rejected,

  /// Sent back to the requester for a change.
  returned,

  cancelled,

  /// Raised before the approval workflow existed (nothing before December
  /// 2025 has an approval record). Never reviewed by anyone.
  unreviewed,
}

CreditLimitOutcome creditLimitOutcomeFrom(String? raw) {
  switch (raw) {
    case 'approved':
      return CreditLimitOutcome.approved;
    case 'awaiting':
      return CreditLimitOutcome.awaiting;
    case 'rejected':
      return CreditLimitOutcome.rejected;
    case 'returned':
      return CreditLimitOutcome.returned;
    case 'cancelled':
      return CreditLimitOutcome.cancelled;
    default:
      return CreditLimitOutcome.unreviewed;
  }
}

extension CreditLimitOutcomeLabel on CreditLimitOutcome {
  String get label {
    switch (this) {
      case CreditLimitOutcome.approved:
        return 'GRANTED';
      case CreditLimitOutcome.awaiting:
        return 'WAITING';
      case CreditLimitOutcome.rejected:
        return 'REJECTED';
      case CreditLimitOutcome.returned:
        return 'RETURNED';
      case CreditLimitOutcome.cancelled:
        return 'CANCELLED';
      case CreditLimitOutcome.unreviewed:
        return 'NEVER REVIEWED';
    }
  }

  /// The filter value the server expects, and the one the chips send back.
  String get wire {
    switch (this) {
      case CreditLimitOutcome.approved:
        return 'approved';
      case CreditLimitOutcome.awaiting:
        return 'awaiting';
      case CreditLimitOutcome.rejected:
        return 'rejected';
      case CreditLimitOutcome.returned:
        return 'returned';
      case CreditLimitOutcome.cancelled:
        return 'cancelled';
      case CreditLimitOutcome.unreviewed:
        return 'unreviewed';
    }
  }
}

/// One credit-limit record, as it appears in the list and in a customer's
/// timeline.
class CreditLimitRow {
  final int creditLimitId;
  final String documentNumber;
  final int customerId;
  final String? customerName;
  final String? phoneNumber;
  final double creditAmount;
  final double? previousAmount;
  final double currentBalance;
  final String? effectiveDate;
  final String? expiryDate;
  final String? reason;
  final String? notes;
  final String? createdAt;
  final String? approvedAt;
  final String? createdByName;
  final String? approvedByName;

  /// Who actually took the decision, read from the approval trail. The
  /// record's own `approved_by` is NULL on every historical row — the step
  /// that would have written it is the one the triggers broke.
  final String? decidedByName;
  final String? decidedAt;

  final CreditLimitOutcome outcome;

  /// True when the stored `status` column contradicts the outcome above.
  /// 450 records in this database do; the screen says so rather than showing
  /// a finished request as though it were still pending.
  final bool statusIsStale;

  final String storedStatus;
  final bool isCurrent;
  final int? approvalId;

  CreditLimitRow({
    required this.creditLimitId,
    required this.documentNumber,
    required this.customerId,
    required this.creditAmount,
    required this.currentBalance,
    required this.outcome,
    required this.statusIsStale,
    required this.storedStatus,
    required this.isCurrent,
    this.customerName,
    this.phoneNumber,
    this.previousAmount,
    this.effectiveDate,
    this.expiryDate,
    this.reason,
    this.notes,
    this.createdAt,
    this.approvedAt,
    this.createdByName,
    this.approvedByName,
    this.decidedByName,
    this.decidedAt,
    this.approvalId,
  });

  factory CreditLimitRow.fromJson(Map<String, dynamic> json) => CreditLimitRow(
        creditLimitId: _asInt(json['credit_limit_id']),
        documentNumber: json['document_number']?.toString() ?? '',
        customerId: _asInt(json['customer_id']),
        customerName: _asString(json['customer_name']),
        phoneNumber: _asString(json['phone_number']),
        creditAmount: _asDouble(json['credit_amount']),
        previousAmount: json['previous_amount'] == null
            ? null
            : _asDouble(json['previous_amount']),
        currentBalance: _asDouble(json['current_balance']),
        effectiveDate: _asString(json['effective_date']),
        expiryDate: _asString(json['expiry_date']),
        reason: _asString(json['reason']),
        notes: _asString(json['notes']),
        createdAt: _asString(json['created_at']),
        approvedAt: _asString(json['approved_at']),
        createdByName: _asString(json['created_by_name']),
        approvedByName: _asString(json['approved_by_name']),
        decidedByName: _asString(json['decided_by_name']),
        decidedAt: _asString(json['decided_at']),
        outcome: creditLimitOutcomeFrom(json['effective_status']?.toString()),
        statusIsStale: json['status_is_stale'] == true,
        storedStatus: json['stored_status']?.toString() ?? '',
        isCurrent: _asInt(json['is_current']) == 1,
        approvalId: _asIntOrNull(json['approval_id']),
      );
}

/// The four figures above the list, plus the two that explain them.
class CreditLimitStatistics {
  final int total;
  final int awaiting;
  final int approved;
  final int rejected;
  final int returned;
  final int cancelled;
  final int unreviewed;
  final double totalAmount;
  final double approvedAmount;

  /// How many records store `pending` while the approval trail says the
  /// request was settled long ago.
  final int staleStatusRows;

  const CreditLimitStatistics({
    this.total = 0,
    this.awaiting = 0,
    this.approved = 0,
    this.rejected = 0,
    this.returned = 0,
    this.cancelled = 0,
    this.unreviewed = 0,
    this.totalAmount = 0,
    this.approvedAmount = 0,
    this.staleStatusRows = 0,
  });

  factory CreditLimitStatistics.fromJson(Map<String, dynamic> json) =>
      CreditLimitStatistics(
        total: _asInt(json['total']),
        awaiting: _asInt(json['awaiting']),
        approved: _asInt(json['approved']),
        rejected: _asInt(json['rejected']),
        returned: _asInt(json['returned']),
        cancelled: _asInt(json['cancelled']),
        unreviewed: _asInt(json['unreviewed']),
        totalAmount: _asDouble(json['total_amount']),
        approvedAmount: _asDouble(json['approved_amount']),
        staleStatusRows: _asInt(json['stale_status_rows']),
      );

  int countFor(CreditLimitOutcome outcome) {
    switch (outcome) {
      case CreditLimitOutcome.approved:
        return approved;
      case CreditLimitOutcome.awaiting:
        return awaiting;
      case CreditLimitOutcome.rejected:
        return rejected;
      case CreditLimitOutcome.returned:
        return returned;
      case CreditLimitOutcome.cancelled:
        return cancelled;
      case CreditLimitOutcome.unreviewed:
        return unreviewed;
    }
  }
}

/// One page of the list, with the filters the server actually applied.
///
/// The dates come back from the server rather than being assumed, because
/// without `customer_credit_limits_filter_date` the range is forced to today
/// however the request was made — the screen has to show the range it got,
/// not the one it asked for.
class CreditLimitPage {
  final List<CreditLimitRow> rows;
  final int total;
  final int limit;
  final int offset;
  final String? dateFrom;
  final String? dateTo;
  final bool canFilterDate;
  final String status;
  final String search;

  /// The stock locations this data is filtered to — the web shows the same
  /// list in a banner above the table.
  final List<String> locations;

  CreditLimitPage({
    required this.rows,
    required this.total,
    required this.limit,
    required this.offset,
    required this.canFilterDate,
    required this.locations,
    this.dateFrom,
    this.dateTo,
    this.status = '',
    this.search = '',
  });

  factory CreditLimitPage.fromJson(Map<String, dynamic> json) {
    final list = json['requests'];
    return CreditLimitPage(
      rows: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CreditLimitRow.fromJson)
              .toList()
          : <CreditLimitRow>[],
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], 50),
      offset: _asInt(json['offset']),
      dateFrom: _asString(json['date_from']),
      dateTo: _asString(json['date_to']),
      canFilterDate: json['can_filter_date'] == true,
      status: json['status']?.toString() ?? '',
      search: json['search']?.toString() ?? '',
      locations: json['locations'] is List
          ? (json['locations'] as List).map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

/// The customer a history screen is about.
class CreditHistoryCustomer {
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final String? supervisorName;
  final String dormant;
  final String isAllowedCredit;
  final int sortOrder;

  /// Carried for completeness only. This module never writes it, and it is 0
  /// for 3,307 of the 3,677 customers on this system.
  final double creditLimit;

  final double currentBalance;

  /// The figures this module actually moves.
  final bool hasOneTimeCredit;
  final double oneTimeLimit;

  CreditHistoryCustomer({
    required this.customerId,
    required this.customerName,
    required this.dormant,
    required this.isAllowedCredit,
    required this.sortOrder,
    required this.creditLimit,
    required this.currentBalance,
    required this.hasOneTimeCredit,
    required this.oneTimeLimit,
    this.phoneNumber,
    this.supervisorName,
  });

  bool get creditAllowed => isAllowedCredit.toUpperCase() == 'ACTIVE';

  factory CreditHistoryCustomer.fromJson(Map<String, dynamic> json) =>
      CreditHistoryCustomer(
        customerId: _asInt(json['customer_id']),
        customerName: (json['customer_name']?.toString() ?? '').trim(),
        phoneNumber: _asString(json['phone_number']),
        supervisorName: _asString(json['supervisor_name']),
        dormant: json['dormant']?.toString() ?? '',
        isAllowedCredit: json['is_allowed_credit']?.toString() ?? '',
        sortOrder: _asInt(json['sort_order']),
        creditLimit: _asDouble(json['credit_limit']),
        currentBalance: _asDouble(json['current_balance']),
        hasOneTimeCredit: json['has_one_time_credit'] == true,
        oneTimeLimit: _asDouble(json['one_time_limit']),
      );
}

/// The record currently marked as the customer's standing one, if any.
class CurrentCreditLimit {
  final int creditLimitId;
  final String documentNumber;
  final double creditAmount;
  final String? effectiveDate;
  final String? expiryDate;
  final String status;
  final String? approvedAt;

  CurrentCreditLimit({
    required this.creditLimitId,
    required this.documentNumber,
    required this.creditAmount,
    required this.status,
    this.effectiveDate,
    this.expiryDate,
    this.approvedAt,
  });

  factory CurrentCreditLimit.fromJson(Map<String, dynamic> json) =>
      CurrentCreditLimit(
        creditLimitId: _asInt(json['credit_limit_id']),
        documentNumber: json['document_number']?.toString() ?? '',
        creditAmount: _asDouble(json['credit_amount']),
        effectiveDate: _asString(json['effective_date']),
        expiryDate: _asString(json['expiry_date']),
        status: json['status']?.toString() ?? '',
        approvedAt: _asString(json['approved_at']),
      );
}

/// Everything the module knows about one customer.
class CustomerCreditHistory {
  final CreditHistoryCustomer customer;
  final CurrentCreditLimit? current;
  final CreditLimitStatistics statistics;
  final List<CreditLimitRow> history;

  /// True when the customer has more records than the timeline carries.
  final bool truncated;

  CustomerCreditHistory({
    required this.customer,
    required this.statistics,
    required this.history,
    required this.truncated,
    this.current,
  });

  factory CustomerCreditHistory.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final list = json['history'];
    return CustomerCreditHistory(
      customer: CreditHistoryCustomer.fromJson(
          (json['customer'] as Map?)?.cast<String, dynamic>() ?? const {}),
      current: current is Map<String, dynamic>
          ? CurrentCreditLimit.fromJson(current)
          : null,
      statistics: CreditLimitStatistics.fromJson(
          (json['statistics'] as Map?)?.cast<String, dynamic>() ?? const {}),
      history: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CreditLimitRow.fromJson)
              .toList()
          : <CreditLimitRow>[],
      truncated: json['history_truncated'] == true,
    );
  }
}

/// A customer still holding a one-time allowance they have not spent.
class UnusedAllowance {
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final double oneTimeLimit;
  final int sortOrder;
  final String? supervisorName;
  final String? lastDocumentNumber;
  final String? lastRequestedAt;

  UnusedAllowance({
    required this.customerId,
    required this.customerName,
    required this.oneTimeLimit,
    required this.sortOrder,
    this.phoneNumber,
    this.supervisorName,
    this.lastDocumentNumber,
    this.lastRequestedAt,
  });

  factory UnusedAllowance.fromJson(Map<String, dynamic> json) =>
      UnusedAllowance(
        customerId: _asInt(json['customer_id']),
        customerName: (json['customer_name']?.toString() ?? '').trim(),
        phoneNumber: _asString(json['phone_number']),
        oneTimeLimit: _asDouble(json['one_time_limit']),
        sortOrder: _asInt(json['sort_order']),
        supervisorName: _asString(json['supervisor_name']),
        lastDocumentNumber: _asString(json['last_document_number']),
        lastRequestedAt: _asString(json['last_requested_at']),
      );
}

/// The unused-allowance list and what it adds up to.
class UnusedAllowanceList {
  final List<UnusedAllowance> customers;
  final double totalAmount;

  UnusedAllowanceList({required this.customers, required this.totalAmount});

  factory UnusedAllowanceList.fromJson(Map<String, dynamic> json) {
    final list = json['customers'];
    return UnusedAllowanceList(
      customers: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(UnusedAllowance.fromJson)
              .toList()
          : <UnusedAllowance>[],
      totalAmount: _asDouble(json['total_amount']),
    );
  }
}

/// The date window one approvable model was granted on an approvals list.
///
/// The two lists mix discounts and credit limits, and the two are governed by
/// different web permissions (`one_time_discounts_date` and
/// `customer_credit_limits_filter_date`). Someone holding one and not the
/// other widens one half of the list and leaves the other on today, so the
/// server reports the outcome per model rather than pretending it is uniform.
class ApprovalDateScope {
  final String modelType;

  /// What to call this model when explaining itself, e.g. "Discount requests".
  final String label;

  final String? dateFrom;
  final String? dateTo;
  final bool canFilterDate;

  const ApprovalDateScope({
    required this.modelType,
    required this.label,
    required this.canFilterDate,
    this.dateFrom,
    this.dateTo,
  });

  factory ApprovalDateScope.fromJson(Map<String, dynamic> json) {
    return ApprovalDateScope(
      modelType: json['model_type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      dateFrom: _asString(json['date_from']),
      dateTo: _asString(json['date_to']),
      canFilterDate: json['can_filter_date'] == true,
    );
  }
}

/// One page of an approvals list, with the range the server actually applied.
///
/// [dateFrom]/[dateTo] are read off the response, never assumed from what was
/// asked for: without the governing grant the server pins the range to today
/// however the request was made.
///
/// [totalAllDates] is the same list with the dates taken off. It is what lets
/// a screen say "nothing today, 26 waiting on other days" instead of showing
/// an empty list with no explanation.
class ApprovalPage {
  final List<Approval> approvals;
  final int total;
  final int totalAllDates;
  final int limit;
  final int offset;
  final String? dateFrom;
  final String? dateTo;
  final bool canFilterDate;
  final bool dateScopeUniform;
  final List<ApprovalDateScope> dateScope;

  const ApprovalPage({
    this.approvals = const [],
    this.total = 0,
    this.totalAllDates = 0,
    this.limit = 0,
    this.offset = 0,
    this.dateFrom,
    this.dateTo,
    this.canFilterDate = false,
    this.dateScopeUniform = true,
    this.dateScope = const [],
  });

  /// How many rows the date filter is holding back right now.
  int get hiddenByDate =>
      totalAllDates > total ? totalAllDates - total : 0;

  /// The kinds of request still stuck on today because this employee does not
  /// hold that kind's date grant, while the rest of the range was widened.
  List<ApprovalDateScope> get pinnedToToday => dateScope
      .where((s) => !s.canFilterDate)
      .toList(growable: false);

  /// [listKey] differs between the two endpoints: the queue returns
  /// "approvals", my own requests return "requests".
  factory ApprovalPage.fromJson(Map<String, dynamic> json, String listKey) {
    final list = json[listKey];
    final scope = json['date_scope'];

    return ApprovalPage(
      approvals: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(Approval.fromJson)
              .toList()
          : const <Approval>[],
      total: _asInt(json['total']),
      totalAllDates: _asInt(json['total_all_dates']),
      limit: _asInt(json['limit']),
      offset: _asInt(json['offset']),
      dateFrom: _asString(json['date_from']),
      dateTo: _asString(json['date_to']),
      canFilterDate: json['can_filter_date'] == true,
      // Absent means uniform: an older server that does not send the field is
      // not filtering per model at all.
      dateScopeUniform: json['date_scope_uniform'] != false,
      dateScope: scope is List
          ? scope
              .whereType<Map<String, dynamic>>()
              .map(ApprovalDateScope.fromJson)
              .toList()
          : const <ApprovalDateScope>[],
    );
  }
}
