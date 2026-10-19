/// Staff-side view of an order placed on the public shop (ospos_public_orders),
/// as returned by `GET /api/orders`. Mirrors the web module at /online_orders.
class OnlineOrder {
  final int orderId;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double total;
  final String? notes;
  final String createdAt;
  final int? saleId;
  final String? deliveredAt;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final List<OnlineOrderItem> items;

  OnlineOrder({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.total,
    this.notes,
    required this.createdAt,
    this.saleId,
    this.deliveredAt,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    required this.items,
  });

  /// The statuses, in the order the web module lists them.
  static const List<String> statuses = [
    'pending',
    'confirmed',
    'processing',
    'ready',
    'delivered',
    'cancelled',
  ];

  factory OnlineOrder.fromJson(Map<String, dynamic> json) {
    final customer = (json['customer'] as Map?)?.cast<String, dynamic>() ?? {};
    return OnlineOrder(
      orderId: _int(json['order_id']),
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      subtotal: _double(json['subtotal']),
      total: _double(json['total']),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      saleId: json['sale_id'] == null ? null : _int(json['sale_id']),
      deliveredAt: json['delivered_at']?.toString(),
      customerName: customer['name']?.toString() ?? '',
      customerPhone: customer['phone']?.toString() ?? '',
      customerEmail: customer['email']?.toString(),
      customerAddress: customer['address']?.toString(),
      items: (json['items'] as List? ?? [])
          .map((e) => OnlineOrderItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Delivered orders are recorded as a POS sale and locked.
  bool get isLocked => saleId != null;

  /// "Item A, Item B" -- the Item column of the web list.
  String get itemNames => items.map((i) => i.itemName).join(', ');

  /// "1, 2" -- the Quantity column of the web list.
  String get quantities => items.map((i) => i.quantityText).join(', ');

  static int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
  static double _double(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

class OnlineOrderItem {
  final int itemId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final String priceType;
  final double subtotal;

  OnlineOrderItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.priceType,
    required this.subtotal,
  });

  factory OnlineOrderItem.fromJson(Map<String, dynamic> json) => OnlineOrderItem(
        itemId: OnlineOrder._int(json['item_id']),
        itemName: json['item_name']?.toString() ?? '',
        quantity: OnlineOrder._double(json['quantity']),
        unitPrice: OnlineOrder._double(json['unit_price']),
        priceType: json['price_type']?.toString() ?? 'retail',
        subtotal: OnlineOrder._double(json['subtotal']),
      );

  bool get isWholesale => priceType == 'wholesale';

  String get quantityText =>
      quantity % 1 == 0 ? quantity.toStringAsFixed(0) : quantity.toString();
}

/// One response of the list endpoint: the orders for a date range, the count
/// per status for that same range, and what this user may do.
class OnlineOrdersPage {
  final List<OnlineOrder> orders;
  final Map<String, int> counts;
  final String startDate;
  final String endDate;
  final bool canView;
  final bool canEdit;
  final bool canDelete;

  OnlineOrdersPage({
    required this.orders,
    required this.counts,
    required this.startDate,
    required this.endDate,
    required this.canView,
    required this.canEdit,
    required this.canDelete,
  });

  factory OnlineOrdersPage.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    (json['counts'] as Map? ?? {}).forEach((k, v) {
      counts['$k'] = int.tryParse('$v') ?? 0;
    });
    final perms = (json['permissions'] as Map?) ?? {};
    return OnlineOrdersPage(
      orders: (json['orders'] as List? ?? [])
          .map((e) => OnlineOrder.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      counts: counts,
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      canView: perms['view'] == true,
      canEdit: perms['edit'] == true,
      canDelete: perms['delete'] == true,
    );
  }

  int get total => counts.values.fold(0, (a, b) => a + b);
}
