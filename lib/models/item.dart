/// Gallery image for an item
class ItemGalleryImage {
  final int imageId;
  final String filename;
  final String url;
  final bool isPrimary;

  ItemGalleryImage({
    required this.imageId,
    required this.filename,
    required this.url,
    this.isPrimary = false,
  });

  factory ItemGalleryImage.fromJson(Map<String, dynamic> json) {
    return ItemGalleryImage(
      imageId: json['image_id'] ?? 0,
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
    );
  }
}

/// Portfolio/history image for an item
class ItemPortfolioImage {
  final int portfolioId;
  final String filename;
  final String url;
  final String? title;
  final String? description;

  ItemPortfolioImage({
    required this.portfolioId,
    required this.filename,
    required this.url,
    this.title,
    this.description,
  });

  factory ItemPortfolioImage.fromJson(Map<String, dynamic> json) {
    return ItemPortfolioImage(
      portfolioId: json['portfolio_id'] ?? 0,
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      title: json['title'],
      description: json['description'],
    );
  }
}

/// Location-specific pricing data for an item
class ItemLocationPrice {
  final double? costPrice;
  final double? unitPrice;
  final int? discountLimit;

  ItemLocationPrice({
    this.costPrice,
    this.unitPrice,
    this.discountLimit,
  });

  factory ItemLocationPrice.fromJson(Map<String, dynamic> json) {
    return ItemLocationPrice(
      costPrice: json['cost_price'] != null ? double.tryParse(json['cost_price'].toString()) : null,
      unitPrice: json['unit_price'] != null ? double.tryParse(json['unit_price'].toString()) : null,
      discountLimit: json['discount_limit'] != null ? int.tryParse(json['discount_limit'].toString()) : null,
    );
  }
}

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
  final String variation; // CTN, PC, BUNDLE
  final int? days; // Days since last sale
  final double? mainstore; // Quantity from mainstore (bonge database)
  final double quantity;
  final Map<int, double>? quantityByLocation; // Map of location_id to quantity
  final int deleted;
  final String? tax1Name;
  final double? tax1Percent;
  final String? tax2Name;
  final double? tax2Percent;
  final double wholesalePrice;
  final bool showOnLanding;

  // Location-specific pricing fields (Come & Save feature)
  final double? defaultCostPrice; // Item's default cost price (before location override)
  final double? defaultUnitPrice; // Item's default unit price (before location override)
  final int? defaultDiscountLimit; // Item's default discount limit (before location override)
  final Map<int, ItemLocationPrice>? locationPrices; // Map of location_id to pricing

  // Gallery and portfolio images
  final List<ItemGalleryImage> galleryImages;
  final List<ItemPortfolioImage> portfolioImages;

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
    required this.variation,
    this.days,
    this.mainstore,
    required this.quantity,
    this.quantityByLocation,
    this.deleted = 0,
    this.tax1Name,
    this.tax1Percent,
    this.tax2Name,
    this.tax2Percent,
    this.wholesalePrice = 0,
    this.showOnLanding = false,
    this.defaultCostPrice,
    this.defaultUnitPrice,
    this.defaultDiscountLimit,
    this.locationPrices,
    this.galleryImages = const [],
    this.portfolioImages = const [],
  });

  /// Check if this item has a location-specific price override for the current location
  bool get hasLocationPriceOverride {
    if (defaultUnitPrice == null) return false;
    return unitPrice != defaultUnitPrice;
  }

  /// Check if this item has a location-specific cost price override
  bool get hasLocationCostPriceOverride {
    if (defaultCostPrice == null) return false;
    return costPrice != defaultCostPrice;
  }

  /// Check if this item has a location-specific discount limit override
  bool get hasLocationDiscountLimitOverride {
    if (defaultDiscountLimit == null) return false;
    return discountLimit != defaultDiscountLimit;
  }

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

    // Parse location_prices if present (Come & Save feature)
    // Format: {"1": {"cost_price": "100.00", "unit_price": "150.00", "discount_limit": "10"}, ...}
    Map<int, ItemLocationPrice>? locationPrices;
    if (json['location_prices'] != null) {
      final rawLocPrices = json['location_prices'];
      if (rawLocPrices is Map) {
        final locPrices = rawLocPrices as Map<String, dynamic>;
        locationPrices = {};
        locPrices.forEach((key, value) {
          final locationId = int.tryParse(key.toString()) ?? 0;
          if (locationId > 0 && value is Map) {
            locationPrices![locationId] = ItemLocationPrice.fromJson(value as Map<String, dynamic>);
          }
        });
      }
    }

    // Helper to parse int from String or int (SQLite stores as String)
    int? parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }
    int parseIntOrZero(dynamic value) => parseIntOrNull(value) ?? 0;

    // Parse gallery images
    List<ItemGalleryImage> galleryImages = [];
    if (json['gallery_images'] != null && json['gallery_images'] is List) {
      galleryImages = (json['gallery_images'] as List)
          .map((img) => ItemGalleryImage.fromJson(img as Map<String, dynamic>))
          .toList();
    }

    // Parse portfolio images
    List<ItemPortfolioImage> portfolioImages = [];
    if (json['portfolio_images'] != null && json['portfolio_images'] is List) {
      portfolioImages = (json['portfolio_images'] as List)
          .map((img) => ItemPortfolioImage.fromJson(img as Map<String, dynamic>))
          .toList();
    }

    return Item(
      itemId: parseIntOrZero(json['item_id']),
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      supplierId: parseIntOrNull(json['supplier_id']),
      supplierName: json['supplier_name'],
      itemNumber: json['item_number'],
      description: json['description'] ?? '',
      costPrice: (json['cost_price'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      reorderLevel: (json['reorder_level'] ?? 0).toDouble(),
      receivingQuantity: (json['receiving_quantity'] ?? 1).toDouble(),
      picFilename: json['pic_filename'],
      allowAltDescription: json['allow_alt_description'] == 1 || json['allow_alt_description'] == true || json['allow_alt_description'] == '1',
      isSerialized: json['is_serialized'] == 1 || json['is_serialized'] == true || json['is_serialized'] == '1',
      stockType: parseIntOrZero(json['stock_type']),
      itemType: parseIntOrZero(json['item_type']),
      taxCategoryId: parseIntOrNull(json['tax_category_id']),
      qtyPerPack: (json['qty_per_pack'] ?? 1).toDouble(),
      packName: json['pack_name'] ?? 'Each',
      hsnCode: json['hsn_code'] ?? '',
      arrange: parseIntOrZero(json['arrange']),
      discountLimit: parseIntOrZero(json['discount_limit']),
      dormant: json['dormant'] ?? 'ACTIVE',
      child: json['child']?.toString(),
      variation: json['variation'] ?? 'CTN',
      days: parseIntOrNull(json['days']),
      mainstore: json['mainstore'] != null ? double.tryParse(json['mainstore'].toString()) : null,
      quantity: double.tryParse((json['quantity'] ?? 0).toString()) ?? 0,
      quantityByLocation: quantityByLocation,
      deleted: parseIntOrZero(json['deleted']),
      tax1Name: json['tax_1_name'],
      tax1Percent: json['tax_1_percent'] != null ? double.tryParse(json['tax_1_percent'].toString()) : null,
      tax2Name: json['tax_2_name'],
      tax2Percent: json['tax_2_percent'] != null ? double.tryParse(json['tax_2_percent'].toString()) : null,
      wholesalePrice: (json['wholesale_price'] ?? 0).toDouble(),
      showOnLanding: json['show_on_landing'] == 1 || json['show_on_landing'] == true || json['show_on_landing'] == '1',
      // Location-specific pricing fields (Come & Save feature)
      defaultCostPrice: json['default_cost_price'] != null ? double.tryParse(json['default_cost_price'].toString()) : null,
      defaultUnitPrice: json['default_unit_price'] != null ? double.tryParse(json['default_unit_price'].toString()) : null,
      defaultDiscountLimit: parseIntOrNull(json['default_discount_limit']),
      locationPrices: locationPrices,
      galleryImages: galleryImages,
      portfolioImages: portfolioImages,
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
      'wholesale_price': wholesalePrice,
      'reorder_level': reorderLevel,
      'receiving_quantity': receivingQuantity,
      'pic_filename': picFilename,
      'allow_alt_description': allowAltDescription,
      'is_serialized': isSerialized,
      'show_on_landing': showOnLanding,
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
      'variation': variation,
      'days': days,
      'mainstore': mainstore,
      'quantity': quantity,
    };
  }
}

/// Form data for location-specific pricing when editing items
class ItemLocationPriceFormData {
  final double? costPrice;
  final double? unitPrice;
  final int? discountLimit;

  ItemLocationPriceFormData({
    this.costPrice,
    this.unitPrice,
    this.discountLimit,
  });

  Map<String, dynamic> toJson() {
    return {
      if (costPrice != null) 'cost_price': costPrice,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (discountLimit != null) 'discount_limit': discountLimit,
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
  final double wholesalePrice;
  final double reorderLevel;
  final double receivingQuantity;
  final bool allowAltDescription;
  final bool isSerialized;
  final bool showOnLanding;
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

  // Location-specific pricing (Come & Save feature)
  final Map<int, ItemLocationPriceFormData>? locationPrices; // Location ID -> Pricing

  ItemFormData({
    required this.name,
    this.category = '',
    this.supplierId,
    this.itemNumber,
    this.description = '',
    this.costPrice = 0,
    this.unitPrice = 0,
    this.wholesalePrice = 0,
    this.reorderLevel = 0,
    this.receivingQuantity = 1,
    this.allowAltDescription = false,
    this.isSerialized = false,
    this.showOnLanding = false,
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
    this.locationPrices,
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
      'wholesale_price': wholesalePrice,
      'reorder_level': reorderLevel,
      'receiving_quantity': receivingQuantity,
      'allow_alt_description': allowAltDescription ? 1 : 0,
      'is_serialized': isSerialized ? 1 : 0,
      'show_on_landing': showOnLanding ? 1 : 0,
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

    // Add location-specific pricing if provided (Come & Save feature)
    if (locationPrices != null && locationPrices!.isNotEmpty) {
      final locationPricesJson = <String, dynamic>{};
      locationPrices!.forEach((locationId, pricing) {
        locationPricesJson[locationId.toString()] = pricing.toJson();
      });
      json['location_prices'] = locationPricesJson;
    }

    return json;
  }
}
