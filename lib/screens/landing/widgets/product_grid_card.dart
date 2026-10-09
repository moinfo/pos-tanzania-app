import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;

import '../../../models/public_product.dart';
import '../../../services/public_api_service.dart';
import '../../../widgets/tr_text.dart';
import '../landing_screen.dart';

/// Shop-window product tile for the landing grid: square photo, rounded card,
/// price in the brand colour, a heart, a "New" / "Out of stock" tag and a round
/// add-to-cart button. Tapping the card opens the full product page.
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLike,
    required this.onAddToCart,
    this.isDarkMode = false,
    this.showStockIndicator = false,
    this.currencySymbol = 'TZS',
  });

  final PublicProduct product;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onAddToCart;
  final bool isDarkMode;
  final bool showStockIndicator;
  final String currencySymbol;

  /// Newest portfolio photo first (that is what the full card shows), then the
  /// main product image.
  String? get _imageUrl {
    final portfolio = List.of(product.portfolio)
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
    for (final p in portfolio) {
      final url = PublicApiService.getPortfolioImageUrl(p.filename);
      if (url.isNotEmpty) return url;
    }
    final main = PublicApiService.getProductImageUrl(product.displayImage);
    return main.isNotEmpty ? main : null;
  }

  bool get _isNew {
    final at = product.latestMediaAt;
    return at != null && DateTime.now().difference(at).inDays <= 7;
  }

  bool get _outOfStock => showStockIndicator && !product.isInStock;

  String _price(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final brand = LandingColors.primaryRed;
    final surface = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDarkMode ? Colors.white : const Color(0xFF14213D);
    final muted = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final placeholder = isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F5);
    final url = _imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          // Brand-green outline (the client's logo colour).
          border: Border.all(color: brand, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url == null
                      ? _placeholder(placeholder, muted)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: placeholder,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: brand),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _placeholder(placeholder, muted),
                        ),
                  // Soft fade so the tags stay legible on bright photos.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isNew && !_outOfStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _tag('New', brand, Colors.white),
                    ),
                  if (_outOfStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _tag('Out of stock', const Color(0xFFD93A3A), Colors.white),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: onLike,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          product.isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: product.isLiked ? const Color(0xFFE53935) : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  if (_outOfStock)
                    Positioned.fill(
                      child: ColoredBox(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.category.isNotEmpty)
                      Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: brand,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: ink,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$currencySymbol ${_price(product.retailPrice)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                              if (product.hasWholesalePrice)
                                Text(
                                  'Wholesale: $currencySymbol ${_price(product.wholesalePrice)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10.5, color: muted),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: brand,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: brand.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.2,
          ),
        ),
      );

  Widget _placeholder(Color bg, Color fg) => Container(
        color: bg,
        child: Center(
          child: Icon(Icons.image_outlined, size: 40, color: fg.withValues(alpha: 0.6)),
        ),
      );
}
