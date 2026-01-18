/// Financial Banking Dashboard Models (Leruma only)

/// Summary statistics for the financial banking dashboard
class FinancialSummary {
  final double totalBalance;
  final double totalDeposited;
  final double pendingDeposits;
  final int activeBeneficiaries;
  final double depositPercentage;

  FinancialSummary({
    required this.totalBalance,
    required this.totalDeposited,
    required this.pendingDeposits,
    required this.activeBeneficiaries,
    required this.depositPercentage,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      totalDeposited: (json['total_deposited'] ?? 0).toDouble(),
      pendingDeposits: (json['pending_deposits'] ?? 0).toDouble(),
      activeBeneficiaries: json['active_beneficiaries'] ?? 0,
      depositPercentage: (json['deposit_percentage'] ?? 0).toDouble(),
    );
  }
}

/// Deposit statistics
class DepositStatistics {
  final int totalTransactions;
  final int totalMismatches;
  final int totalPending;
  final int verifiedCount;

  DepositStatistics({
    required this.totalTransactions,
    required this.totalMismatches,
    required this.totalPending,
    required this.verifiedCount,
  });

  factory DepositStatistics.fromJson(Map<String, dynamic> json) {
    return DepositStatistics(
      totalTransactions: json['total_transactions'] ?? 0,
      totalMismatches: json['total_mismatches'] ?? 0,
      totalPending: json['total_pending'] ?? 0,
      verifiedCount: json['verified_count'] ?? 0,
    );
  }
}

/// Individual deposit record
class FinancialDeposit {
  final int id;
  final String depositDate;
  final String? invoiceDate;
  final String referenceNumber;
  final double amount;
  final String paymentMethod;
  final String beneficiaryName;
  final String bankName;
  final String efdName;
  final String supplierName;
  final String accountNumber;
  final double? lerumaAmount;
  final String? lerumaReference;
  final String? lerumaDate;
  final String status; // 'Verified', 'Mismatch', 'Not yet deposited'
  final String createdAt;

  FinancialDeposit({
    required this.id,
    required this.depositDate,
    this.invoiceDate,
    required this.referenceNumber,
    required this.amount,
    required this.paymentMethod,
    required this.beneficiaryName,
    required this.bankName,
    required this.efdName,
    required this.supplierName,
    required this.accountNumber,
    this.lerumaAmount,
    this.lerumaReference,
    this.lerumaDate,
    required this.status,
    required this.createdAt,
  });

  factory FinancialDeposit.fromJson(Map<String, dynamic> json) {
    return FinancialDeposit(
      id: json['id'] ?? 0,
      depositDate: json['deposit_date'] ?? '',
      invoiceDate: json['invoice_date'],
      referenceNumber: json['reference_number'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? '',
      beneficiaryName: json['beneficiary_name'] ?? '',
      bankName: json['bank_name'] ?? '',
      efdName: json['efd_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      lerumaAmount: json['leruma_amount']?.toDouble(),
      lerumaReference: json['leruma_reference'],
      lerumaDate: json['leruma_date'],
      status: json['status'] ?? 'Not yet deposited',
      createdAt: json['created_at'] ?? '',
    );
  }

  /// Check if deposit is verified
  bool get isVerified => status == 'Verified';

  /// Check if deposit has mismatch
  bool get isMismatched => status == 'Mismatch';

  /// Check if deposit is pending
  bool get isPending => status == 'Not yet deposited';
}

/// EFD (Electronic Fiscal Device) for filtering
class Efd {
  final int id;
  final String name;

  Efd({
    required this.id,
    required this.name,
  });

  factory Efd.fromJson(Map<String, dynamic> json) {
    return Efd(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

/// Bank account for a beneficiary
class BeneficiaryBankAccount {
  final String bankName;
  final String accountNumber;
  final int bankId;
  final int beneficiaryAccountId;

  BeneficiaryBankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.bankId,
    required this.beneficiaryAccountId,
  });

  factory BeneficiaryBankAccount.fromJson(Map<String, dynamic> json) {
    return BeneficiaryBankAccount(
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      bankId: json['bank_id'] ?? 0,
      beneficiaryAccountId: json['beneficiary_account_id'] ?? 0,
    );
  }
}

/// Beneficiary target with deposit progress
class BeneficiaryTarget {
  final int efdId;
  final int beneficiaryId;
  final String beneficiaryName;
  final int supplierId;
  final String supplierName;
  final String? description;
  final List<BeneficiaryBankAccount> bankAccounts;
  final double totalAmount;
  final double depositedAmount;
  final double remainingAmount;
  final double progressPercentage;

  BeneficiaryTarget({
    required this.efdId,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.supplierId,
    required this.supplierName,
    this.description,
    required this.bankAccounts,
    required this.totalAmount,
    required this.depositedAmount,
    required this.remainingAmount,
    required this.progressPercentage,
  });

  factory BeneficiaryTarget.fromJson(Map<String, dynamic> json) {
    final accountsJson = json['bank_accounts'] as List? ?? [];
    return BeneficiaryTarget(
      efdId: json['efd_id'] ?? 0,
      beneficiaryId: json['beneficiary_id'] ?? 0,
      beneficiaryName: json['beneficiary_name'] ?? '',
      supplierId: json['supplier_id'] ?? 0,
      supplierName: json['supplier_name'] ?? '',
      description: json['description'],
      bankAccounts: accountsJson
          .map((a) => BeneficiaryBankAccount.fromJson(a))
          .toList(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      depositedAmount: (json['deposited_amount'] ?? 0).toDouble(),
      remainingAmount: (json['remaining_amount'] ?? 0).toDouble(),
      progressPercentage: (json['progress_percentage'] ?? 0).toDouble(),
    );
  }

  /// Check if deposit is complete
  bool get isComplete => progressPercentage >= 100;

  /// Check if deposit has started
  bool get hasDeposits => depositedAmount > 0;
}

/// Complete dashboard response
class FinancialDashboard {
  final FinancialSummary summary;
  final DepositStatistics statistics;
  final List<BeneficiaryTarget> beneficiaryTargets;
  final List<FinancialDeposit> deposits;
  final List<Efd> efds;
  final String startDate;
  final String endDate;
  final int? efdId;

  FinancialDashboard({
    required this.summary,
    required this.statistics,
    required this.beneficiaryTargets,
    required this.deposits,
    required this.efds,
    required this.startDate,
    required this.endDate,
    this.efdId,
  });

  factory FinancialDashboard.fromJson(Map<String, dynamic> json) {
    final targetsJson = json['beneficiary_targets'] as List? ?? [];
    final depositsJson = json['deposits'] as List? ?? [];
    final efdsJson = json['efds'] as List? ?? [];
    final filters = json['filters'] as Map<String, dynamic>? ?? {};

    return FinancialDashboard(
      summary: FinancialSummary.fromJson(json['summary'] ?? {}),
      statistics: DepositStatistics.fromJson(json['statistics'] ?? {}),
      beneficiaryTargets:
          targetsJson.map((t) => BeneficiaryTarget.fromJson(t)).toList(),
      deposits: depositsJson.map((d) => FinancialDeposit.fromJson(d)).toList(),
      efds: efdsJson.map((e) => Efd.fromJson(e)).toList(),
      startDate: filters['start_date'] ?? '',
      endDate: filters['end_date'] ?? '',
      efdId: filters['efd_id'],
    );
  }
}

/// Request model for creating a deposit
class CreateDepositRequest {
  final int beneficiaryId;
  final int supplierId;
  final int efdId;
  final double amount;
  final String depositDate;
  final String? invoiceDate;
  final String referenceNumber;
  final String paymentMethod;
  final String bankName;
  final String accountNumber;
  final int beneficiaryAccountId;
  final int bankId;
  final String? notes;

  CreateDepositRequest({
    required this.beneficiaryId,
    required this.supplierId,
    required this.efdId,
    required this.amount,
    required this.depositDate,
    this.invoiceDate,
    required this.referenceNumber,
    required this.paymentMethod,
    required this.bankName,
    required this.accountNumber,
    required this.beneficiaryAccountId,
    required this.bankId,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'beneficiary_id': beneficiaryId,
      'supplier_id': supplierId,
      'efd_id': efdId,
      'amount': amount,
      'deposit_date': depositDate,
      'invoice_date': invoiceDate,
      'reference_number': referenceNumber,
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'account_number': accountNumber,
      'beneficiary_account_id': beneficiaryAccountId,
      'bank_id': bankId,
      'notes': notes,
    };
  }
}
