import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/landing_provider.dart';
import '../../models/public_product.dart';
import '../../services/screen_protection_service.dart';
import '../login_screen.dart';
import 'widgets/product_card.dart';
import 'widgets/product_skeleton.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';

/// Brand colors from Come N' Save logo
class LandingColors {
  static const Color primaryRed = Color(0xFFE31E24);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF666666);
}

/// Main landing page with bottom navigation
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _currentIndex = 0;
  bool _isDarkMode = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Enable screenshot protection
    ScreenProtectionService().enableProtection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LandingProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF121212) : LandingColors.white;
    final cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : LandingColors.white;
    final textColor = _isDarkMode ? LandingColors.white : LandingColors.black;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: LandingColors.primaryRed,
        scaffoldBackgroundColor: bgColor,
        colorScheme: _isDarkMode
            ? ColorScheme.dark(
                primary: LandingColors.primaryRed,
                secondary: LandingColors.primaryRed,
                surface: cardColor,
              )
            : const ColorScheme.light(
                primary: LandingColors.primaryRed,
                secondary: LandingColors.black,
                surface: LandingColors.white,
              ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
        ),
        cardTheme: CardThemeData(color: cardColor),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          children: [
            _HomeTab(isDarkMode: _isDarkMode),
            CartScreen(
              isDarkMode: _isDarkMode,
              onNavigateToOrders: () {
                // Navigate to Orders tab (index 2)
                _pageController.jumpToPage(2);
                setState(() => _currentIndex = 2);
              },
            ),
            OrderHistoryScreen(isDarkMode: _isDarkMode),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final iconColor = _isDarkMode ? LandingColors.white : LandingColors.black;

    return AppBar(
      titleSpacing: 8,
      title: Row(
        children: [
          Image.asset(
            'assets/images/come_and_save_logo.png',
            height: 36,
            fit: BoxFit.contain,
          ),
          const Expanded(
            child: Center(
              child: Text(
                'COME N\' SAVE',
                style: TextStyle(
                  color: LandingColors.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
          height: 1,
        ),
      ),
      actions: [
        // Dark mode toggle
        IconButton(
          icon: Icon(
            _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: iconColor,
            size: 22,
          ),
          onPressed: () {
            setState(() => _isDarkMode = !_isDarkMode);
          },
        ),
        // Login button
        IconButton(
          icon: Icon(
            Icons.admin_panel_settings,
            color: iconColor,
            size: 22,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        final cartCount = provider.cart.length;

        return Container(
          color: _isDarkMode ? const Color(0xFF121212) : LandingColors.lightGrey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Container(
              height: 70,
                decoration: BoxDecoration(
                  gradient: _isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [Colors.white, Color(0xFFFAFAFA)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, 'Home'),
                      _buildNavItem(1, Icons.shopping_bag_rounded, 'Cart', badge: cartCount),
                      _buildNavItem(2, Icons.receipt_long_rounded, 'Orders'),
                    ],
                  ),
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badge = 0}) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: isSelected
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE31E24),
                    Color(0xFFFF4D4D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE31E24).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : (_isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    size: 24,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: -10,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Colors.white, Color(0xFFF0F0F0)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFE31E24), Color(0xFFFF4D4D)],
                              ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? Colors.black.withValues(alpha: 0.2)
                                : const Color(0xFFE31E24).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFE31E24) : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: SizedBox(width: isSelected ? 8 : 0),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.2, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: isSelected
                  ? Text(
                      label,
                      key: ValueKey('${label}_selected'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home tab with search and products feed
class _HomeTab extends StatefulWidget {
  final bool isDarkMode;

  const _HomeTab({required this.isDarkMode});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<LandingProvider>().loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bgColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : LandingColors.lightGrey;

    return RefreshIndicator(
      color: LandingColors.primaryRed,
      onRefresh: () => context.read<LandingProvider>().initialize(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Offline/cache indicator banner
          SliverToBoxAdapter(
            child: Consumer<LandingProvider>(
              builder: (context, provider, _) {
                if (!provider.isFromCache) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange[700],
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Showing cached data. Pull to refresh.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => provider.initialize(),
                        child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Search bar with sort options
          SliverToBoxAdapter(
            child: Consumer<LandingProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
                  child: Row(
                    children: [
                      // Search field
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              color: widget.isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(
                                color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: widget.isDarkMode ? Colors.grey[400] : LandingColors.darkGrey,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: widget.isDarkMode ? Colors.grey[400] : LandingColors.darkGrey,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        context.read<LandingProvider>().searchProducts('');
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: bgColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            ),
                            onSubmitted: (value) {
                              context.read<LandingProvider>().searchProducts(value);
                            },
                            onChanged: (value) {
                              setState(() {});
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (_searchController.text == value) {
                                  context.read<LandingProvider>().searchProducts(value);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Products count
                      Text(
                        '${provider.totalProducts}',
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.grey[400] : LandingColors.darkGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sort dropdown
                      PopupMenuButton<String>(
                        initialValue: provider.sortBy,
                        onSelected: (value) => provider.changeSortOrder(value),
                        padding: EdgeInsets.zero,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'latest', child: Text('Latest')),
                          const PopupMenuItem(value: 'popular', child: Text('Most Popular')),
                          const PopupMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                          const PopupMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                          const PopupMenuItem(value: 'name', child: Text('Name')),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getSortLabel(provider.sortBy),
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.grey[300] : LandingColors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: widget.isDarkMode ? Colors.grey[300] : LandingColors.black,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Products grid
          _buildProductsGrid(),
          // Loading indicator
          _buildLoadingIndicator(),
        ],
      ),
    );
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'latest': return 'Latest';
      case 'popular': return 'Popular';
      case 'price_low': return 'Price ↑';
      case 'price_high': return 'Price ↓';
      case 'name': return 'Name';
      default: return 'Latest';
    }
  }

  Widget _buildProductsGrid() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        // Show skeleton loading while loading products
        if (provider.isLoadingProducts && provider.products.isEmpty) {
          return SliverToBoxAdapter(
            child: ProductSkeletonList(
              count: 3,
              isDarkMode: widget.isDarkMode,
            ),
          );
        }

        if (provider.products.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage.isNotEmpty
                        ? provider.errorMessage
                        : (_searchController.text.isNotEmpty ? 'No results found' : 'No products found'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (provider.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.initialize(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LandingColors.primaryRed,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else if (_searchController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        context.read<LandingProvider>().searchProducts('');
                        setState(() {});
                      },
                      child: const Text('Clear search'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Show cache indicator if data is from cache
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = provider.products[index];
              return ProductCard(
                product: product,
                isDarkMode: widget.isDarkMode,
                showStockIndicator: provider.hasStockDisplay,
                onTap: () => _openProductDetail(context, product),
                onLike: () => provider.toggleLike(product.itemId),
                onAddToCart: () => _quickAddToCart(context, provider, product),
              );
            },
            childCount: provider.products.length,
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        if (!provider.isLoadingProducts || provider.products.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: LandingColors.primaryRed)),
          ),
        );
      },
    );
  }

  void _openProductDetail(BuildContext context, PublicProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _quickAddToCart(BuildContext context, LandingProvider provider, PublicProduct product) {
    final error = provider.addToCart(product, quantity: 1, priceType: 'retail');
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
