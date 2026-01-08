import 'package:flutter/material.dart';
import '../../../models/public_product.dart';
import '../../../services/public_api_service.dart';
import '../landing_screen.dart';

/// Instagram-style product card - full width, single column
class ProductCard extends StatelessWidget {
  final PublicProduct product;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onAddToCart;
  final String currencySymbol;
  final bool isDarkMode;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLike,
    required this.onAddToCart,
    this.currencySymbol = 'TZS',
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];
    final placeholderColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      elevation: 0,
      color: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Category icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LandingColors.primaryRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 18,
                      color: LandingColors.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Category name
                  Expanded(
                    child: Text(
                      product.category.isNotEmpty ? product.category : 'Product',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Wholesale badge
                  if (product.hasWholesalePrice)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Wholesale',
                        style: TextStyle(
                          color: Colors.green[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Image - Full width, square aspect ratio
            AspectRatio(
              aspectRatio: 1,
              child: _buildImage(placeholderColor),
            ),

            // Actions row (like, add to cart)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Like button
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        product.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: product.isLiked ? Colors.red : subtextColor,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Add to cart button
                  InkWell(
                    onTap: onAddToCart,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.add_shopping_cart_outlined,
                        color: subtextColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Price
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: LandingColors.primaryRed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$currencySymbol ${_formatPrice(product.retailPrice)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Likes count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${product.likesCount} likes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ),

            // Product name and description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    if (product.description.isNotEmpty) ...[
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: product.description.length > 80
                            ? '${product.description.substring(0, 80)}...'
                            : product.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Wholesale price if available
            if (product.hasWholesalePrice)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Text(
                  'Wholesale: $currencySymbol ${_formatPrice(product.wholesalePrice)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),

            // Divider
            Divider(height: 1, color: dividerColor),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Color? placeholderColor) {
    final imageUrl = product.displayImage != null
        ? PublicApiService.getProductImageUrl(product.displayImage)
        : null;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(placeholderColor),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: placeholderColor,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: LandingColors.primaryRed,
              ),
            ),
          );
        },
      );
    }

    return _buildPlaceholder(placeholderColor);
  }

  Widget _buildPlaceholder(Color? placeholderColor) {
    return Container(
      color: placeholderColor,
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 64,
          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}
