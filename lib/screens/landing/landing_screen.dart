import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/landing_provider.dart';
import '../../models/public_product.dart';
import 'widgets/product_card.dart';
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

/// Main landing page with Instagram-style product grid
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LandingProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<LandingProvider>().loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors based on dark mode
    final bgColor = _isDarkMode ? const Color(0xFF121212) : LandingColors.white;
    final textColor = _isDarkMode ? LandingColors.white : LandingColors.black;
    final cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : LandingColors.white;

    // Apply landing page theme with brand colors
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
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: LandingColors.primaryRed,
          foregroundColor: LandingColors.white,
        ),
        cardTheme: CardThemeData(
          color: cardColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(),
        body: RefreshIndicator(
          color: LandingColors.primaryRed,
          onRefresh: () => context.read<LandingProvider>().initialize(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Search bar (when expanded)
              if (_showSearch) _buildSearchBar(),

              // Sort options
              _buildSortOptions(),

              // Products grid
              _buildProductsGrid(),

              // Loading indicator
              _buildLoadingIndicator(),
            ],
          ),
        ),
        floatingActionButton: _buildCartFAB(),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: LandingColors.white,
        child: Image.asset(
          'assets/images/come_and_save_logo.png',
          height: 80,
          fit: BoxFit.contain,
        ),
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
            height: 40,
            fit: BoxFit.contain,
          ),
          const Expanded(
            child: Center(
              child: Text(
                'COME N\' SAVE',
                style: TextStyle(
                  color: LandingColors.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
        // Search toggle
        IconButton(
          icon: Icon(Icons.search, color: iconColor),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                context.read<LandingProvider>().searchProducts('');
              }
            });
          },
        ),
        // Order history
        IconButton(
          icon: Icon(Icons.receipt_long_outlined, color: iconColor),
          onPressed: _showOrderHistory,
        ),
        // Dark mode toggle
        IconButton(
          icon: Icon(
            _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: iconColor,
          ),
          onPressed: () {
            setState(() {
              _isDarkMode = !_isDarkMode;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products...',
            prefixIcon: const Icon(Icons.search, color: LandingColors.darkGrey),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: LandingColors.darkGrey),
                    onPressed: () {
                      _searchController.clear();
                      context.read<LandingProvider>().searchProducts('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: LandingColors.primaryRed),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: LandingColors.primaryRed, width: 2),
            ),
            filled: true,
            fillColor: LandingColors.lightGrey,
          ),
          cursorColor: LandingColors.primaryRed,
          onSubmitted: (value) {
            context.read<LandingProvider>().searchProducts(value);
          },
          onChanged: (value) {
            // Debounce search
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                context.read<LandingProvider>().searchProducts(value);
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        if (provider.categories.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: provider.categories.length + 1, // +1 for "All" chip
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "All" chip
                  final isSelected = provider.selectedCategory == null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(
                        'All',
                        style: TextStyle(
                          color: isSelected ? LandingColors.white : LandingColors.black,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: LandingColors.primaryRed,
                      backgroundColor: LandingColors.lightGrey,
                      checkmarkColor: LandingColors.white,
                      onSelected: (_) {
                        provider.filterByCategory(null);
                      },
                    ),
                  );
                }

                final category = provider.categories[index - 1];
                final isSelected = provider.selectedCategory == category.name;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(
                      '${category.name} (${category.productCount})',
                      style: TextStyle(
                        color: isSelected ? LandingColors.white : LandingColors.black,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: LandingColors.primaryRed,
                    backgroundColor: LandingColors.lightGrey,
                    checkmarkColor: LandingColors.white,
                    onSelected: (_) {
                      provider.filterByCategory(
                        provider.selectedCategory == category.name
                            ? null
                            : category.name,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOptions() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${provider.totalProducts} products',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey[400] : LandingColors.darkGrey,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // Sort dropdown
                PopupMenuButton<String>(
                  initialValue: provider.sortBy,
                  onSelected: (value) => provider.changeSortOrder(value),
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
                        style: const TextStyle(
                          color: LandingColors.primaryRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: LandingColors.primaryRed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingProducts && provider.products.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: LandingColors.primaryRed),
            ),
          );
        }

        if (provider.products.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: LandingColors.darkGrey),
                  const SizedBox(height: 16),
                  const Text(
                    'No products found',
                    style: TextStyle(fontSize: 18, color: LandingColors.darkGrey),
                  ),
                  if (provider.searchQuery != null || provider.selectedCategory != null)
                    TextButton(
                      onPressed: () => provider.clearFilters(),
                      style: TextButton.styleFrom(foregroundColor: LandingColors.primaryRed),
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = provider.products[index];
              return ProductCard(
                product: product,
                onTap: () => _openProductDetail(product),
                onLike: () => provider.toggleLike(product.itemId),
                onAddToCart: () => _addToCart(product),
                isDarkMode: _isDarkMode,
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
        if (provider.isLoadingProducts && provider.products.isNotEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: LandingColors.primaryRed),
              ),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox(height: 80));
      },
    );
  }

  Widget _buildCartFAB() {
    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        if (provider.isCartEmpty) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: () => _openCart(),
          icon: Badge(
            label: Text('${provider.cartItemCount}'),
            child: const Icon(Icons.shopping_cart),
          ),
          label: Text('TZS ${_formatPrice(provider.cartTotal)}'),
        );
      },
    );
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'latest':
        return 'Latest';
      case 'popular':
        return 'Popular';
      case 'price_low':
        return 'Price ↑';
      case 'price_high':
        return 'Price ↓';
      case 'name':
        return 'Name';
      default:
        return 'Sort';
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }

  void _openProductDetail(PublicProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }

  void _addToCart(PublicProduct product) {
    context.read<LandingProvider>().addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: _openCart,
        ),
      ),
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
    );
  }

  void _showOrderHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
    );
  }

  void _showBusinessInfo() {
    final provider = context.read<LandingProvider>();
    final info = provider.businessInfo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                info?.businessName ?? 'Gift Shop',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (info?.tagline != null) ...[
                const SizedBox(height: 4),
                Text(
                  info!.tagline!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (info?.description != null) ...[
                const SizedBox(height: 16),
                Text(info!.description!),
              ],
              const Divider(height: 32),
              if (info?.hasPhone ?? false)
                _buildContactRow(Icons.phone, 'Phone', info!.phone!),
              if (info?.hasWhatsapp ?? false)
                _buildContactRow(Icons.message, 'WhatsApp', info!.whatsapp!),
              if (info?.email != null)
                _buildContactRow(Icons.email, 'Email', info!.email!),
              if (info?.address != null)
                _buildContactRow(Icons.location_on, 'Address', info!.address!),
              if (info?.workingHours != null)
                _buildContactRow(Icons.access_time, 'Hours', info!.workingHours!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
