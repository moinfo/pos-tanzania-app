/// Model for public orders placed from landing page
class PublicOrder {
  final int orderId;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double total;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final PublicCustomer customer;
  final List<PublicOrderItem> items;
  final int itemsCount;

  PublicOrder({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.total,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.customer,
    required this.items,
    required this.itemsCount,
  });

  factory PublicOrder.fromJson(Map<String, dynamic> json) {
    return PublicOrder(
      orderId: json['order_id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'pending',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      customer: PublicCustomer.fromJson(json['customer'] ?? {}),
      items: json['items'] != null
          ? (json['items'] as List).map((e) => PublicOrderItem.fromJson(e)).toList()
          : [],
      itemsCount: json['items_count'] ?? 0,
    );
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'ready':
        return 'Ready';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Get status color
  String get statusColor {
    switch (status) {
      case 'pending':
        return 'orange';
      case 'confirmed':
        return 'blue';
      case 'processing':
        return 'purple';
      case 'ready':
        return 'green';
      case 'delivered':
        return 'green';
      case 'cancelled':
        return 'red';
      default:
        return 'grey';
    }
  }
}

/// Order line item
class PublicOrderItem {
  final int orderItemId;
  final int itemId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final String priceType;
  final double subtotal;
  final String? notes;
  final String? image;

  PublicOrderItem({
    required this.orderItemId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.priceType,
    required this.subtotal,
    this.notes,
    this.image,
  });

  factory PublicOrderItem.fromJson(Map<String, dynamic> json) {
    return PublicOrderItem(
      orderItemId: json['order_item_id'] ?? 0,
      itemId: json['item_id'] ?? 0,
      itemName: json['item_name'] ?? '',
      quantity: (json['quantity'] ?? 1).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      priceType: json['price_type'] ?? 'retail',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      notes: json['notes'],
      image: json['image'],
    );
  }

  /// Check if wholesale price
  bool get isWholesale => priceType == 'wholesale';
}

/// Public customer (no login required)
class PublicCustomer {
  final int customerId;
  final String name;
  final String phone;
  final String? email;
  final String? address;

  PublicCustomer({
    required this.customerId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
  });

  factory PublicCustomer.fromJson(Map<String, dynamic> json) {
    return PublicCustomer(
      customerId: json['customer_id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }
}

/// Cart item for placing order
class CartItem {
  final int itemId;
  final String itemName;
  final String? image;
  final double retailPrice;
  final double wholesalePrice;
  int quantity;
  String priceType; // 'retail' or 'wholesale'
  String? notes;

  CartItem({
    required this.itemId,
    required this.itemName,
    this.image,
    required this.retailPrice,
    required this.wholesalePrice,
    this.quantity = 1,
    this.priceType = 'retail',
    this.notes,
  });

  /// Get current unit price based on price type
  double get unitPrice => priceType == 'wholesale' && wholesalePrice > 0
      ? wholesalePrice
      : retailPrice;

  /// Get subtotal
  double get subtotal => unitPrice * quantity;

  /// Check if wholesale is available
  bool get hasWholesale => wholesalePrice > 0;

  /// Convert to order item JSON
  Map<String, dynamic> toOrderJson() {
    return {
      'item_id': itemId,
      'quantity': quantity,
      'price_type': priceType,
      if (notes != null) 'notes': notes,
    };
  }

  /// Create from public product
  factory CartItem.fromProduct(dynamic product) {
    return CartItem(
      itemId: product.itemId,
      itemName: product.name,
      image: product.displayImage,
      retailPrice: product.retailPrice,
      wholesalePrice: product.wholesalePrice,
    );
  }
}
