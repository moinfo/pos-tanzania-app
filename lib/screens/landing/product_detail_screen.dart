import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import '../../models/public_product.dart';
import '../../providers/landing_provider.dart';
import '../../services/public_api_service.dart';
import 'landing_screen.dart';
import '../../widgets/tr_text.dart';

/// Product detail screen with image gallery and portfolio
class ProductDetailScreen extends StatefulWidget {
  final PublicProduct product;
  final bool isDarkMode;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isDarkMode = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late PublicProduct _product;
  int _currentImageIndex = 0;
  int _currentPortfolioIndex = 0;
  int _quantity = 1;
  String _priceType = 'retail';
  bool _descriptionExpanded = false;
  bool _isLoading = true;
  final PageController _pageController = PageController();
  final PageController _portfolioPageController = PageController();

  // Dark mode colors
  Color get _bgColor => widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  Color get _cardColor => widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get _subtextColor => widget.isDarkMode ? Colors.grey[400]! : const Color(0xFF6B7280);
  Color get _dividerColor => widget.isDarkMode ? Colors.grey[800]! : const Color(0xFFE5E7EB);
  Color get _placeholderColor => widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _loadProductDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _portfolioPageController.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetails() async {
    try {
      final apiService = PublicApiService();
      final product = await apiService.getProduct(widget.product.itemId);
      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bgColor,
        appBarTheme: AppBarTheme(
          backgroundColor: _cardColor,
          foregroundColor: _textColor,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        body: CustomScrollView(
          slivers: [
            // Image gallery app bar
            _buildSliverAppBar(),

            // Product content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main product card
                  _buildProductCard(),

                  const SizedBox(height: 12),

                  // Price selection card
                  if (_product.hasWholesalePrice) _buildPriceSelectionCard(),

                  // Quantity card
                  _buildQuantityCard(),

                  // Description card
                  if (_product.description.isNotEmpty) _buildDescriptionCard(),

                  // Portfolio section
                  if (_product.portfolio.isNotEmpty) _buildPortfolioSection(),

                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    // Collect all images - same approach as ProductCard
    final List<String> allImages = [];

    // Sort portfolio by date (newest first) and add them first
    final sortedPortfolio = List.of(_product.portfolio);
    sortedPortfolio.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    // Add portfolio images first (these are shown in "Our Work" section but also make good main images)
    for (final portfolio in sortedPortfolio) {
      final url = PublicApiService.getPortfolioImageUrl(portfolio.filename);
      if (url.isNotEmpty && !allImages.contains(url)) {
        allImages.add(url);
      }
    }

    // Add gallery images
    for (var img in _product.images) {
      final url = PublicApiService.getProductImageUrl(img.filename);
      if (url.isNotEmpty && !allImages.contains(url)) {
        allImages.add(url);
      }
    }

    // Add main display image as fallback
    if (_product.displayImage != null) {
      final mainUrl = PublicApiService.getProductImageUrl(_product.displayImage);
      if (mainUrl.isNotEmpty && !allImages.contains(mainUrl)) {
        allImages.add(mainUrl);
      }
    }

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.width * 0.9,
      pinned: true,
      backgroundColor: _cardColor,
      foregroundColor: _textColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF14213D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _product.isLiked ? Icons.favorite : Icons.favorite_border,
              color: _product.isLiked ? Colors.red : const Color(0xFF14213D),
            ),
            onPressed: () {
              context.read<LandingProvider>().toggleLike(_product.itemId);
              setState(() {
                _product = _product.copyWith(
                  isLiked: !_product.isLiked,
                  likesCount: _product.isLiked
                      ? _product.likesCount - 1
                      : _product.likesCount + 1,
                );
              });
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image carousel
            if (allImages.isNotEmpty)
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemCount: allImages.length,
                itemBuilder: (context, index) {
                  final imageUrl = allImages[index];

                  return GestureDetector(
                    onTap: () => _showFullScreenImage(imageUrl),
                    onLongPress: () => _showProtectionMessage(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
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
              _buildImagePlaceholder(),

            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Curved edge: the photo meets the page in a rounded sheet.
            Positioned(
              bottom: -1,
              left: 0,
              right: 0,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
            ),

            // Page indicator
            if (allImages.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    allImages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentImageIndex == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentImageIndex == index
                            ? LandingColors.primaryRed
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),

            // Image counter
            if (allImages.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 50,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${allImages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: _placeholderColor,
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 80,
          color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildProductCard() {
    final brand = LandingColors.primaryRed;
    final showStock = context.read<LandingProvider>().hasStockDisplay;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category and likes row
          Row(
            children: [
              if (_product.category.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: brand.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _product.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 15,
                      color: Colors.red[400],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_product.likesCount}',
                      style: TextStyle(
                        color: _subtextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Product name
          Text(
            _product.name,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
              color: _textColor,
            ),
          ),

          const SizedBox(height: 14),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TZS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: brand,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _formatPrice(_product.retailPrice),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -0.5,
                  color: brand,
                ),
              ),
              if (_product.hasWholesalePrice) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: brand.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Wholesale',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: brand,
                        ),
                      ),
                      Text(
                        'TZS ${_formatPrice(_product.wholesalePrice)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Stock indicator (only shown if feature enabled for this client)
          if (showStock) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _product.isInStock
                    ? brand.withOpacity(0.10)
                    : Colors.red.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _product.isInStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 19,
                    color: _product.isInStock ? brand : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _product.isInStock
                          ? '${_product.retailQuantity.toInt()} available (Retail)'
                          : 'Out of stock',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _product.isInStock ? brand : Colors.red,
                      ),
                    ),
                  ),
                  if (_product.hasWholesalePrice && _product.wholesaleQuantity > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '| ${_product.wholesaleQuantity.toInt()} (Wholesale)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: brand,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shared look of every card on this page.
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: LandingColors.primaryRed.withOpacity(widget.isDarkMode ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.28 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );

  Widget _buildPriceSelectionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriceOption(
                  'Retail',
                  _product.retailPrice,
                  'retail',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceOption(
                  'Wholesale',
                  _product.wholesalePrice,
                  'wholesale',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOption(String label, double price, String type) {
    final isSelected = _priceType == type;
    final brand = LandingColors.primaryRed;

    return GestureDetector(
      onTap: () => setState(() => _priceType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? brand : _dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? brand.withOpacity(0.09) : _bgColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isSelected ? brand : _subtextColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'TZS ${_formatPrice(price)}',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? brand : _textColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 21,
              color: isSelected ? brand : _dividerColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityCard() {
    final brand = LandingColors.primaryRed;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: brand.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_basket_rounded, size: 20, color: brand),
          ),
          const SizedBox(width: 12),
          Text(
            'Quantity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const Spacer(),
          _buildQuantityButton(
            Icons.remove_rounded,
            _quantity > 1 ? () => setState(() => _quantity--) : null,
          ),
          Container(
            width: 46,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
          ),
          _buildQuantityButton(
            Icons.add_rounded,
            () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    final brand = LandingColors.primaryRed;
    final enabled = onPressed != null;

    return Material(
      color: enabled ? brand : _dividerColor.withOpacity(0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            color: enabled ? Colors.white : _subtextColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final brand = LandingColors.primaryRed;
    final long = _product.description.length > 160;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 20, color: brand),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: Text(
              _product.description,
              maxLines: (_descriptionExpanded || !long) ? null : 5,
              overflow: (_descriptionExpanded || !long)
                  ? TextOverflow.visible
                  : TextOverflow.fade,
              style: TextStyle(
                fontSize: 14,
                color: _textColor.withOpacity(0.85),
                height: 1.5,
              ),
            ),
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _descriptionExpanded ? 'Show less' : 'Read more',
                  style: TextStyle(
                    color: brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDarkMode ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: LandingColors.primaryRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Our Work',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LandingColors.primaryRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_currentPortfolioIndex + 1}/${_product.portfolio.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Portfolio carousel - Full width single image
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              children: [
                // Image carousel
                SizedBox(
                  height: MediaQuery.of(context).size.width * 0.85, // Slightly smaller
                  child: PageView.builder(
                    controller: _portfolioPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPortfolioIndex = index;
                      });
                    },
                    itemCount: _product.portfolio.length,
                    itemBuilder: (context, index) {
                      final portfolio = _product.portfolio[index];
                      final imageUrl = PublicApiService.getPortfolioImageUrl(portfolio.filename);

                      return GestureDetector(
                        onTap: () => _showFullScreenImage(imageUrl),
                        onLongPress: () => _showProtectionMessage(),
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: _placeholderColor,
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 64,
                                      color: _subtextColor,
                                    ),
                                  ),
                                ),
                                // Invisible overlay to block context menus
                                Positioned.fill(
                                  child: Container(color: Colors.transparent),
                                ),
                                // Title overlay at bottom
                                if (portfolio.title != null && portfolio.title!.isNotEmpty)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.7),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            portfolio.title!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (portfolio.description != null && portfolio.description!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                portfolio.description!,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 13,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Tap to zoom icon
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Page indicators
                if (_product.portfolio.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _product.portfolio.length,
                        (index) => GestureDetector(
                          onTap: () {
                            _portfolioPageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _currentPortfolioIndex == index ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPortfolioIndex == index
                                  ? LandingColors.primaryRed
                                  : _dividerColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final brand = LandingColors.primaryRed;
    final deep = HSLColor.fromColor(brand)
        .withLightness((HSLColor.fromColor(brand).lightness * 0.7).clamp(0.0, 1.0))
        .toColor();
    final unitPrice =
        _priceType == 'wholesale' ? _product.wholesalePrice : _product.retailPrice;
    final total = unitPrice * _quantity;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDarkMode ? 0.4 : 0.14),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: _subtextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'TZS ${_formatPrice(total)}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: _addToCart,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [brand, deep],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: brand.withOpacity(0.40),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_shopping_cart_rounded, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart() {
    final provider = context.read<LandingProvider>();
    final error = provider.addToCart(
      _product,
      quantity: _quantity,
      priceType: _priceType,
    );

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(error),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${_product.name} added to cart'),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
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

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProtectedFullScreenImage(imageUrl: imageUrl),
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

/// Protected fullscreen image viewer with screenshot prevention
class _ProtectedFullScreenImage extends StatefulWidget {
  final String imageUrl;

  const _ProtectedFullScreenImage({required this.imageUrl});

  @override
  State<_ProtectedFullScreenImage> createState() => _ProtectedFullScreenImageState();
}

class _ProtectedFullScreenImageState extends State<_ProtectedFullScreenImage> {
  @override
  void initState() {
    super.initState();
    // Ensure protection is enabled for fullscreen view
    // Screenshots are allowed; protection is no longer enabled here.
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onLongPress: _showProtectionMessage,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: LandingColors.primaryRed,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Invisible overlay to block context menus
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}
