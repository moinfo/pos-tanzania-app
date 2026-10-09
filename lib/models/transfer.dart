// Transfer (/transfer) - CTN-to-PC same-location item conversion tool.
// Distinct from Stock Transfers (location-to-location) - see stock_transfer.dart.

class TransferInventoryInfo {
  final double currentStock;
  final double ctn; // units per carton
  final double costPrice;
  final int? childItemId;
  final String? childName;

  TransferInventoryInfo({
    required this.currentStock,
    required this.ctn,
    required this.costPrice,
    this.childItemId,
    this.childName,
  });

  factory TransferInventoryInfo.fromJson(Map<String, dynamic> json) {
    return TransferInventoryInfo(
      currentStock: _parseDouble(json['current_stock']),
      ctn: _parseDouble(json['ctn']),
      costPrice: _parseDouble(json['cost_price']),
      childItemId: json['child'] != null ? int.tryParse(json['child'].toString()) : null,
      childName: json['child_name']?.toString(),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class TransferHistoryRow {
  final String itemName;
  final double quantity;
  final double total;

  TransferHistoryRow({required this.itemName, required this.quantity, required this.total});
}
