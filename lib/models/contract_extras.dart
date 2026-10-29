/// The Contracts module's tenant-wide screens beyond the main list/detail:
/// Payments, Services, Payment requests, Inspections, Messages -- see
/// CONTRACTS_MODULE.md on the backend and api/Contracts.php's matching
/// endpoints (payments/services/payment-requests/inspections/messages).

class ContractPaymentEntry {
  final int id;
  final int contractId;
  final String contractName;
  final double amount;
  final String date;
  final String? description;
  final String? receiptUrl;

  ContractPaymentEntry({
    required this.id,
    required this.contractId,
    required this.contractName,
    required this.amount,
    required this.date,
    this.description,
    this.receiptUrl,
  });

  factory ContractPaymentEntry.fromJson(Map<String, dynamic> json) {
    return ContractPaymentEntry(
      id: json['id'] as int,
      contractId: json['contract_id'] as int,
      contractName: json['contract_name'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      date: json['date'] as String,
      description: json['description'] as String?,
      receiptUrl: json['receipt_url'] as String?,
    );
  }
}

class ContractServiceEntry {
  final int id;
  final int contractId;
  final String contractName;
  final double amount;
  final String date;
  final String? description;

  ContractServiceEntry({
    required this.id,
    required this.contractId,
    required this.contractName,
    required this.amount,
    required this.date,
    this.description,
  });

  factory ContractServiceEntry.fromJson(Map<String, dynamic> json) {
    return ContractServiceEntry(
      id: json['id'] as int,
      contractId: json['contract_id'] as int,
      contractName: json['contract_name'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      date: json['date'] as String,
      description: json['description'] as String?,
    );
  }
}

/// A customer-submitted payment claim (amount + receipt photo) awaiting
/// staff approval -- doesn't touch the ledger until approved. See
/// Contract_payment_request on the backend.
class ContractPaymentRequest {
  final int id;
  final int contractId;
  final String contractName;
  final String? contractDescription;
  final String? contractPhone;
  final double amount;
  final String date;
  final String receiptUrl;
  final String status; // pending / approved / rejected
  final String createdAt;

  ContractPaymentRequest({
    required this.id,
    required this.contractId,
    required this.contractName,
    this.contractDescription,
    this.contractPhone,
    required this.amount,
    required this.date,
    required this.receiptUrl,
    required this.status,
    required this.createdAt,
  });

  factory ContractPaymentRequest.fromJson(Map<String, dynamic> json) {
    return ContractPaymentRequest(
      id: json['id'] as int,
      contractId: json['contract_id'] as int,
      contractName: json['contract_name'] as String? ?? '',
      contractDescription: json['contract_description'] as String?,
      contractPhone: json['contract_phone'] as String?,
      amount: (json['amount'] as num).toDouble(),
      date: json['date'] as String,
      receiptUrl: json['receipt_url'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// One row of the Inspections report -- every active contract with an
/// inspection interval configured, overdue ones first.
class ContractInspectionDue {
  final int contractId;
  final String name;
  final String? contractDescription;
  final String? phone;
  final String? assetPlateNumber;
  final String inspectionDueDate;
  final bool inspectionOverdue;

  ContractInspectionDue({
    required this.contractId,
    required this.name,
    this.contractDescription,
    this.phone,
    this.assetPlateNumber,
    required this.inspectionDueDate,
    required this.inspectionOverdue,
  });

  factory ContractInspectionDue.fromJson(Map<String, dynamic> json) {
    return ContractInspectionDue(
      contractId: json['contract_id'] as int,
      name: json['name'] as String? ?? '',
      contractDescription: json['contract_description'] as String?,
      phone: json['phone'] as String?,
      assetPlateNumber: json['asset_plate_number'] as String?,
      inspectionDueDate: json['inspection_due_date'] as String,
      inspectionOverdue: json['inspection_overdue'] as bool? ?? false,
    );
  }
}

/// One past inspection, from a single contract's history.
class ContractInspectionRecord {
  final int id;
  final String inspectedAt;
  final String? notes;
  final String recordedByName;

  ContractInspectionRecord({
    required this.id,
    required this.inspectedAt,
    this.notes,
    required this.recordedByName,
  });

  factory ContractInspectionRecord.fromJson(Map<String, dynamic> json) {
    return ContractInspectionRecord(
      id: json['id'] as int,
      inspectedAt: json['inspected_at'] as String,
      notes: json['notes'] as String?,
      recordedByName: json['recorded_by_name'] as String? ?? '',
    );
  }
}

/// One row of the "Sent" message log (SMS/WhatsApp actually attempted).
class ContractMessageLogEntry {
  final int id;
  final int? contractId;
  final String? contractName;
  final String recipientRole;
  final String messageType;
  final String messageTypeLabel;
  final String channel;
  final String phone;
  final String message;
  final String status; // sent / failed
  final String createdAt;

  ContractMessageLogEntry({
    required this.id,
    this.contractId,
    this.contractName,
    required this.recipientRole,
    required this.messageType,
    required this.messageTypeLabel,
    required this.channel,
    required this.phone,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory ContractMessageLogEntry.fromJson(Map<String, dynamic> json) {
    return ContractMessageLogEntry(
      id: json['id'] as int,
      contractId: json['contract_id'] as int?,
      contractName: json['contract_name'] as String?,
      recipientRole: json['recipient_role'] as String? ?? '',
      messageType: json['message_type'] as String? ?? '',
      messageTypeLabel: json['message_type_label'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// One row of the live-computed "Upcoming" preview -- what would go out
/// at the next cron run if nothing changes. Nothing here has been sent.
class ContractUpcomingMessage {
  final int contractId;
  final String contractName;
  final String type;
  final String label;
  final String message;
  final String severity; // default / warning / danger
  final List<String> notes;

  ContractUpcomingMessage({
    required this.contractId,
    required this.contractName,
    required this.type,
    required this.label,
    required this.message,
    required this.severity,
    required this.notes,
  });

  factory ContractUpcomingMessage.fromJson(Map<String, dynamic> json) {
    return ContractUpcomingMessage(
      contractId: json['contract_id'] as int,
      contractName: json['contract_name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'default',
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ContractMessagesReport {
  final List<ContractMessageLogEntry> sent;
  final List<ContractUpcomingMessage> upcoming;

  ContractMessagesReport({required this.sent, required this.upcoming});

  factory ContractMessagesReport.fromJson(Map<String, dynamic> json) {
    return ContractMessagesReport(
      sent: (json['sent'] as List<dynamic>? ?? const [])
          .map((e) => ContractMessageLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      upcoming: (json['upcoming'] as List<dynamic>? ?? const [])
          .map((e) => ContractUpcomingMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
