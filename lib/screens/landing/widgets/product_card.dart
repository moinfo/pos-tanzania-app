import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/public_product.dart';
import '../../../services/public_api_service.dart';
import '../landing_screen.dart';

/// Instagram-style product card - full width with swipeable images
class ProductCard extends StatefulWidget {
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
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Get all available images (portfolio first, sorted by latest, then main image)
  List<String> get _allImages {
    final images = <String>[];

    // Sort portfolio by date (newest first) and add them first
    final sortedPortfolio = List.of(widget.product.portfolio);
    sortedPortfolio.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!); // Newest first
    });

    // Add portfolio images first (latest on front)
    for (final portfolio in sortedPortfolio) {
      final url = PublicApiService.getPortfolioImageUrl(portfolio.filename);
      if (url.isNotEmpty && !images.contains(url)) {
        images.add(url);
      }
    }

    // Add main display image at the end (fallback if no portfolio)
    if (widget.product.displayImage != null) {
      final mainUrl = PublicApiService.getProductImageUrl(widget.product.displayImage);
      if (mainUrl.isNotEmpty && !images.contains(mainUrl)) {
        images.add(mainUrl);
      }
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subtextColor = widget.isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final bgColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor = widget.isDarkMode ? Colors.grey[800] : Colors.grey[200];
    final placeholderColor = widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100];

    final images = _allImages;
    final hasMultipleImages = images.length > 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      elevation: 0,
      color: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with category - tappable
          InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LandingColors.primaryRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 18,
                      color: LandingColors.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.product.category.isNotEmpty ? widget.product.category : 'Product',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        if (widget.product.timeAgo.isNotEmpty)
                          Text(
                            widget.product.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.product.hasWholesalePrice)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
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
          ),

          // Product Images - Swipeable (separate from InkWell to allow swipe)
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                // Image PageView - swipeable
                if (images.isNotEmpty)
                  PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: widget.onTap,
                        // Intercept long press to prevent image saving
                        onLongPress: () => _showProtectionMessage(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: placeholderColor,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: LandingColors.primaryRed,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(placeholderColor),
                            ),
                            // Invisible overlay to block context menus
                            Positioned.fill(
                              child: Container(color: Colors.transparent),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  GestureDetector(
                    onTap: widget.onTap,
                    child: _buildPlaceholder(placeholderColor),
                  ),

                // Multi-image indicator icon (top right)
                if (hasMultipleImages)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentImageIndex + 1}/${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Page indicators (bottom center)
                if (hasMultipleImages)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => Container(
                          width: index == _currentImageIndex ? 8 : 6,
                          height: index == _currentImageIndex ? 8 : 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentImageIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Actions row (like, add to cart)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: widget.onLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      widget.product.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: widget.product.isLiked ? Colors.red : subtextColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: widget.onAddToCart,
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
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _openWhatsApp(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366), // WhatsApp green
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: LandingColors.primaryRed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${widget.currencySymbol} ${_formatPrice(widget.product.retailPrice)}',
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

          // Likes count & Product info - tappable
          InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${widget.product.likesCount} likes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: widget.product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        if (widget.product.description.isNotEmpty) ...[
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: widget.product.description.length > 80
                                ? '${widget.product.description.substring(0, 80)}...'
                                : widget.product.description,
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
                if (widget.product.hasWholesalePrice)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: Text(
                      'Wholesale: ${widget.currencySymbol} ${_formatPrice(widget.product.wholesalePrice)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }

  /// Open WhatsApp with pre-filled message about this product
  Future<void> _openWhatsApp() async {
    const whatsappNumber = '255652894205'; // Tanzania format without leading 0
    final product = widget.product;
    final price = _formatPrice(product.retailPrice);

    // Build detailed message
    final buffer = StringBuffer();
    buffer.writeln('Hi! I\'m interested in:');
    buffer.writeln('');
    buffer.writeln('*${product.name}*');
    if (product.category.isNotEmpty) {
      buffer.writeln('Category: ${product.category}');
    }
    buffer.writeln('Price: TZS $price');
    if (product.hasWholesalePrice) {
      buffer.writeln('Wholesale: TZS ${_formatPrice(product.wholesalePrice)}');
    }
    if (product.description.isNotEmpty) {
      final desc = product.description.length > 100
          ? '${product.description.substring(0, 100)}...'
          : product.description;
      buffer.writeln('');
      buffer.writeln(desc);
    }
    buffer.writeln('');
    buffer.writeln('Can you tell me more about this product?');

    final message = Uri.encodeComponent(buffer.toString());
    final whatsappUrl = Uri.parse('https://wa.me/$whatsappNumber?text=$message');

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  /// Show message when user tries to long-press save image
  void _showProtectionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.shield, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Images are protected'),
          ],
        ),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPlaceholder(Color? placeholderColor) {
    return Container(
      color: placeholderColor,
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 64,
          color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
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
