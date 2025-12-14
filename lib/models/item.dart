class Item {
  final int itemId;
  final String name;
  final String category;
  final int? supplierId;
  final String? supplierName;
  final String? itemNumber;
  final String description;
  final double costPrice;
  final double unitPrice;
  final double reorderLevel;
  final double receivingQuantity;
  final String? picFilename;
  final bool allowAltDescription;
  final bool isSerialized;
  final int stockType;
  final int itemType;
  final int? taxCategoryId;
  final double qtyPerPack;
  final String packName;
  final String hsnCode;
  final int arrange;
  final int discountLimit;
  final String dormant;
  final String? child;
  final double quantity;
  final Map<int, double>? quantityByLocation; // Map of location_id to quantity
  final int deleted;
  final String? tax1Name;
  final double? tax1Percent;
  final String? tax2Name;
  final double? tax2Percent;

  Item({
    required this.itemId,
    required this.name,
    required this.category,
    this.supplierId,
    this.supplierName,
    this.itemNumber,
    required this.description,
    required this.costPrice,
    required this.unitPrice,
    required this.reorderLevel,
    required this.receivingQuantity,
    this.picFilename,
    required this.allowAltDescription,
    required this.isSerialized,
    required this.stockType,
    required this.itemType,
    this.taxCategoryId,
    required this.qtyPerPack,
    required this.packName,
    required this.hsnCode,
    required this.arrange,
    required this.discountLimit,
    required this.dormant,
    this.child,
    required this.quantity,
    this.quantityByLocation,
    this.deleted = 0,
    this.tax1Name,
    this.tax1Percent,
    this.tax2Name,
    this.tax2Percent,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    // Parse quantity_by_location if present
    // Handle both Map and empty List (PHP quirk: empty array serializes as [])
    Map<int, double>? quantityByLocation;
    if (json['quantity_by_location'] != null) {
      final rawLocQty = json['quantity_by_location'];
      if (rawLocQty is Map) {
        final locQty = rawLocQty as Map<String, dynamic>;
        quantityByLocation = {};
        locQty.forEach((key, value) {
          final locationId = int.tryParse(key.toString()) ?? 0;
          if (locationId > 0) {
            quantityByLocation![locationId] = (value ?? 0).toDouble();
          }
        });
      }
      // If it's a List (empty array from PHP), just leave quantityByLocation as null
    }

    return Item(
      itemId: json['item_id'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'],
      itemNumber: json['item_number'],
      description: json['description'] ?? '',
      costPrice: (json['cost_price'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      reorderLevel: (json['reorder_level'] ?? 0).toDouble(),
      receivingQuantity: (json['receiving_quantity'] ?? 1).toDouble(),
      picFilename: json['pic_filename'],
      allowAltDescription: json['allow_alt_description'] == 1 || json['allow_alt_description'] == true,
      isSerialized: json['is_serialized'] == 1 || json['is_serialized'] == true,
      stockType: json['stock_type'] ?? 0,
      itemType: json['item_type'] ?? 0,
      taxCategoryId: json['tax_category_id'],
      qtyPerPack: (json['qty_per_pack'] ?? 1).toDouble(),
      packName: json['pack_name'] ?? 'Each',
      hsnCode: json['hsn_code'] ?? '',
      arrange: json['arrange'] ?? 0,
      discountLimit: json['discount_limit'] ?? 0,
      dormant: json['dormant'] ?? 'ACTIVE',
      child: json['child'],
      quantity: (json['quantity'] ?? 0).toDouble(),
      quantityByLocation: quantityByLocation,
      deleted: json['deleted'] ?? 0,
      tax1Name: json['tax_1_name'],
      tax1Percent: json['tax_1_percent'] != null ? (json['tax_1_percent']).toDouble() : null,
      tax2Name: json['tax_2_name'],
      tax2Percent: json['tax_2_percent'] != null ? (json['tax_2_percent']).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'name': name,
      'category': category,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'item_number': itemNumber,
      'description': description,
      'cost_price': costPrice,
      'unit_price': unitPrice,
      'reorder_level': reorderLevel,
      'receiving_quantity': receivingQuantity,
      'pic_filename': picFilename,
      'allow_alt_description': allowAltDescription,
      'is_serialized': isSerialized,
      'stock_type': stockType,
      'item_type': itemType,
      'tax_category_id': taxCategoryId,
      'qty_per_pack': qtyPerPack,
      'pack_name': packName,
      'hsn_code': hsnCode,
      'arrange': arrange,
      'discount_limit': discountLimit,
      'dormant': dormant,
      'child': child,
      'quantity': quantity,
    };
  }
}

class ItemFormData {
  final String name;
  final String category;
  final int? supplierId;
  final String? itemNumber;
  final String description;
  final double costPrice;
  final double unitPrice;
  final double reorderLevel;
  final double receivingQuantity;
  final bool allowAltDescription;
  final bool isSerialized;
  final int stockType;
  final int itemType;
  final int? taxCategoryId;
  final double qtyPerPack;
  final String packName;
  final int arrange;
  final int discountLimit;
  final String dormant;
  final String? child;
  final Map<int, double> quantityByLocation; // Location ID -> Quantity
  final String? tax1Name;
  final double? tax1Percent;
  final String? tax2Name;
  final double? tax2Percent;
  final String? attributeValue; // For Add Attribute field
  final int deleted;

  ItemFormData({
    required this.name,
    this.category = '',
    this.supplierId,
    this.itemNumber,
    this.description = '',
    this.costPrice = 0,
    this.unitPrice = 0,
    this.reorderLevel = 0,
    this.receivingQuantity = 1,
    this.allowAltDescription = false,
    this.isSerialized = false,
    this.stockType = 0,
    this.itemType = 0,
    this.taxCategoryId,
    this.qtyPerPack = 1,
    this.packName = 'Each',
    this.arrange = 0,
    this.discountLimit = 0,
    this.dormant = 'ACTIVE',
    this.child,
    this.quantityByLocation = const {},
    this.tax1Name,
    this.tax1Percent,
    this.tax2Name,
    this.tax2Percent,
    this.attributeValue,
    this.deleted = 0,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'name': name,
      'category': category,
      'supplier_id': supplierId,
      'item_number': itemNumber,
      'description': description,
      'cost_price': costPrice,
      'unit_price': unitPrice,
      'reorder_level': reorderLevel,
      'receiving_quantity': receivingQuantity,
      'allow_alt_description': allowAltDescription ? 1 : 0,
      'is_serialized': isSerialized ? 1 : 0,
      'stock_type': stockType,
      'item_type': itemType,
      'tax_category_id': taxCategoryId,
      'qty_per_pack': qtyPerPack,
      'pack_name': packName,
      'arrange': arrange,
      'discount_limit': discountLimit,
      'dormant': dormant,
      'child': child,
      'deleted': deleted,
    };

    // Add tax information if provided
    if (tax1Name != null) json['tax_1_name'] = tax1Name;
    if (tax1Percent != null) json['tax_1_percent'] = tax1Percent;
    if (tax2Name != null) json['tax_2_name'] = tax2Name;
    if (tax2Percent != null) json['tax_2_percent'] = tax2Percent;
    if (attributeValue != null) json['attribute_value'] = attributeValue;

    // Add quantities for each location
    quantityByLocation.forEach((locationId, quantity) {
      json['quantity_$locationId'] = quantity;
    });

    return json;
  }
}
