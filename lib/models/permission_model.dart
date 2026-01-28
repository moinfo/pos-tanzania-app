class Permission {
  final String permissionId;
  final String moduleId;
  final String? menuGroup;
  final int? locationId;

  Permission({
    required this.permissionId,
    required this.moduleId,
    this.menuGroup,
    this.locationId,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    // Handle location_id which can be a string or int from API
    int? parsedLocationId;
    if (json['location_id'] != null) {
      if (json['location_id'] is int) {
        parsedLocationId = json['location_id'];
      } else if (json['location_id'] is String) {
        parsedLocationId = int.tryParse(json['location_id']);
      }
    }

    return Permission(
      permissionId: json['permission_id'] as String,
      moduleId: json['module_id'] as String,
      menuGroup: json['menu_group'] as String?,
      locationId: parsedLocationId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permission_id': permissionId,
      'module_id': moduleId,
      'menu_group': menuGroup,
      'location_id': locationId,
    };
  }

  @override
  String toString() {
    return 'Permission(permissionId: $permissionId, moduleId: $moduleId, menuGroup: $menuGroup)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Permission && other.permissionId == permissionId;
  }

  @override
  int get hashCode => permissionId.hashCode;
}

/// User permissions response from API
class UserPermissionsResponse {
  final List<Permission> permissions;

  UserPermissionsResponse({required this.permissions});

  factory UserPermissionsResponse.fromJson(Map<String, dynamic> json) {
    final permissionsJson = json['permissions'] as List<dynamic>? ?? [];
    return UserPermissionsResponse(
      permissions: permissionsJson
          .map((p) => Permission.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permissions': permissions.map((p) => p.toJson()).toList(),
    };
  }
}

/// Permission groups for easy reference
class PermissionIds {
  // Module-level permissions (from ospos_permissions table)
  static const String home = 'home';
  static const String sales = 'sales';
  static const String receivings = 'receivings';
  static const String items = 'items';
  static const String itemKits = 'item_kits';
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';
  static const String reports = 'reports';
  static const String employees = 'employees';
  static const String giftcards = 'giftcards';
  static const String messages = 'messages';
  static const String taxes = 'taxes';
  static const String config = 'config';
  static const String office = 'office';
  static const String contracts = 'contracts';
  static const String expenses = 'expenses';
  static const String withdrawal = 'withdrawal';
  static const String cashSubmit = 'cash_submit';
  static const String clients = 'clients';
  static const String credits = 'credits';

  // Module aliases for features
  static const String zreports = cashSubmitZReport;
  static const String profitSubmit = office;

  // Banking module permissions
  static const String banking = 'banking';
  static const String bankingAddDeposit = 'banking_add_deposit';
  static const String bankingEditDeposit = 'banking_edit_deposit';
  static const String bankingDeleteDeposit = 'banking_delete_deposit';
  static const String bankingDateRangeFilter = 'banking_date_range_filter';
  static const String bankingDate = 'banking_date'; // Permission to change date when adding/editing
  static const String bankingSelectAllEfds = 'banking_select_all_efds'; // Can see all EFDs
  static const String bankingMismatchReport = 'banking_mismatch_report'; // View mismatch report

  // Items sub-permissions
  static const String itemsAdd = 'items_add';
  static const String itemsEdit = 'items_edit';
  static const String itemsDelete = 'items_delete';
  static const String itemsView = 'items_view';
  static const String itemsCategories = 'items_categories';
  static const String itemsCostPrice = 'items_cost_price';
  static const String itemsQuantity = 'items_quantity';
  static const String itemsStock = 'items_stock';
  static const String itemsInventory = 'items_inventory';
  static const String itemsDormantInactive = 'items_dormant_inactive_items';
  static const String itemsMakeDormantActive = 'items_make_item_dormant_active';
  static const String itemAllowOthersFillable = 'item_allow_others_fillable';
  static const String itemsBagamoyo = 'items_BAGAMOYO';
  static const String itemsKiwangwa = 'items_KIWANGWA';

  // Sales sub-permissions
  static const String salesAdd = 'sales_add';
  static const String salesAddPayment = 'sales_add_payment';
  static const String salesEdit = 'sales_edit';
  static const String salesDelete = 'sales_delete';
  static const String salesView = 'sales_view';
  static const String salesStock = 'sales_stock';
  static const String salesChangeModeReturn = 'sales_change_mode_return';
  static const String salesSuspended = 'sales_suspended';
  static const String salesUnsuspended = 'sales_unsuspended';
  static const String salesUnsuspendPrint = 'sales_unsuspend_print';
  static const String salesPrintedLogs = 'sales_printed_logs';
  static const String salesTransactionDate = 'sales_transaction_date';
  static const String salesKiwangwa = 'sales_KIWANGWA';
  static const String salesBagamoyo = 'sales_BAGAMOYO';

  // Receivings sub-permissions
  static const String receivingsAdd = 'receivings_add';
  static const String receivingsEdit = 'receivings_edit';
  static const String receivingsDelete = 'receivings_delete';
  static const String receivingsView = 'receivings_view';
  static const String receivingsStock = 'receivings_stock';
  static const String receivingsKiwangwa = 'receivings_KIWANGWA';
  static const String receivingsBagamoyo = 'receivings_BAGAMOYO';

  // Customers sub-permissions
  static const String customersView = 'customers_view';
  static const String customersAdd = 'customers_add';
  static const String customersEdit = 'customers_edit';
  static const String customersDelete = 'customers_delete';
  static const String customersAddPayment = 'customers_add_payment';
  static const String customersViewCredit = 'customers_view_credit';
  static const String customersDormantInactive = 'customers_dormant_inactive_customers';
  static const String customersMakeDormantActive = 'customers_make_customer_dormant_active';

  // Suppliers sub-permissions
  static const String suppliersAdd = 'suppliers_add';
  static const String suppliersEdit = 'suppliers_edit';
  static const String suppliersDelete = 'suppliers_delete';
  static const String suppliersView = 'suppliers_view';
  static const String suppliersCreditors = 'suppliers_creditors';
  static const String suppliersCreditorsAdd = 'suppliers_creditors_add';
  static const String suppliersCreditorsEdit = 'suppliers_creditors_edit';
  static const String suppliersCreditorsDelete = 'suppliers_creditors_delete';
  static const String suppliersCreditorsView = 'suppliers_creditors_view';
  static const String suppliersCreditorsPayment = 'suppliers_creditors_make_payment';
  static const String suppliersCreditorsDate = 'suppliers_creditors_date';
  static const String suppliersCreditorsEditDate = 'suppliers_creditors_edit_date';

  // Clients sub-permissions
  static const String clientsEdit = 'clients_edit';
  static const String clientsDelete = 'clients_delete';
  static const String clientsCanAllowCredit = 'clients_can_allow_credit';

  // Credits sub-permissions
  static const String creditsEdit = 'credits_edit';
  static const String creditsDelete = 'credits_delete';
  static const String creditsPay = 'credits_pay';
  static const String creditsTransfer = 'credits_transfer';
  static const String creditsDate = 'credits_date';
  static const String creditsEditDate = 'credits_edit_date';

  // Cash submission sub-permissions (comprehensive list)
  // Note: Location permissions use sales_ prefix (sales_KIWANGWA, sales_BAGAMOYO)
  static const String cashSubmitView = 'cash_submit_view';
  static const String cashSubmitAdd = 'cash_submit_add';
  static const String cashSubmitEdit = 'cash_submit_edit';
  static const String cashSubmitDelete = 'cash_submit_delete';
  static const String cashSubmitDate = 'cash_submit_date';
  static const String cashSubmitAddBanking = 'cash_submit_add_banking';
  static const String cashSubmitBanking = 'cash_submit_banking';
  static const String cashSubmitDeleteBanking = 'cash_submit_delete_banking';
  static const String cashSubmitEditBanking = 'cash_submit_edit_banking';
  static const String cashSubmitBankingDate = 'cash_submit_banking_date';
  static const String cashSubmitAddZReport = 'cash_submit_add_z_report';
  static const String cashSubmitDeleteZReport = 'cash_submit_delete_z_report';
  static const String cashSubmitEditZReport = 'cash_submit_edit_z_report';
  static const String cashSubmitZReport = 'cash_submit_z_report';
  static const String cashSubmitZReportDate = 'cash_submit_z_report_date';
  static const String cashSubmitSupervisor = 'cash_submit_supervisor';
  static const String cashSubmitAdmin = 'cash_submit_admin';
  static const String cashSubmitUser = 'cash_submit_user';
  static const String cashSubmitAudit = 'cash_submit_audit';
  static const String cashSubmitOpenCash = 'cash_submit_open_cash';
  static const String cashSubmitOpening = 'cash_submit_opening';
  static const String cashSubmitAllSales = 'cash_submit_all_sales';
  static const String cashSubmitCashSales = 'cash_submit_cash_sales';
  static const String cashSubmitBongeSales = 'cash_submit_bonge_sales';
  static const String cashSubmitCashAmount = 'cash_submit_cash_amount';
  static const String cashSubmitAmountTendered = 'cash_submit_amount_tendered';
  static const String cashSubmitAmountDue = 'cash_submit_amount_due';
  static const String cashSubmitSalesReturn = 'cash_submit_sales_return';
  static const String cashSubmitReceivingReturn = 'cash_submit_receiving_return';
  static const String cashSubmitSalesDiscount = 'cash_submit_sales_discount';
  static const String cashSubmitExpenses = 'cash_submit_expenses';
  static const String cashSubmitSupplierCash = 'cash_submit_supplier_cash';
  static const String cashSubmitSupplierCredit = 'cash_submit_supplier_credit';
  static const String cashSubmitCustomerCredit = 'cash_submit_customer_credit';
  static const String cashSubmitDebitCustomer = 'cash_submit_debit_customer';
  static const String cashSubmitDebitSupplierCash = 'cash_submit_debit_supplier_cash';
  static const String cashSubmitDebitSupplierBank = 'cash_submit_debit_supplier_bank';
  static const String cashSubmitTransportCost = 'cash_submit_transport_cost';
  static const String cashSubmitDamage = 'cash_submit_damage';
  static const String cashSubmitGainLoss = 'cash_submit_gain_loss';
  static const String cashSubmitTurnover = 'cash_submit_turnover';
  static const String cashSubmitProfit = 'cash_submit_profit';
  static const String cashSubmitAddProfit = 'cash_submit_add_profit';
  static const String cashSubmitEditProfit = 'cash_submit_edit_profit';
  static const String cashSubmitDeleteProfit = 'cash_submit_delete_profit';
  static const String cashSubmitProfitDate = 'cash_submit_profit_date';
  static const String cashSubmitCashSubmitted = 'cash_submit_cash_submitted';
  static const String cashSubmitBankingAmount = 'cash_submit_banking_amount';
  static const String cashSubmitProfitSubmitted = 'cash_submit_profit_submitted';
  static const String cashSubmitFinancialBanking = 'cash_submit_financial_banking';
  static const String cashSubmitDifference = 'cash_submit_difference';
  static const String cashSubmitDifferenceMrBs = 'cash_submit_difference_mr_bs';
  static const String cashSubmitMainStoreReceiving = 'cash_submit_main_store_receiving';
  // Leruma-specific permissions
  static const String cashSubmitChipDeposited = 'cash_submit_chip_deposited';
  static const String cashSubmitChipUsed = 'cash_submit_chip_used';
  static const String cashSubmitManualEditing = 'cash_submit_manual_editing';
  static const String cashSubmitManualEditingWorkout = 'cash_submit_manual_editing_workout';
  static const String cashSubmitChangeDue = 'cash_submit_change_due';
  static const String cashSubmitDifferenceManualEditing = 'cash_submit_difference_manual_editing';
  static const String cashSubmitDoubleSalesItems = 'cash_submit_double_sales_items';
  static const String cashSubmitSellerReport = 'cash_submit_seller_report';

  // Transactions module (base permission)
  static const String transactions = 'transactions';

  // Transactions module sub-permissions
  // Main menu permissions
  static const String transactionsDepositsAndWithdraws = 'transactions_deposits_and_withdraws';
  static const String transactionsWakalaReport = 'transactions_wakala_report';

  // Cash Basis
  static const String transactionsCashBasis = 'transactions_cash_basis';
  static const String transactionsCashBasisAdd = 'transactions_cash_basis_add';
  static const String transactionsCashBasisEdit = 'transactions_cash_basis_edit';
  static const String transactionsCashBasisDelete = 'transactions_cash_basis_delete';
  static const String transactionsCashBasisSettingAdd = 'transactions_cash_basis_setting_add';
  static const String transactionsCashBasisSettingEdit = 'transactions_cash_basis_setting_edit';
  static const String transactionsCashBasisSettingDelete = 'transactions_cash_basis_setting_delete';

  // Bank Basis
  static const String transactionsBankBasis = 'transactions_bank_basis';
  static const String transactionsBankBasisAdd = 'transactions_bank_basis_add';
  static const String transactionsBankBasisEdit = 'transactions_bank_basis_edit';
  static const String transactionsBankBasisDelete = 'transactions_bank_basis_delete';
  static const String transactionsBankBasisSettingAdd = 'transactions_bank_basis_setting_add';
  static const String transactionsBankBasisSettingEdit = 'transactions_bank_basis_setting_edit';
  static const String transactionsBankBasisSettingDelete = 'transactions_bank_basis_setting_delete';

  // Customer Transactions (Deposits & Withdrawals)
  static const String transactionsCustomer = 'transactions_customer';
  static const String transactionsDepositAdd = 'transactions_deposit_add';
  static const String transactionsDepositEdit = 'transactions_deposit_edit';
  static const String transactionsDepositDelete = 'transactions_deposit_delete';
  static const String transactionsWithdrawAdd = 'transactions_withdraw_add';
  static const String transactionsWithdrawEdit = 'transactions_withdraw_edit';
  static const String transactionsWithdrawDelete = 'transactions_withdraw_delete';

  // Wakala
  static const String transactionsWakala = 'transactions_wakala';
  static const String transactionsWakalaAdd = 'transactions_wakala_add';
  static const String transactionsWakalaEdit = 'transactions_wakala_edit';
  static const String transactionsWakalaDelete = 'transactions_wakala_delete';
  static const String transactionsWakalaSettingAdd = 'transactions_wakala_setting_add';
  static const String transactionsWakalaSettingEdit = 'transactions_wakala_setting_edit';
  static const String transactionsWakalaSettingDelete = 'transactions_wakala_setting_delete';

  // Wakala Expenses
  static const String transactionsWakalaExpenses = 'transactions_wakala_expenses';
  static const String transactionsWakalaExpensesAdd = 'transactions_wakala_expenses_add';
  static const String transactionsWakalaExpensesEdit = 'transactions_wakala_expenses_edit';
  static const String transactionsWakalaExpensesDelete = 'transactions_wakala_expenses_delete';

  // Reports sub-permissions
  static const String reportsCustomers = 'reports_customers';
  static const String reportsReceivings = 'reports_receivings';
  static const String reportsItems = 'reports_items';
  static const String reportsInventory = 'reports_inventory';
  static const String reportsEmployees = 'reports_employees';
  static const String reportsSuppliers = 'reports_suppliers';
  static const String reportsSales = 'reports_sales';
  static const String reportsDiscounts = 'reports_discounts';
  static const String reportsTaxes = 'reports_taxes';
  static const String reportsCategories = 'reports_categories';
  static const String reportsPayments = 'reports_payments';

  // Stock Tracking sub-permissions (uses items_stock permission)
  static const String stockTracking = 'items_stock';

  // Giftcards sub-permissions
  static const String giftcardsAdd = 'giftcards_add';
  static const String giftcardsDelete = 'giftcards_delete';

  // Expenses sub-permissions
  static const String expensesAdd = 'expenses_add';
  static const String expensesEdit = 'expenses_edit';
  static const String expensesDelete = 'expenses_delete';
  static const String expensesView = 'expenses_view';
  static const String expensesDate = 'expenses_date';
  static const String expensesApprove = 'expenses_approve';
  static const String expensesGivenExpenses = 'expenses_given_expenses';
  static const String expensesAddDriverBudget = 'expenses_add_driver_budget';
  static const String expensesEditDriverBudget = 'expenses_edit_driver_budget';
  static const String expensesDeleteDriverBudget = 'expenses_delete_driver_budget';
  static const String expensesCategoriesAdd = 'expenses_categories_add';
  static const String expensesCategoriesEdit = 'expenses_categories_edit';
  static const String expensesCategoriesDelete = 'expenses_categories_delete';
  static const String expensesCategoriesView = 'expenses_categories_view';

  // Estimations sub-permissions
  static const String estimationsAdd = 'estimations_add';
  static const String estimationsDelete = 'estimations_delete';

  // Transfers sub-permissions
  static const String transfersDelete = 'transfers_delete';

  // Withdrawal sub-permissions
  static const String withdrawalAdd = 'withdrawal_add';
  static const String withdrawalDelete = 'withdrawal_delete';

  // Issues sub-permissions
  static const String issuesAdd = 'issues_add';
  static const String issuesDelete = 'issues_delete';

  // Employee management sub-permissions
  static const String manageEmployeeAdd = 'manage_employee_add';
  static const String manageEmployeeEdit = 'manage_employee_edit';
  static const String manageEmployeePay = 'manage_employee_pay';

  // Supervisors sub-permissions
  static const String supervisorsAdd = 'supervisors_add';
  static const String supervisorsDelete = 'supervisors_delete';

  // NFC Cards sub-permissions
  static const String nfcCardsView = 'nfc_cards_view';
  static const String nfcCardsRegister = 'nfc_cards_register';
  static const String nfcCardsUnregister = 'nfc_cards_unregister';
  static const String nfcCardsDeposit = 'nfc_cards_deposit';
  static const String nfcCardsStatement = 'nfc_cards_statement';
  static const String nfcCardsSettings = 'nfc_cards_settings';
  static const String nfcConfirmationsView = 'nfc_confirmations_view';
  static const String nfcPayment = 'nfc_payment';

  // TRA (TRADE) module permissions
  static const String tra = 'TRA';
  static const String traDateFilter = 'tra_date_filter';
  static const String traFilterAllEfd = 'tra_filter_all_efd';
  static const String traEditZNumbers = 'tra_edit_z_numbers';
  // Sales
  static const String traViewSales = 'tra_view_sales';
  static const String traAddSales = 'tra_add_sales';
  static const String traEditSales = 'tra_edit_sales';
  static const String traDeleteSales = 'tra_delete_sales';
  // Purchases
  static const String traViewPurchases = 'tra_view_purchases';
  static const String traAddPurchases = 'tra_add_purchases';
  static const String traEditPurchases = 'tra_edit_purchases';
  static const String traDeletePurchases = 'tra_delete_purchases';
  // Expenses
  static const String traViewExpenses = 'tra_view_expenses';
  static const String traAddExpenses = 'tra_add_expenses';
  static const String traEditExpenses = 'tra_edit_expenses';
  static const String traDeleteExpenses = 'tra_delete_expenses';
  // Reports
  static const String traViewReports = 'tra_view_reports';
  static const String traViewExpensesReports = 'tra_view_expenses_reports';
  static const String traViewSalesReports = 'tra_view_sales_reports';
  static const String traViewPurchasesReports = 'tra_view_purchases_reports';

  // Shops permissions (under customers module, SADA only)
  static const String customersShops = 'customers_shops';
  static const String customersShopsView = 'customers_shops_view';
  static const String customersShopsAdd = 'customers_shops_add';
  static const String customersShopsEdit = 'customers_shops_edit';
  static const String customersShopsDelete = 'customers_shops_delete';
}