/// The catalogue of write actions the app can hold on the device until a
/// network comes back, and the words for the ones it deliberately cannot.
///
/// Everything here CREATES something the server can settle on arrival. That is
/// the whole admission test. An action that needs to read server state first --
/// how much of a sale is left to return, what a customer's balance is now,
/// whether an approval has already been decided by somebody else -- cannot be
/// queued, because the copy sitting in the queue would be deciding on facts
/// that were true when the phone went dark and may not be true when it wakes.
/// Those live in [OnlineOnly] instead, and are refused by name.
///
/// The exactly-once guarantee is the same one sales already have (see
/// `sync_service.dart` and commit ba6624d): one request_id per logical action,
/// minted once, PERSISTED next to the payload, and reused verbatim on every
/// attempt. `API_Controller::claim_request_id()` claims the id on the first
/// request, replays the original stored response for a retry, and answers 409
/// while our own earlier attempt is still running -- so a queued upload of an
/// action that did reach the server last time returns that same record instead
/// of writing a second one.
library;

/// One queueable action type.
///
/// [type] is written into SQLite and read back by a later app version, so an
/// existing value must never be changed -- a queued row whose type no longer
/// resolves cannot be uploaded. [endpoint] is what makes the replay identical
/// to the original attempt: the queue re-POSTs the same path with the same
/// body and the same key, rather than rebuilding the request from a model that
/// may have moved on.
class OfflineAction {
  /// Stable key stored in `pending_actions.action_type`.
  final String type;

  /// Path under the API root, e.g. `expenses/create`.
  final String endpoint;

  /// What a person calls this thing, in English. Used in every message the
  /// user sees about it, so it reads as the thing they just did.
  final String label;

  const OfflineAction._(this.type, this.endpoint, this.label);

  // --- Money going out and stock coming in -------------------------------

  static const expense =
      OfflineAction._('expense', 'expenses/create', 'Expense');
  static const receiving =
      OfflineAction._('receiving', 'receivings/create', 'Receiving');

  // --- Banking ------------------------------------------------------------

  static const bankingDeposit =
      OfflineAction._('banking_deposit', 'banking/add_deposit', 'Bank deposit');
  static const banking =
      OfflineAction._('banking', 'banking/create', 'Banking record');

  // --- End-of-shift paperwork --------------------------------------------

  static const cashSubmit =
      OfflineAction._('cash_submit', 'cashsubmit/create', 'Cash submission');
  static const profitSubmit = OfflineAction._(
      'profit_submit', 'profitsubmit/create', 'Profit submission');
  static const zReport =
      OfflineAction._('zreport', 'zreports/create', 'Z report');

  // --- Requests that go to an approver -----------------------------------
  //
  // Creating a request is safe to queue: it is new work for somebody else to
  // look at, and nothing about it depends on server state. DECIDING one is
  // not, and is refused -- see [OnlineOnly.approve].

  static const discountRequest = OfflineAction._(
      'discount_request', 'discount_requests/create', 'Discount request');
  static const oneTimeDiscountRequest = OfflineAction._(
      'one_time_discount_request',
      'one_time_discounts/create',
      'One-time discount request');
  static const creditLimitRequest = OfflineAction._('credit_limit_request',
      'customer_credit_limits/create', 'Credit limit request');

  // --- People -------------------------------------------------------------

  static const customer =
      OfflineAction._('customer', 'customers/create', 'Customer');
  static const supplier =
      OfflineAction._('supplier', 'suppliers/create', 'Supplier');

  // --- transactions/add_* -------------------------------------------------

  static const transactionDeposit = OfflineAction._(
      'transaction_deposit', 'transactions/add_deposit', 'Customer deposit');
  static const transactionWithdrawal = OfflineAction._(
      'transaction_withdrawal',
      'transactions/add_withdrawal',
      'Customer withdrawal');
  static const cashBasis = OfflineAction._(
      'cash_basis', 'transactions/add_cash_basis', 'Cash transaction');
  static const cashBasisCategory = OfflineAction._('cash_basis_category',
      'transactions/add_cash_basis_category', 'Cash category');
  static const bankBasis = OfflineAction._(
      'bank_basis', 'transactions/add_bank_basis', 'Bank transaction');
  static const bankBasisCategory = OfflineAction._('bank_basis_category',
      'transactions/add_bank_basis_category', 'Bank category');
  static const sim = OfflineAction._('sim', 'transactions/add_sim', 'SIM card');
  static const wakala = OfflineAction._(
      'wakala', 'transactions/add_wakala', 'Wakala transaction');
  static const wakalaExpense = OfflineAction._(
      'wakala_expense', 'transactions/add_wakala_expense', 'Wakala expense');
  static const commission = OfflineAction._(
      'commission', 'transactions/add_commission', 'Commission');
  static const capital =
      OfflineAction._('capital', 'transactions/add_capital', 'Capital');

  /// Every queueable action. The sync queue resolves a stored row's type
  /// through this list, so an action missing from it is one the queue cannot
  /// upload -- which is why adding a `static const` above without adding it
  /// here would be a silent bug rather than a compile error.
  static const List<OfflineAction> values = <OfflineAction>[
    expense,
    receiving,
    bankingDeposit,
    banking,
    cashSubmit,
    profitSubmit,
    zReport,
    discountRequest,
    oneTimeDiscountRequest,
    creditLimitRequest,
    customer,
    supplier,
    transactionDeposit,
    transactionWithdrawal,
    cashBasis,
    cashBasisCategory,
    bankBasis,
    bankBasisCategory,
    sim,
    wakala,
    wakalaExpense,
    commission,
    capital,
  ];

  /// The action a stored row belongs to, or null if this build does not know
  /// the type. Null is handled as a refusal to upload, never as a reason to
  /// guess at an endpoint.
  static OfflineAction? byType(String type) {
    for (final action in values) {
      if (action.type == type) return action;
    }
    return null;
  }

  @override
  String toString() => 'OfflineAction($type -> $endpoint)';
}

/// Actions that must reach the server while the person is still standing
/// there, and the reason each one cannot wait in a queue.
///
/// These are not an oversight. Queueing any of them would let the device
/// decide something only the server can know, and the damage would surface
/// hours later as a double refund, an overspent wallet or an approval granted
/// twice. Refusing is the smaller harm, so long as the refusal says which
/// action it is about -- which is what [message] is for.
class OnlineOnly {
  const OnlineOnly._();

  /// Deciding an approval: the request may have been decided by someone else,
  /// or advanced a step, while this device was dark.
  static const String approve = 'Approving a request';
  static const String reject = 'Rejecting a request';
  static const String bulkApprove = 'Approving these requests';
  static const String bulkReject = 'Rejecting these requests';
  static const String approveDiscount = 'Approving a discount request';
  static const String rejectDiscount = 'Rejecting a discount request';

  /// A return depends on the quantity still returnable on that sale, which
  /// only the server knows; a queued one could over-return.
  static const String processReturn = 'Returning a sale';

  /// The balance is authoritative on the server. Deducting offline spends
  /// money that may not be there.
  static const String nfcWallet = 'This NFC wallet action';
  static const String creditPayment = 'Recording a credit payment';

  /// Anything that targets a server id -- an id the record may not have yet,
  /// because the record itself could still be sitting in the queue.
  static String edit(String what) => 'Editing this $what';
  static String remove(String what) => 'Deleting this $what';

  /// What the user is told. Names the action, says a connection is needed, and
  /// -- the part that stops people tapping again and again -- says plainly
  /// that nothing was saved and nothing will be retried on its own.
  static String message(String action) =>
      '$action needs an internet connection. Nothing was saved and this will '
      'not be retried automatically. Reconnect and try again.';
}
