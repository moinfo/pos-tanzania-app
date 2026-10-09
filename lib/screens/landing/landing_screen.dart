import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import '../../providers/landing_provider.dart';
import '../../models/public_product.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'widgets/product_card.dart';
import 'widgets/product_grid_card.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'widgets/product_skeleton.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/language_switcher.dart';
import '../../l10n/lang.dart';

/// Brand colors - adapts to current client
class LandingColors {
  static Color get primaryRed {
    final branding = ApiService.currentClient?.branding;
    if (branding != null && branding.primaryColor != 0xFF1565C0) {
      return Color(branding.primaryColor);
    }
    return const Color(0xFFE31E24); // Default: Come N' Save red
  }
  static Color get primaryLight {
    final branding = ApiService.currentClient?.branding;
    if (branding != null && branding.primaryColor != 0xFF1565C0) {
      return Color(branding.primaryColor).withOpacity(0.8);
    }
    return const Color(0xFFFF4D4D); // Default: lighter red
  }
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
  // Tabs run Cart | Home | Orders, with Home in the middle and open first.
  int _currentIndex = 1;
  bool _isDarkMode = false;
  final PageController _pageController = PageController(initialPage: 1);

  @override
  void initState() {
    super.initState();
    // Screenshots are allowed; protection is no longer enabled here.
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
            : ColorScheme.light(
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
            CartScreen(
              isDarkMode: _isDarkMode,
              onNavigateToOrders: () {
                // Navigate to Orders tab (index 2)
                _pageController.jumpToPage(2);
                setState(() => _currentIndex = 2);
              },
            ),
            _HomeTab(isDarkMode: _isDarkMode),
            OrderHistoryScreen(isDarkMode: _isDarkMode),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // The bar carries the client's brand colour (Kariakoo: logo green), with
    // white text and icons on it.
    final brand = LandingColors.primaryRed;
    const iconColor = Colors.white;

    final client = ApiService.currentClient;
    final logoPath = client?.logoUrl ?? 'assets/images/come_and_save_logo.png';
    final title = client?.branding.appTitle ?? 'COME N\' SAVE';

    return AppBar(
      backgroundColor: brand,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleSpacing: 10,
      title: Row(
        children: [
          // White ring so the green logo tile stands out on the green bar.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                logoPath,
                height: 34,
                width: 34,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        // English / Kiswahili
        Center(
          child: LanguageChip(
            surface: Colors.white.withValues(alpha: 0.16),
            border: Colors.white.withValues(alpha: 0.55),
            ink: Colors.white,
            accent: Colors.white,
            activeInk: brand,
          ),
        ),
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
          tooltip: 'Login'.tr,
          icon: Icon(
            Icons.login_rounded,
            color: iconColor,
            size: 24,
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
            // Lift the pill above the system navigation buttons / gesture
            // bar; edge-to-edge Android otherwise draws them over it.
            padding: EdgeInsets.fromLTRB(
                16, 6, 16, 10 + MediaQuery.of(context).viewPadding.bottom),
            child: Container(
              height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LandingColors.primaryRed,
                      HSLColor.fromColor(LandingColors.primaryRed)
                          .withLightness((HSLColor.fromColor(LandingColors.primaryRed).lightness * 0.68)
                              .clamp(0.0, 1.0))
                          .toColor(),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: LandingColors.primaryRed.withValues(alpha: _isDarkMode ? 0.30 : 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.shopping_bag_rounded, 'Cart', badge: cartCount),
                      _buildNavItem(1, Icons.home_rounded, 'Home'),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
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
                        ? LandingColors.primaryRed
                        : Colors.white.withValues(alpha: 0.82),
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
                        color: isSelected ? LandingColors.primaryRed : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: TextStyle(
                          color: isSelected ? Colors.white : LandingColors.primaryRed,
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
                      style: TextStyle(
                        color: LandingColors.primaryRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
          // Branded hero with the search pill
          SliverToBoxAdapter(child: _buildHero()),
          // Category chips
          SliverToBoxAdapter(child: _buildCategoryChips()),
          // Result count + sort
          SliverToBoxAdapter(child: _buildResultsBar()),
          // Products grid
          _buildProductsGrid(),
          // Loading indicator
          _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final brand = LandingColors.primaryRed;
    final deep = HSLColor.fromColor(brand)
        .withLightness((HSLColor.fromColor(brand).lightness * 0.62).clamp(0.0, 1.0))
        .toColor();
    final dark = widget.isDarkMode;
    final client = ApiService.currentClient;
    final tagline = client?.branding.tagline ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, deep],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: dark ? 0.25 : 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative discs.
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                client?.branding.appTitle ?? client?.displayName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Search pill
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search...'.tr,
                    hintStyle: TextStyle(
                      color: dark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: brand, size: 24),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: dark ? Colors.grey[400] : LandingColors.darkGrey,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              context.read<LandingProvider>().searchProducts('');
                              setState(() {});
                            },
                          )
                        : null,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final brand = LandingColors.primaryRed;
    final dark = widget.isDarkMode;

    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories.where((c) => c.name.isNotEmpty).toList();
        if (categories.isEmpty) return const SizedBox(height: 6);

        Widget chip(String label, bool selected, VoidCallback onTap) {
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? brand
                    : (dark ? const Color(0xFF1E1E1E) : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? brand : (dark ? Colors.white24 : const Color(0xFFE2E6EA)),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: brand.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : (dark ? Colors.grey[300] : const Color(0xFF3B4756)),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
            children: [
              chip('All', provider.selectedCategory == null,
                  () => provider.filterByCategory(null)),
              for (final c in categories)
                chip(c.name, provider.selectedCategory == c.name,
                    () => provider.filterByCategory(c.name)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsBar() {
    final dark = widget.isDarkMode;
    final brand = LandingColors.primaryRed;

    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${provider.totalProducts} products',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.grey[300] : const Color(0xFF3B4756),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                initialValue: provider.sortBy,
                onSelected: (value) => provider.changeSortOrder(value),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'latest', child: Text('Latest')),
                  PopupMenuItem(value: 'popular', child: Text('Most Popular')),
                  PopupMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                  PopupMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                  PopupMenuItem(value: 'name', child: Text('Name')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: dark ? 0.2 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: brand),
                      const SizedBox(width: 6),
                      Text(
                        _getSortLabel(provider.sortBy),
                        style: TextStyle(
                          color: brand,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = provider.products[index];
                return ProductGridCard(
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
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
