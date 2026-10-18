import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/public_order.dart';
import '../../providers/landing_provider.dart';
import '../../services/public_api_service.dart';
import 'landing_screen.dart' show LandingColors;
import '../../widgets/tr_text.dart';
import '../../l10n/lang.dart';

/// Shopping cart screen (used as tab)
class CartScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onNavigateToOrders;

  const CartScreen({super.key, this.isDarkMode = false, this.onNavigateToOrders});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  // Keys for SharedPreferences
  static const _keyCustomerName = 'customer_name';
  static const _keyCustomerPhone = 'customer_phone';
  static const _keyCustomerEmail = 'customer_email';
  static const _keyCustomerAddress = 'customer_address';

  @override
  bool get wantKeepAlive => true;

  late final LandingProvider _landing;

  @override
  void initState() {
    super.initState();
    _landing = context.read<LandingProvider>();
    _landing.checkoutRequest.addListener(_openCheckoutIfRequested);
    // The page can be built because of the request, after it was made.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCheckoutIfRequested());
  }

  /// "View Cart" from anywhere in the shop lands here with checkout open.
  void _openCheckoutIfRequested() {
    if (!mounted || !_landing.checkoutPending) return;
    _landing.checkoutPending = false;
    if (_landing.isCartEmpty) return;
    _showCheckoutDialog(_landing);
  }

  Color get _bgColor => widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
  Color get _cardColor => widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black;
  Color get _subtextColor => widget.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  void dispose() {
    _landing.checkoutRequest.removeListener(_openCheckoutIfRequested);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Load saved customer details from SharedPreferences
  Future<void> _loadSavedCustomerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString(_keyCustomerName) ?? '';
    _phoneController.text = prefs.getString(_keyCustomerPhone) ?? '';
    _emailController.text = prefs.getString(_keyCustomerEmail) ?? '';
    _addressController.text = prefs.getString(_keyCustomerAddress) ?? '';
  }

  /// Save customer details to SharedPreferences
  Future<void> _saveCustomerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomerName, _nameController.text.trim());
    await prefs.setString(_keyCustomerPhone, _phoneController.text.trim());
    if (_emailController.text.trim().isNotEmpty) {
      await prefs.setString(_keyCustomerEmail, _emailController.text.trim());
    }
    if (_addressController.text.trim().isNotEmpty) {
      await prefs.setString(_keyCustomerAddress, _addressController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<LandingProvider>(
      builder: (context, provider, _) {
        if (provider.isCartEmpty) {
          return _buildEmptyCart();
        }

        return Column(
          children: [
            // Header with clear button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
              child: Row(
                children: [
                  Text(
                    'Your Cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _confirmClearCart(provider),
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                    label: Text('Clear', style: TextStyle(color: Colors.red[400])),
                  ),
                ],
              ),
            ),

            // Cart items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: provider.cart.length,
                itemBuilder: (context, index) {
                  return _buildCartItem(provider.cart[index], provider);
                },
              ),
            ),

            // Order summary
            _buildOrderSummary(provider),
          ],
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products from the Home tab',
            style: TextStyle(
              color: _subtextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, LandingProvider provider) {
    final imageUrl = item.image != null
        ? PublicApiService.getProductImageUrl(item.image)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildItemPlaceholder(),
                      )
                    : _buildItemPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Price type toggle
                  if (item.hasWholesale)
                    Row(
                      children: [
                        _buildPriceTypeChip(
                          'Retail',
                          item.priceType == 'retail',
                          () {
                            final error = provider.updateCartPriceType(item.itemId, 'retail');
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPriceTypeChip(
                          'Wholesale',
                          item.priceType == 'wholesale',
                          () {
                            final error = provider.updateCartPriceType(item.itemId, 'wholesale');
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      ],
                    ),

                  const SizedBox(height: 4),

                  // Stock indicator (only shown if feature enabled for this client)
                  if (provider.hasStockDisplay && item.availableStock > 0)
                    Row(
                      children: [
                        Icon(
                          item.availableStock > 0 ? Icons.check_circle : Icons.cancel,
                          size: 12,
                          color: item.availableStock > 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.availableStock > 0
                              ? '${item.availableStock.toInt()} in stock'
                              : 'Out of stock',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.availableStock > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Price and quantity
                  Row(
                    children: [
                      Text(
                        'TZS ${_formatPrice(item.unitPrice)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const Spacer(),
                      // Quantity controls
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: widget.isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                final error = provider.updateCartQuantity(
                                  item.itemId,
                                  item.quantity - 1,
                                );
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.remove, size: 16, color: _textColor),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                final error = provider.updateCartQuantity(
                                  item.itemId,
                                  item.quantity + 1,
                                );
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.add, size: 16, color: _textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Subtotal
                  Text(
                    'Subtotal: TZS ${_formatPrice(item.subtotal)}',
                    style: TextStyle(
                      color: _subtextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[400]),
              onPressed: () => provider.removeFromCart(item.itemId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.card_giftcard,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildPriceTypeChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey[600],
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(LandingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${provider.cartItemCount} items',
                  style: TextStyle(color: _subtextColor, fontSize: 12),
                ),
                Text(
                  'TZS ${_formatPrice(provider.cartTotal)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Checkout button
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showCheckoutDialog(provider),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: LandingColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCheckoutDialog(LandingProvider provider) async {
    // Load saved customer details when opening checkout
    await _loadSavedCustomerDetails();
    final hasRememberedDetails = _nameController.text.isNotEmpty && _phoneController.text.isNotEmpty;

    if (!mounted) return;

    final isDark = widget.isDarkMode;
    final sheetBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final sheetTextColor = isDark ? Colors.white : Colors.black;
    final sheetSubtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: sheetTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (hasRememberedDetails)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.green[700]! : Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[500], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Welcome back! Your details are remembered.',
                            style: TextStyle(
                              color: isDark ? Colors.green[400] : Colors.green[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Enter your details to place the order',
                    style: TextStyle(color: sheetSubtextColor),
                  ),
                const SizedBox(height: 24),

                // Name field
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: sheetTextColor),
                  decoration: InputDecoration(
                    labelText: 'Your Name *'.tr,
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.person_outline, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone field
                TextFormField(
                  controller: _phoneController,
                  style: TextStyle(color: sheetTextColor),
                  decoration: InputDecoration(
                    labelText: 'Phone Number *'.tr,
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.phone_outlined, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    hintText: '0762995775'.tr,
                    hintStyle: TextStyle(color: sheetSubtextColor),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number'.tr;
                    }
                    // Validate Tanzanian phone format
                    final phone = value.trim();
                    if (!RegExp(r'^0[67]\d{8}$').hasMatch(phone)) {
                      return 'Enter valid phone (e.g., 0762995775)'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email field (optional)
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(color: sheetTextColor),
                  decoration: InputDecoration(
                    labelText: 'Email (Optional)'.tr,
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.email_outlined, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Address field (optional)
                TextFormField(
                  controller: _addressController,
                  style: TextStyle(color: sheetTextColor),
                  decoration: InputDecoration(
                    labelText: 'Delivery Address (Optional)'.tr,
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.location_on_outlined, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: sheetTextColor),
                  decoration: InputDecoration(
                    labelText: 'Order Notes (Optional)'.tr,
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.note_outlined, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    hintText: 'Any special instructions...'.tr,
                    hintStyle: TextStyle(color: sheetSubtextColor),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Order summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Items', style: TextStyle(color: sheetTextColor)),
                          Text('${provider.cartItemCount}', style: TextStyle(color: sheetTextColor)),
                        ],
                      ),
                      Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold, color: sheetTextColor),
                          ),
                          Text(
                            'TZS ${_formatPrice(provider.cartTotal)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: sheetTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Place order button
                Consumer<LandingProvider>(
                  builder: (context, provider, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: provider.isPlacingOrder
                            ? null
                            : () => _placeOrder(provider),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: provider.isPlacingOrder
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Place Order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder(LandingProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final order = await provider.placeOrder(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (order != null && mounted) {
      // Save customer details for next time
      await _saveCustomerDetails();

      // Close checkout dialog first, then show success
      Navigator.of(context).pop();

      // Use a slight delay to ensure navigation completes before showing dialog
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _showOrderSuccess(order);
        }
      });
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Shown once the order is saved: a clear "it worked" moment with the order
  /// number (copyable), what was ordered and what happens next.
  void _showOrderSuccess(PublicOrder order) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final muted = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final panel = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6F8);
    final brand = LandingColors.primaryRed;
    final products = order.items.map((i) => i.itemId).toSet().length;
    final count = products > 0 ? products : order.itemsCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand-coloured header with the check mark popping in.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 30, bottom: 26),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        brand,
                        HSLColor.fromColor(brand)
                            .withLightness(
                                (HSLColor.fromColor(brand).lightness * 0.7)
                                    .clamp(0.0, 1.0))
                            .toColor(),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1.0),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                                width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Icon(Icons.check_rounded,
                                  size: 42, color: brand),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Order Placed!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thank you for shopping with us',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Column(
                    children: [
                      // Order number, tap to copy.
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: order.orderNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Order number copied'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: brand,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: brand.withValues(alpha: 0.4),
                                width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.confirmation_number_outlined,
                                  size: 22, color: brand),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Order number',
                                        style: TextStyle(
                                            fontSize: 11.5, color: muted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      order.orderNumber,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.copy_rounded, size: 19, color: brand),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // What was ordered.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 20, color: muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                count == 1 ? '1 product' : '$count products',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                            Text(
                              'TZS ${_formatPrice(order.total)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // What happens next.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_in_talk_outlined,
                              size: 19, color: brand),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'We will contact you at ${order.customer.phone} '
                              'to confirm your order.',
                              style: TextStyle(
                                  fontSize: 13.5, height: 1.4, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          // Navigate to Orders tab
                          widget.onNavigateToOrders?.call();
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 20),
                        label: const Text('View My Orders',
                            style: TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text('Continue shopping',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: muted)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Confirmation shown before the whole cart is emptied. Says what is about
  /// to be lost (how many products and the total) so "Clear" is never a
  /// surprise, with the safe choice first and the destructive one in red.
  void _confirmClearCart(LandingProvider provider) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final muted = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    const danger = Color(0xFFE53935);

    final products = provider.cart.map((c) => c.itemId).toSet().length;
    final total = provider.cartTotal;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Soft red header with the icon popping in.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 28, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      danger.withValues(alpha: isDark ? 0.22 : 0.14),
                      danger.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: danger.withValues(alpha: 0.12),
                      border: Border.all(
                          color: danger.withValues(alpha: 0.35), width: 2),
                    ),
                    child: const Icon(Icons.remove_shopping_cart_rounded,
                        size: 36, color: danger),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  children: [
                    Text(
                      'Clear your cart?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All items will be removed from your cart. '
                      'This cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4, color: muted),
                    ),
                    const SizedBox(height: 16),
                    // What is about to be lost.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F6F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 20, color: muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              products == 1
                                  ? '1 product'
                                  : '$products products',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          Text(
                            'TZS ${_formatPrice(total)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: ink,
                          side: BorderSide(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : const Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Keep items',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          provider.clearCart();
                          Navigator.pop(dialogContext);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20),
                        label: const Text('Clear cart',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
