// Stock Transfers between stock locations (ARG Sparkles only).
// No JSON endpoint exists for the pending/history lists - Stock_transfers::index()
// renders them straight into HTML tables, so these are parsed from that page
// (see StockTransferService._parseHtml). issue_batch/confirm_batch/cancel_batch/
// issue/confirm/cancel/batch_items are real JSON endpoints.

class PendingBatch {
  final int batchId;
  final String fromLocationName;
  final String toLocationName;
  final int itemCount;
  final String issuedByName;
  final String issuedDate;
  final String note;

  PendingBatch({
    required this.batchId,
    required this.fromLocationName,
    required this.toLocationName,
    required this.itemCount,
    required this.issuedByName,
    required this.issuedDate,
    required this.note,
  });
}

class BatchItem {
  final String itemName;
  final String quantity;

  BatchItem({required this.itemName, required this.quantity});

  factory BatchItem.fromJson(Map<String, dynamic> json) {
    return BatchItem(
      itemName: json['item_name']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
    );
  }
}

class PendingTransfer {
  final int? transferId; // null if this staff member has no confirm/cancel grant
  final String itemName;
  final String quantity;
  final String fromLocationName;
  final String toLocationName;
  final String issuedByName;
  final String issuedDate;
  final String note;

  PendingTransfer({
    required this.transferId,
    required this.itemName,
    required this.quantity,
    required this.fromLocationName,
    required this.toLocationName,
    required this.issuedByName,
    required this.issuedDate,
    required this.note,
  });
}

class TransferHistoryRow {
  final String itemName;
  final String quantity;
  final String fromLocationName;
  final String toLocationName;
  final String status;
  final String issuedByName;
  final String issuedDate;
  final String confirmedByName;
  final String confirmedDate;

  TransferHistoryRow({
    required this.itemName,
    required this.quantity,
    required this.fromLocationName,
    required this.toLocationName,
    required this.status,
    required this.issuedByName,
    required this.issuedDate,
    required this.confirmedByName,
    required this.confirmedDate,
  });
}

class StockTransfersPage {
  final List<PendingBatch> pendingBatches;
  final List<PendingTransfer> pending;
  final List<TransferHistoryRow> history;

  StockTransfersPage({
    required this.pendingBatches,
    required this.pending,
    required this.history,
  });
}

class ShipmentLine {
  final int itemId;
  final String itemName;
  final double quantity;

  ShipmentLine({required this.itemId, required this.itemName, required this.quantity});
}
