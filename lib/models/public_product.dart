/// Model for public-facing products on landing page
class PublicProduct {
  final int itemId;
  final String name;
  final String category;
  final String description;
  final double retailPrice;
  final double wholesalePrice;
  final String? image;
  final String? defaultImage;
  final int likesCount;
  final bool isLiked;
  final List<ProductImage> images;
  final List<PortfolioImage> portfolio;
  final DateTime? latestMediaAt;
  final double retailQuantity;   // Stock at location 2
  final double wholesaleQuantity; // Stock at location 3

  PublicProduct({
    required this.itemId,
    required this.name,
    required this.category,
    required this.description,
    required this.retailPrice,
    required this.wholesalePrice,
    this.image,
    this.defaultImage,
    required this.likesCount,
    required this.isLiked,
    this.images = const [],
    this.portfolio = const [],
    this.latestMediaAt,
    this.retailQuantity = 0,
    this.wholesaleQuantity = 0,
  });

  factory PublicProduct.fromJson(Map<String, dynamic> json) {
    DateTime? latestMedia;
    if (json['latest_media_at'] != null) {
      latestMedia = DateTime.tryParse(json['latest_media_at']);
    }

    return PublicProduct(
      itemId: json['item_id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      retailPrice: (json['retail_price'] ?? 0).toDouble(),
      wholesalePrice: (json['wholesale_price'] ?? 0).toDouble(),
      image: json['display_image'] ?? json['image'],
      defaultImage: json['default_image'],
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      images: json['images'] != null
          ? (json['images'] as List).map((e) => ProductImage.fromJson(e)).toList()
          : [],
      portfolio: json['portfolio'] != null
          ? (json['portfolio'] as List).map((e) => PortfolioImage.fromJson(e)).toList()
          : [],
      latestMediaAt: latestMedia,
      retailQuantity: (json['retail_quantity'] ?? 0).toDouble(),
      wholesaleQuantity: (json['wholesale_quantity'] ?? 0).toDouble(),
    );
  }

  /// Get the best available image URL
  String? get displayImage => image ?? defaultImage;

  /// Check if product has wholesale price
  bool get hasWholesalePrice => wholesalePrice > 0;

  /// Get stock quantity for a price type
  double getStock(String priceType) {
    return priceType == 'wholesale' ? wholesaleQuantity : retailQuantity;
  }

  /// Check if product is in stock for retail
  bool get isInStock => retailQuantity > 0;

  /// Check if product is in stock for wholesale
  bool get isInStockWholesale => wholesaleQuantity > 0;

  /// Get "time ago" string for latest media
  String get timeAgo {
    if (latestMediaAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(latestMediaAt!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Copy with updated like status
  PublicProduct copyWith({
    int? likesCount,
    bool? isLiked,
  }) {
    return PublicProduct(
      itemId: itemId,
      name: name,
      category: category,
      description: description,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
      image: image,
      defaultImage: defaultImage,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      images: images,
      portfolio: portfolio,
      latestMediaAt: latestMediaAt,
      retailQuantity: retailQuantity,
      wholesaleQuantity: wholesaleQuantity,
    );
  }
}

/// Product gallery image
class ProductImage {
  final int imageId;
  final String filename;
  final int sortOrder;
  final bool isPrimary;

  ProductImage({
    required this.imageId,
    required this.filename,
    required this.sortOrder,
    required this.isPrimary,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      imageId: json['image_id'] ?? 0,
      filename: json['filename'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

/// Portfolio/history image showing past work
class PortfolioImage {
  final int portfolioId;
  final String filename;
  final String? title;
  final String? description;
  final int sortOrder;
  final String? createdAt;

  PortfolioImage({
    required this.portfolioId,
    required this.filename,
    this.title,
    this.description,
    required this.sortOrder,
    this.createdAt,
  });

  factory PortfolioImage.fromJson(Map<String, dynamic> json) {
    return PortfolioImage(
      portfolioId: json['portfolio_id'] ?? 0,
      filename: json['image_filename'] ?? json['filename'] ?? '',
      title: json['title'],
      description: json['description'],
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'],
    );
  }
}

/// Product category with count
class ProductCategory {
  final String name;
  final int productCount;

  ProductCategory({
    required this.name,
    required this.productCount,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      name: json['name'] ?? '',
      productCount: json['product_count'] ?? 0,
    );
  }
}

/// Business information for landing page
class BusinessInfo {
  final String businessName;
  final String? tagline;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final double? locationLat;
  final double? locationLng;
  final String? logoFilename;
  final String? bannerFilename;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? twitterUrl;
  final String? workingHours;

  BusinessInfo({
    required this.businessName,
    this.tagline,
    this.description,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.locationLat,
    this.locationLng,
    this.logoFilename,
    this.bannerFilename,
    this.facebookUrl,
    this.instagramUrl,
    this.twitterUrl,
    this.workingHours,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      businessName: json['business_name'] ?? 'Gift Shop',
      tagline: json['tagline'],
      description: json['description'],
      phone: json['phone'],
      whatsapp: json['whatsapp'],
      email: json['email'],
      address: json['address'],
      locationLat: json['location_lat'] != null ? double.tryParse(json['location_lat'].toString()) : null,
      locationLng: json['location_lng'] != null ? double.tryParse(json['location_lng'].toString()) : null,
      logoFilename: json['logo_filename'],
      bannerFilename: json['banner_filename'],
      facebookUrl: json['facebook_url'],
      instagramUrl: json['instagram_url'],
      twitterUrl: json['twitter_url'],
      workingHours: json['working_hours'],
    );
  }

  /// Check if WhatsApp is available
  bool get hasWhatsapp => whatsapp != null && whatsapp!.isNotEmpty;

  /// Check if phone is available
  bool get hasPhone => phone != null && phone!.isNotEmpty;
}
