import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/public_order.dart';
import '../../providers/landing_provider.dart';
import '../../services/public_api_service.dart';

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

  Color get _bgColor => widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
  Color get _cardColor => widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black;
  Color get _subtextColor => widget.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  void dispose() {
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

                  // Stock indicator
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
                  backgroundColor: const Color(0xFFE31E24),
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
                    labelText: 'Your Name *',
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
                      return 'Please enter your name';
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
                    labelText: 'Phone Number *',
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.phone_outlined, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    hintText: '0762995775',
                    hintStyle: TextStyle(color: sheetSubtextColor),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    // Validate Tanzanian phone format
                    final phone = value.trim();
                    if (!RegExp(r'^0[67]\d{8}$').hasMatch(phone)) {
                      return 'Enter valid phone (e.g., 0762995775)';
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
                    labelText: 'Email (Optional)',
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
                    labelText: 'Delivery Address (Optional)',
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
                    labelText: 'Order Notes (Optional)',
                    labelStyle: TextStyle(color: sheetSubtextColor),
                    prefixIcon: Icon(Icons.note_outlined, color: sheetSubtextColor),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    ),
                    hintText: 'Any special instructions...',
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

  void _showOrderSuccess(PublicOrder order) {
    final isDark = widget.isDarkMode;
    final dialogBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dialogTextColor = isDark ? Colors.white : Colors.black;
    final dialogSubtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[500], size: 28),
            const SizedBox(width: 8),
            Text('Order Placed!', style: TextStyle(color: dialogTextColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Number: ${order.orderNumber}', style: TextStyle(color: dialogTextColor)),
            const SizedBox(height: 8),
            Text('Total: TZS ${_formatPrice(order.total)}', style: TextStyle(color: dialogTextColor)),
            const SizedBox(height: 16),
            Text(
              'We will contact you at ${order.customer.phone} to confirm your order.',
              style: TextStyle(color: dialogSubtextColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close dialog
              // Navigate to Orders tab
              widget.onNavigateToOrders?.call();
            },
            child: const Text('View My Orders'),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(LandingProvider provider) {
    final isDark = widget.isDarkMode;
    final dialogBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dialogTextColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text('Clear Cart?', style: TextStyle(color: dialogTextColor)),
        content: Text('Are you sure you want to remove all items from your cart?', style: TextStyle(color: dialogTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
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
