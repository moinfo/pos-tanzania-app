import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sale_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/offline_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/offline_indicator.dart';
import 'suspended_sheet_screen.dart';
import 'suspended_sheet2_screen.dart';
import 'suspended_sheet3_screen.dart';
import 'customer_care_screen.dart';
import 'map_route_screen.dart';
import 'suspended_summary_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/nfc_scan_dialog.dart';
import '../services/nfc_service.dart';
import '../models/item_quantity_offer.dart';
import '../utils/sale_design.dart';
import '../widgets/sale/keypad_sheet.dart';
import '../widgets/sale/sale_sheets.dart';
import '../models/nfc_wallet.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  SaleTheme get _sale => SaleTheme.of(context);

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  List<Item> _items = [];
  List<Item> _filteredItems = [];
  bool _isLoading = false;
  bool _isProcessing = false;

  /// Whether the inline cart preview shows its item list.
  ///
  /// Everything above the results list is fixed height, so on a phone -- and
  /// especially on Android once the keyboard claims roughly half the screen --
  /// an expanded cart leaves almost no room for search results. The cart
  /// collapses to its summary row while searching and restores afterwards; the
  /// cashier can still expand it mid-search by tapping the header.
  bool _cartExpanded = true;

  @override
  void initState() {
    super.initState();
    // The suffix icons depend on focus, so rebuild whenever it changes
    _searchFocusNode.addListener(_onSearchFocusChanged);
    // Defer location initialization until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Stock location the item list was last loaded for.
  ///
  /// The redesign has no location bar of its own -- the store switcher lives in
  /// the app bar now -- so the screen watches for a change and refetches the
  /// catalogue, which is priced and stocked per location.
  int? _lastLoadedLocationId;

  /// The redesigned Leruma sale screen.
  Widget _buildLerumaSaleScreen() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final locationId = locationProvider.selectedLocation?.locationId;

        if (locationId != null && locationId != _lastLoadedLocationId) {
          _lastLoadedLocationId = locationId;
          // Defer: we are inside build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<SaleProvider>().setStockLocation(locationId);
            _closeSearch();
            _loadItems();
          });
        }

        return _buildLerumaScaffold();
      },
    );
  }

  Widget _buildLerumaScaffold() {
    return Scaffold(
      backgroundColor: _sale.pageBackground,
      // The keyboard must not squeeze the footer off screen; the middle region
      // scrolls instead.
      resizeToAvoidBottomInset: true,
      body: _isLoading
          ? _buildSkeletonGrid(false)
          : Consumer<SaleProvider>(
              builder: (context, saleProvider, child) {
                return Column(
                  children: [
                    // Fixed context block under the app bar
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x0F0F172A), offset: Offset(0, 1)),
                        ],
                      ),
                      child: _buildLerumaContextBlock(saleProvider),
                    ),
                    // The only scrollable region
                    Expanded(child: _buildLerumaMainRegion(saleProvider)),
                    // Fixed totals + actions footer
                    Container(
                      decoration: BoxDecoration(
                        color: _sale.surface,
                        border: Border(
                            top: BorderSide(color: _sale.borderFooter)),
                        boxShadow: _sale.footerShadow,
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                      child: _buildLerumaTotalsAndActions(saleProvider),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ===================================================================
  // Redesigned sale body (design_handoff_sale_screen)
  //
  // Structure per the handoff: a fixed white context block (customer + search)
  // directly under the app bar, then ONE scrollable region that is either the
  // cart or the search results, then the fixed totals/actions footer. The old
  // location + Sheet bar and the inline cart preview above the search are gone
  // for Leruma -- the cart is the screen.
  // ===================================================================

  Widget _buildLerumaContextBlock(SaleProvider saleProvider) {
    final customer = saleProvider.selectedCustomer;

    return Container(
      color: _sale.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          customer == null
              ? _buildCustomerPrompt()
              : _buildCustomerRow(customer),
          const SizedBox(height: 9),
          _buildLerumaSearchField(saleProvider),
        ],
      ),
    );
  }

  /// Amber "required" state -- a sale cannot be charged without a customer.
  Widget _buildCustomerPrompt() {
    return Material(
      color: _sale.warningFill,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        highlightColor: _sale.warningFillPressed,
        onTap: _selectCustomer,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _sale.warningBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined,
                  size: 20, color: _sale.warning),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Select customer to start',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _sale.warningText),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: _sale.warning),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerRow(Customer customer) {
    final name = customer.fullName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Material(
      color: _sale.blueTint2,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        highlightColor: _sale.blueTintPressedRow,
        onTap: _selectCustomer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _sale.brand,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _sale.textPrimary),
                    ),
                    if (customer.phoneNumber.isNotEmpty)
                      Text(
                        customer.phoneNumber,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _sale.textMuted),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _sale.surface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Change',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _sale.brand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLerumaSearchField(SaleProvider saleProvider) {
    final hasCustomer = saleProvider.selectedCustomer != null;
    final hasText = _searchController.text.isNotEmpty;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _sale.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sale.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: _sale.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              enabled: hasCustomer,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchFocusNode.unfocus(),
              onTapOutside: (_) => _searchFocusNode.unfocus(),
              onChanged: _filterItems,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _sale.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hasCustomer
                    ? 'Search item or scan barcode'
                    : 'Select customer first',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: hasCustomer
                      ? _sale.textFaint
                      : _sale.warningText,
                ),
              ),
            ),
          ),
          if (hasText)
            InkWell(
              onTap: _closeSearch,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _sale.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Color(0xFF5A6577)),
              ),
            )
          else
            Icon(Icons.qr_code_scanner_rounded,
                size: 20, color: _sale.brand),
        ],
      ),
    );
  }

  /// The single scrollable region: results while searching, otherwise the cart.
  Widget _buildLerumaMainRegion(SaleProvider saleProvider) {
    if (_searchController.text.isNotEmpty) {
      return _buildLerumaResults();
    }
    if (!saleProvider.hasItems) {
      return _buildLerumaEmptyCart();
    }
    return _buildLerumaCart(saleProvider);
  }

  Widget _buildLerumaResults() {
    if (_filteredItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Text(
          'No item matches that name or barcode',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _sale.textFaint),
        ),
      );
    }

    final locationProvider = context.read<LocationProvider>();
    final location = locationProvider.selectedLocation;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final stock = location != null && item.quantityByLocation != null
            ? (item.quantityByLocation![location.locationId] ?? 0)
            : (item.quantity ?? 0);

        return Material(
          color: _sale.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            highlightColor: _sale.blueTint2,
            // Adding clears the query, returning the seller to the cart
            onTap: () {
              _addItemToCart(item);
              _closeSearch();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _sale.resultCardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _sale.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Stock ${stock.toStringAsFixed(0)} · ${location?.locationName ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _sale.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currencyFormat.format(item.unitPrice),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _sale.brand,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _sale.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLerumaEmptyCart() {
    // Quick-add chips: the first four catalogue items for this store
    final quick = _items.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 56),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 46, color: _sale.iconFaintAlt),
          const SizedBox(height: 14),
          Text(
            'Search an item above to\nstart this sale',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _sale.textFaint,
              height: 1.5,
            ),
          ),
          if (quick.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: quick.map((item) {
                return Material(
                  color: _sale.surface,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    highlightColor: _sale.blueTint2,
                    onTap: () => _addItemToCart(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: _sale.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _sale.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currencyFormat.format(item.unitPrice),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _sale.brand),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLerumaCart(SaleProvider saleProvider) {
    final items = saleProvider.cartItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            // CLEAR wiped the whole cart on one tap with no confirmation and
            // no way back -- removed rather than guarded, per instruction.
            // Removing individual lines still works via each row's own X.
            child: Text(
              '${items.length} ITEM${items.length == 1 ? '' : 'S'} IN CART',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: _sale.textFaint),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _sale.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _sale.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _buildLerumaCartLine(saleProvider, items[i], i,
                      isLast: i == items.length - 1),
              ],
            ),
          ),
          if (saleProvider.hasPayments) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _sale.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _sale.resultCardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < saleProvider.payments.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        border: i == saleProvider.payments.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(color: _sale.divider)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _sale.successTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.check_rounded,
                                size: 14, color: _sale.success),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              saleProvider.payments[i].paymentType,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _currencyFormat.format(saleProvider.payments[i].amount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _sale.success,
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 14, color: _sale.iconFaint),
                            constraints:
                                const BoxConstraints(minWidth: 30, minHeight: 30),
                            padding: EdgeInsets.zero,
                            onPressed: () => saleProvider.removePayment(i),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Quantity a customer must reach before an offer pays out.
  ///
  /// A tiered offer stores its thresholds in the tiers and leaves
  /// purchase_quantity at 0, so reading that column directly renders "Buy 0".
  /// The first tier is the lowest bar to clear.
  double _offerThreshold(ItemQuantityOffer offer) {
    if (offer.useTieredRewards == 1 &&
        offer.tiers != null &&
        offer.tiers!.isNotEmpty) {
      return offer.tiers!
          .map((tier) => tier.minQuantity)
          .reduce((a, b) => a < b ? a : b);
    }
    return offer.purchaseQuantity;
  }

  /// Small status pill used under a cart line.
  Widget _saleBadge({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool outlined = false,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: chip,
    );
  }

  /// Per-item discount, one-time discount and quantity-offer indicators.
  ///
  /// These carry real money rules, so the redesign keeps every one of them --
  /// only the styling changed.
  Widget _buildLerumaLineBadges(
      SaleProvider saleProvider, SaleItem item, int index) {
    final discountLimit = item.discountLimit ?? 0;
    final hasOffer = saleProvider.hasQuantityOffer(item.itemId);
    final hasOtc = saleProvider.hasOneTimeDiscount(item.itemId);
    final hasPendingOtc = saleProvider.hasPendingOneTimeDiscount(item.itemId);
    final hasApproved = saleProvider.hasApprovedDiscountRequest(item.itemId);
    final hasPendingApproved =
        saleProvider.hasPendingApprovedDiscount(item.itemId);
    final groupOffer = saleProvider.getGroupOfferForItem(item.itemId);

    final badges = <Widget>[
      // Per-item discount (tap to edit, capped at the item's discount limit)
      if (discountLimit > 0)
        _saleBadge(
          icon: Icons.discount_outlined,
          label: item.discount > 0
              ? '−${_currencyFormat.format(item.discount)}'
              : 'Disc',
          color: item.discount > 0 ? _sale.warning : _sale.textFaint,
          outlined: item.discount > 0,
          onTap: () => _openLineDiscountDialog(saleProvider, item, index, discountLimit),
        ),
      if (hasOtc)
        _saleBadge(
          icon: Icons.local_offer,
          label: 'OTC',
          color: _sale.success,
        ),
      if (hasPendingOtc && !hasOtc)
        _saleBadge(
          icon: Icons.local_offer_outlined,
          label:
              'OTC: ${saleProvider.getOneTimeDiscountRequiredQty(item.itemId)?.toStringAsFixed(0) ?? "?"}',
          color: _sale.warning,
        ),
      if (hasApproved)
        _saleBadge(
          icon: Icons.verified_outlined,
          label: 'Approved',
          color: _sale.success,
        ),
      if (hasPendingApproved && !hasApproved)
        _saleBadge(
          icon: Icons.hourglass_empty_rounded,
          label: 'Pending',
          color: _sale.warning,
        ),
      if (hasOffer)
        Builder(builder: (context) {
          final offer = saleProvider.getQuantityOffer(item.itemId)!;
          final freeQty = offer.calculateReward(item.quantity);
          final eligible = freeQty > 0;
          return _saleBadge(
            icon: eligible ? Icons.card_giftcard : Icons.card_giftcard_outlined,
            label: eligible
                ? '+${freeQty.toStringAsFixed(0)} FREE'
                : 'Buy ${_offerThreshold(offer).toStringAsFixed(0)}',
            color: eligible ? _sale.success : _sale.brand,
          );
        }),
      // Group offer: threshold is the combined quantity of its member items, so
      // the badge shows progress across the whole group, not just this line.
      if (groupOffer != null)
        Builder(builder: (context) {
          final combined = saleProvider.groupOfferCombinedQuantity(groupOffer);
          final freeQty = saleProvider.groupOfferReward(groupOffer);
          final eligible = freeQty > 0;
          final threshold = _offerThreshold(groupOffer);

          return _saleBadge(
            icon: eligible ? Icons.card_giftcard : Icons.groups_outlined,
            label: eligible
                ? 'GROUP +${freeQty.toStringAsFixed(0)} FREE'
                : 'Group ${combined.toStringAsFixed(0)}/${threshold.toStringAsFixed(0)}',
            color: eligible ? _sale.success : _sale.brand,
          );
        }),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: badges),
    );
  }

  /// Per-item discount editor, capped at the item's discount limit.
  Future<void> _openLineDiscountDialog(
    SaleProvider saleProvider,
    SaleItem item,
    int index,
    int discountLimit,
  ) async {
    final perItem = item.discount > 0 ? (item.discount / item.quantity) : 0;
    final controller = TextEditingController(
        text: perItem > 0 ? perItem.toStringAsFixed(0) : '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Discount per item', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Max: ${_currencyFormat.format(discountLimit)} TSh',
                style: TextStyle(fontSize: 12, color: _sale.warning)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Discount (TSh)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              var disc = double.tryParse(controller.text) ?? 0;
              if (disc > discountLimit) disc = discountLimit.toDouble();
              saleProvider.updateDiscount(index, disc * item.quantity,
                  discountType: 1);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildLerumaCartLine(
    SaleProvider saleProvider,
    SaleItem item,
    int index, {
    required bool isLast,
  }) {
    final isFree = item.quantityOfferFree;
    final lineTotal = (item.quantity * item.unitPrice) - item.discount;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _sale.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _sale.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  isFree
                      // Show how many units are free -- the reward line has no
                      // quantity pill, so this is the only place it appears
                      ? '🎁 ${item.quantity.toStringAsFixed(0)} free · offer'
                      : '${item.quantity.toStringAsFixed(0)} × ${_currencyFormat.format(item.unitPrice)} TSh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isFree ? _sale.success : _sale.textMuted),
                ),
                if (!isFree) _buildLerumaLineBadges(saleProvider, item, index),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Quantity pill -> keypad sheet. Reward lines are derived, not editable.
          if (!isFree)
            Material(
              color: _sale.blueTint3,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                highlightColor: _sale.blueTintPressedAlt,
                onTap: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                    ? null
                    : () => _openQuantitySheet(saleProvider, index),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _sale.blueBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        alignment: Alignment.center,
                        child: Text(
                          item.quantity.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _sale.brand,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.edit_outlined,
                          size: 13, color: _sale.brand),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          // Min width keeps the column aligned for ordinary amounts, but the
          // text is allowed to grow: a fixed 70px wrapped "2,300,000" onto two
          // lines. The name is Expanded, so it yields the space.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 70),
            child: Text(
              _currencyFormat.format(lineTotal),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: _sale.textPrimary,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          // 44x44 target, pulled right so the glyph sits at the card edge
          Transform.translate(
            offset: const Offset(10, 0),
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 13, color: _sale.iconFaint),
                padding: EdgeInsets.zero,
                onPressed: () => saleProvider.removeItem(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // Redesigned sale footer + sheets (design_handoff_sale_screen)
  //
  // These replace the old two-row button block and the payment dialog for
  // Leruma. They deliberately reuse _suspendSale/_completeSale so the existing
  // NFC confirmation, permission and offer/discount bookkeeping still runs.
  // ===================================================================

  /// Totals block and the Suspend / Charge action row.
  Widget _buildLerumaTotalsAndActions(SaleProvider saleProvider) {
    final subtotal = saleProvider.subtotal;
    final lineDiscounts = saleProvider.totalDiscount;
    final due = saleProvider.amountDue;
    final hasCustomer = saleProvider.selectedCustomer != null;
    final canCharge = hasCustomer && saleProvider.hasItems && !_isProcessing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtotal
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _sale.textFaint)),
              Text(
                '${_currencyFormat.format(subtotal)} TSh',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _sale.textSecondary,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
        ),
        // Line discounts are shown here as a read-only total. There is no
        // order-level discount in this business: discount is always per item,
        // set from the line's Disc chip and capped by that item's limit.
        if (lineDiscounts > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.discount_outlined,
                        size: 14, color: _sale.warning),
                    SizedBox(width: 5),
                    Text(
                      'Item discounts',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _sale.warning),
                    ),
                  ],
                ),
                Text(
                  '− ${_currencyFormat.format(lineDiscounts)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _sale.danger,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
          ),
        // Balance due
        Container(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _sale.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                saleProvider.hasPayments ? 'Balance due' : 'Total',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _sale.textMuted),
              ),
              Text(
                _currencyFormat.format(due < 0 ? 0 : due),
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: _sale.textPrimary,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
        ),
        // Suspend + Charge
        Row(
          children: [
            PermissionWrapper(
              permissionId: PermissionIds.salesSuspended,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Material(
                  color: _sale.warningFillSoft,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    highlightColor: _sale.warningFillPressed,
                    onTap: _isProcessing ? null : _suspendSale,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _sale.warningBorder, width: 1.5),
                      ),
                      child: Icon(Icons.pause_rounded,
                          size: 20, color: _sale.warning),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SaleSheetButton(
                label: saleProvider.isFullyPaid && saleProvider.hasItems
                    ? 'Complete sale'
                    : 'Charge ${_currencyFormat.format(due < 0 ? 0 : due)}',
                icon: Icons.credit_card_rounded,
                color: _sale.brand,
                pressedColor: _sale.brandPressed,
                shadow: _sale.primaryButtonShadow,
                onTap: canCharge ? () => _onCharge(saleProvider) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Charge: complete straight away when the balance is covered, otherwise
  /// collect a payment first.
  Future<void> _onCharge(SaleProvider saleProvider) async {
    if (saleProvider.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select a customer to start'),
          backgroundColor: _sale.warning,
        ),
      );
      return;
    }

    if (saleProvider.isFullyPaid) {
      await _completeSale();
      return;
    }

    await _openPaymentSheet(saleProvider);
  }

  /// Payment methods offered for the selected customer.
  ///
  /// Bank is only offered when this customer is allowed to use it, matching
  /// the web register and the customers.allow_bank_payment flag.
  /// 'Credit Card' is what the register stores for a credit sale -- it is the
  /// sales_credit language line, and Customer->get_credit, the statement's
  /// credit side and the API's credit-limit check all match on that exact
  /// string. Sending a bare 'Credit' left credit sales out of every one of
  /// them, so the customer's own statement never showed the sale.
  List<String> _paymentMethodsFor(SaleProvider saleProvider) => <String>[
        'Cash',
        if (saleProvider.selectedCustomer?.allowBankPayment ?? false) 'Bank',
        'Credit Card',
      ];

  /// Shows the payment keypad and records whatever the seller confirms.
  ///
  /// Returns true when a payment was actually added, so callers can tell a
  /// confirmed amount from a dismissed sheet.
  Future<bool> _collectPayment(SaleProvider saleProvider,
      {bool addOnly = false}) async {
    final countBefore = saleProvider.payments.length;

    await showSaleSheet(context, (_) {
      return PaymentSheet(
        amountDue: saleProvider.amountDue,
        isPartPayment: saleProvider.hasPayments,
        addOnly: addOnly,
        methods: _paymentMethodsFor(saleProvider),
        onConfirm: (method, amount) {
          saleProvider.addPayment(SalePayment(paymentType: method, amount: amount));
        },
      );
    });

    if (!mounted) return false;
    return saleProvider.payments.length > countBefore;
  }

  Future<void> _openPaymentSheet(SaleProvider saleProvider) async {
    await _collectPayment(saleProvider);

    if (!mounted) return;

    // Covering the balance completes the sale; otherwise the seller stays on the
    // cart with the remaining balance -- this is how split payments work.
    if (saleProvider.isFullyPaid && saleProvider.hasItems) {
      await _completeSale();
    }
  }

  Future<void> _openQuantitySheet(SaleProvider saleProvider, int index) async {
    final item = saleProvider.cartItems[index];
    await showSaleSheet(context, (_) {
      return QuantitySheet(
        itemName: item.itemName,
        initialQuantity: item.quantity,
        onChanged: (qty) => saleProvider.updateQuantity(index, qty),
      );
    });
  }

  /// Fully close the item search: drop the query, the results and the keyboard.
  ///
  /// Clearing the text alone left stale results on screen, and unfocusing alone
  /// left the query in place, so both were doing half the job.
  void _closeSearch() {
    _searchController.clear();
    _filterItems('');
    FocusScope.of(context).unfocus();
  }

  /// Trailing icons for the item search field.
  ///
  /// While the field has focus it offers a dismiss button, because an empty
  /// focused field otherwise leaves the keyboard up with no way to close it
  /// short of the system back gesture. Dismissing keeps whatever was typed so
  /// the results stay on screen.
  Widget? _buildSearchSuffix(bool isDark, bool hasCustomer) {
    final hasText = _searchController.text.isNotEmpty;
    final isFocused = _searchFocusNode.hasFocus;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade600;

    final icons = <Widget>[
      if (hasText)
        IconButton(
          icon: Icon(Icons.clear_rounded, color: iconColor),
          tooltip: 'Clear search',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            _searchController.clear();
            _filterItems('');
          },
        ),
      if (!isFocused && !hasText && hasCustomer)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Icon(
            Icons.qr_code_scanner_rounded,
            size: 22,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
          ),
        ),
    ];

    if (icons.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    // Initialize for sales module to get sales-specific locations
    await locationProvider.initialize(moduleId: 'sales');
    // Load items after location is initialized
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    final locationProvider = context.read<LocationProvider>();
    final connectivityProvider = context.read<ConnectivityProvider>();
    final offlineProvider = context.read<OfflineProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    // Check if offline AND offline mode is initialized (enabled for this client)
    if (!connectivityProvider.isOnline && offlineProvider.isInitialized) {
      debugPrint('📴 Loading items from offline database');
      final offlineItems = await offlineProvider.getOfflineItems(
        locationId: selectedLocationId,
        limit: 100,
      );

      if (offlineItems.isNotEmpty) {
        setState(() {
          _items = offlineItems.map((data) => Item.fromJson(data)).toList();
          _filteredItems = [];
          _isLoading = false;
        });
        return;
      }
    }

    // Online - fetch from API
    final response = await _apiService.getItems(
      limit: 100,
      locationId: selectedLocationId,
    );

    if (response.isSuccess && response.data != null) {
      setState(() {
        _items = response.data!;
        _filteredItems = []; // Start with empty list - show items only when user searches
        _isLoading = false;
      });
    } else {
      // If API fails, try offline as fallback -- but only for clients that have
      // offline mode enabled. Otherwise there is no local database to read and
      // the API error should surface directly.
      final offlineItems = offlineProvider.isInitialized
          ? await offlineProvider.getOfflineItems(
              locationId: selectedLocationId,
              limit: 100,
            )
          : const <Map<String, dynamic>>[];

      if (offlineItems.isNotEmpty) {
        setState(() {
          _items = offlineItems.map((data) => Item.fromJson(data)).toList();
          _filteredItems = [];
          _isLoading = false;
        });
        debugPrint('📴 Loaded ${_items.length} items from offline (API fallback)');
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  void _filterItems(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredItems = []; // Don't show items when search is empty
        _cartExpanded = true; // Search finished: give the cart its space back
      });
      return;
    }

    // Free up vertical space for results as soon as searching begins
    if (_cartExpanded) {
      setState(() => _cartExpanded = false);
    }

    final locationProvider = context.read<LocationProvider>();
    final connectivityProvider = context.read<ConnectivityProvider>();
    final offlineProvider = context.read<OfflineProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId;

    debugPrint('🔍 Search query: "$query", locationId: $selectedLocationId, online: ${connectivityProvider.isOnline}, offlineInitialized: ${offlineProvider.isInitialized}');

    // Check if offline AND offline mode is initialized (enabled for this client)
    if (!connectivityProvider.isOnline && offlineProvider.isInitialized) {
      final offlineItems = await offlineProvider.getOfflineItems(
        locationId: selectedLocationId,
        search: query,
        limit: 50,
      );

      debugPrint('📴 Offline search returned ${offlineItems.length} items');
      setState(() {
        _filteredItems = offlineItems.map((data) => Item.fromJson(data)).toList();
      });
      return;
    }

    // Online - search via API
    final response = await _apiService.getItems(
      search: query,
      limit: 50,
      locationId: selectedLocationId,
    );

    debugPrint('📡 API response: success=${response.isSuccess}, itemCount=${response.data?.length ?? 0}, message=${response.message}');

    if (response.isSuccess && response.data != null) {
      setState(() {
        _filteredItems = response.data!;
      });
    } else {
      // Fallback to offline search only when this client has offline mode
      if (!offlineProvider.isInitialized) {
        debugPrint('⚠️ API search failed and offline mode is disabled for this client');
        setState(() => _filteredItems = []);
        return;
      }

      debugPrint('⚠️ API failed, falling back to offline search');
      final offlineItems = await offlineProvider.getOfflineItems(
        locationId: selectedLocationId,
        search: query,
        limit: 50,
      );

      setState(() {
        _filteredItems = offlineItems.map((data) => Item.fromJson(data)).toList();
      });
    }
  }

  void _addItemToCart(Item item) {
    final locationProvider = context.read<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a stock location first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final isLerumaClient = ApiService.currentClient?.features.hasOutOfStockSelling ?? false;

    // Get stock quantity for selected location
    double currentStock = 0;
    if (item.quantityByLocation != null) {
      currentStock = item.quantityByLocation![selectedLocation.locationId] ?? 0;
    } else {
      currentStock = item.quantity ?? 0;
    }

    // Only enforce stock validation for non-Leruma clients
    if (!isLerumaClient) {
      if (currentStock <= 0) {
        // Show error - out of stock
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} is out of stock at ${selectedLocation.locationName}!'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final saleProvider = context.read<SaleProvider>();

    // Set stock location in provider if not already set
    if (saleProvider.stockLocation != selectedLocation.locationId) {
      saleProvider.setStockLocation(selectedLocation.locationId);
    }

    // Get current quantity in cart for this item. Offer reward lines are included
    // because free units come off the same shelf as paid ones, and summing every
    // matching line avoids picking just the first one when both kinds are present.
    final currentQuantityInCart = saleProvider.cartItems
        .where((cartItem) => cartItem.itemId == item.itemId)
        .fold<double>(0, (sum, cartItem) => sum + cartItem.quantity);
    final totalQuantityInCart = currentQuantityInCart + 1;

    // Only enforce stock limit for non-Leruma clients
    if (!isLerumaClient && totalQuantityInCart > currentStock) {
      // Show error - insufficient stock
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.name}: Only ${currentStock.toStringAsFixed(0)} available in stock!\nAlready have ${currentQuantityInCart.toStringAsFixed(0)} in cart.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Add to cart with location-specific stock
    saleProvider.addItem(item, quantity: 1, locationId: selectedLocation.locationId);

    // Show different messages for Leruma vs non-Leruma
    final successMessage = isLerumaClient
        ? '${item.name} added to cart (${totalQuantityInCart.toStringAsFixed(0)})'
        : '${item.name} added to cart (${totalQuantityInCart.toStringAsFixed(0)}/${currentStock.toStringAsFixed(0)})';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );

    // Clear the search box + results so the next item can be searched immediately.
    // Mirrors the existing clear-button behaviour at the search field.
    _searchController.clear();
    _filterItems('');
  }

  Future<void> _selectCustomer() async {
    // Show customer selection dialog
    showDialog(
      context: context,
      builder: (context) => const CustomerSelectionDialog(),
    );
  }

  Future<void> _suspendSale() async {
    final saleProvider = context.read<SaleProvider>();

    // Validate cart
    final validationError = saleProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Leruma parks an order only once a deposit is on it. Rather than refusing,
    // the pause button opens the payment keypad so the seller picks a method and
    // amount right here, then falls through to the comment dialog. Backing out
    // of that sheet cancels the suspend -- no payment, no parked order.
    final requiresPayment =
        ApiService.currentClient?.features.hasSuspendRequiresPayment ?? false;
    if (requiresPayment && !saleProvider.hasPayments) {
      final paid = await _collectPayment(saleProvider, addOnly: true);
      if (!mounted) return;
      if (!paid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A payment is needed before suspending this sale.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Ask for optional comment
    String? comment;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add an optional comment for this suspended sale:'),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'e.g., Customer will return later',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              comment = commentController.text.trim();
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final customerId = saleProvider.selectedCustomer?.personId;
      debugPrint('Suspend sale: customer_id=$customerId, customer_name=${saleProvider.selectedCustomer?.fullName}');
      debugPrint('Suspend sale: ${saleProvider.cartItems.length} items in cart');

      final response = await _apiService.suspendSale(
        items: saleProvider.cartItems,
        customerId: customerId,
        comment: comment?.isNotEmpty == true ? comment : null,
        // If this cart came from Resume Sale, update that same suspended row
        // instead of creating a second one for the same order.
        saleId: saleProvider.resumedFromSaleId,
        payments: saleProvider.payments,
        stockLocationId: saleProvider.stockLocation,
      );

      setState(() => _isProcessing = false);

      if (response.isSuccess) {
        // Clear cart
        saleProvider.clearCart();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale suspended successfully!'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error suspending sale: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSaleSuccessDialog(
    Sale sale, {
    double? nfcAmountUsed,
    double? nfcBalanceAfter,
    String? nfcCardUid,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 12),
            const Text('Sale Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sale #${sale.saleId} has been completed successfully.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Total: ${NumberFormat('#,##0').format(sale.total)} TSh',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            // Show NFC payment info if applicable
            if (nfcAmountUsed != null && nfcAmountUsed > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.nfc, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'NFC Card Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Deducted:'),
                        Text(
                          '${NumberFormat('#,##0').format(nfcAmountUsed)} TSh',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (nfcBalanceAfter != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Balance:'),
                          Text(
                            '${NumberFormat('#,##0').format(nfcBalanceAfter)} TSh',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Would you like to print or share the receipt?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No Thanks'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await PdfService.shareSaleReceiptPdf(
                  sale,
                  companyName: ApiService.currentClient?.name ?? 'POS Tanzania',
                  nfcAmountUsed: nfcAmountUsed,
                  nfcBalanceAfter: nfcBalanceAfter,
                  nfcCardUid: nfcCardUid,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to share receipt: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Preparing receipt...'),
                      ],
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );
                await PdfService.printSaleReceipt(
                  sale,
                  companyName: ApiService.currentClient?.name ?? 'POS Tanzania',
                  nfcAmountUsed: nfcAmountUsed,
                  nfcBalanceAfter: nfcBalanceAfter,
                  nfcCardUid: nfcCardUid,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to print receipt: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.print),
            label: const Text('Print'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog(Map<String, dynamic> saleData) {
    final debug = saleData['debug'] as Map<String, dynamic>?;

    if (debug == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Sale Debug Info', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sale ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text('Sale ID: ${debug['sale_id']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tables Updated
              const Text('✅ Tables Updated:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (debug['tables_updated'] != null) ...[
                for (var entry in (debug['tables_updated'] as Map<String, dynamic>).entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text('• ${entry.key}: ${entry.value} record(s)',
                      style: const TextStyle(fontSize: 13)),
                  ),
              ],

              const SizedBox(height: 16),
              const Divider(thickness: 2),
              const SizedBox(height: 16),

              // Inventory Logs
              Row(
                children: [
                  Icon(
                    (debug['inventory_logs_created'] ?? 0) > 0
                        ? Icons.check_circle
                        : Icons.error,
                    color: (debug['inventory_logs_created'] ?? 0) > 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text('Inventory Logs: ${debug['inventory_logs_created']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: (debug['inventory_logs_created'] ?? 0) > 0
                          ? AppColors.success
                          : AppColors.error,
                    )),
                ],
              ),

              const SizedBox(height: 16),
              const Text('📦 Items with Stock Changes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              // Items with Before/After Quantities
              if (debug['items_processed'] != null) ...[
                for (var item in (debug['items_processed'] as List<dynamic>))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['item_name']} (ID: ${item['item_id']})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Before', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${item['quantity_before']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                            const Text('−', style: TextStyle(fontSize: 24, color: AppColors.warning)),
                            Column(
                              children: [
                                const Text('Sold', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${item['quantity_sold']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error)),
                              ],
                            ),
                            const Text('=', style: TextStyle(fontSize: 24, color: AppColors.warning)),
                            Column(
                              children: [
                                const Text('After', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${item['quantity_after']}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('📝 Log: ${item['inventory_log']}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPayment() async {
    final saleProvider = context.read<SaleProvider>();

    // Validate customer is selected
    if (saleProvider.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before adding payment'),
          backgroundColor: AppColors.warning,
        ),
      );
      // Open customer selection dialog
      _selectCustomer();
      return;
    }

    // Validate cart
    final validationError = saleProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Check if already fully paid
    if (saleProvider.isFullyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale is already fully paid'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Show payment dialog with remaining amount due
    final amountDue = saleProvider.amountDue;
    final payment = await showDialog<SalePayment>(
      context: context,
      builder: (context) => PaymentDialog(
        total: amountDue,
        customer: saleProvider.selectedCustomer,
        maxAmount: amountDue, // Pass max amount to prevent overpayment
      ),
    );

    if (payment == null) return;

    // Validate payment doesn't exceed amount due
    if (payment.amount > amountDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment amount cannot exceed amount due (${amountDue.toStringAsFixed(0)} TSh)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Add payment to list
    saleProvider.addPayment(payment);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment added: ${payment.paymentType} - ${payment.amount.toStringAsFixed(0)} TSh'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeSale() async {
    final saleProvider = context.read<SaleProvider>();

    // Validate customer is selected
    if (saleProvider.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before checkout'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Validate cart
    final validationError = saleProvider.validateCart();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Validate payments
    if (!saleProvider.hasPayments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one payment'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!saleProvider.isFullyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment incomplete. Amount due: ${saleProvider.amountDue.toStringAsFixed(0)} TSh',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Check if NFC confirmation is required for credit or cash sales.
    // Credit confirmation is gated by nfcConfirmRequired; cash confirmation is a
    // SEPARATE per-customer toggle (nfcConfirmRequiredCash).
    final customer = saleProvider.selectedCustomer;
    if (customer != null && (customer.nfcConfirmRequired || customer.nfcConfirmRequiredCash)) {
      final hasCreditPayment = customer.nfcConfirmRequired && saleProvider.payments.any(
        (p) => p.paymentType.toLowerCase().contains('credit'),
      );
      final hasCashPayment = customer.nfcConfirmRequiredCash && saleProvider.payments.any(
        (p) => p.paymentType == 'Cash',
      );

      // Skip NFC confirmation if paying with NFC Card (card already used for payment)
      final hasNfcCardPayment = saleProvider.payments.any(
        (p) => p.paymentType == 'NFC Card',
      );

      if ((hasCreditPayment || hasCashPayment) && !hasNfcCardPayment) {
        // Get customer's NFC card
        final cardsResponse = await _apiService.getCustomerCards(customer.personId);
        if (!cardsResponse.isSuccess || cardsResponse.data == null || cardsResponse.data!.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Customer has NFC confirmation required but no NFC card linked'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        final card = cardsResponse.data!.first;
        final confirmAmount = saleProvider.payments
            .where((p) => p.paymentType.toLowerCase().contains('credit') || p.paymentType == 'Cash')
            .fold<double>(0, (sum, p) => sum + p.amount);

        final confirmTitle = hasCreditPayment ? 'Confirm Credit Sale' : 'Confirm Cash Sale';
        final confirmSubtitle = hasCreditPayment
            ? 'Customer must scan NFC card to confirm credit purchase of TZS ${_currencyFormat.format(confirmAmount)}'
            : 'Customer must scan NFC card to confirm cash payment of TZS ${_currencyFormat.format(confirmAmount)}';

        // Show NFC confirmation dialog
        final scanResult = await showDialog<NfcScanResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => NfcScanDialog(
            title: confirmTitle,
            subtitle: confirmSubtitle,
            expectedCardUid: card.cardUid,
            lookupCustomer: false,
          ),
        );

        // Dialog returns null if cancelled, or result when correct card scanned
        if (scanResult == null || !mounted) return;

        // Log the confirmation in the backend
        if (hasCreditPayment) {
          final creditAmount = saleProvider.payments
              .where((p) => p.paymentType.toLowerCase().contains('credit'))
              .fold<double>(0, (sum, p) => sum + p.amount);
          await _apiService.confirmCreditSaleWithNfc(
            cardUid: card.cardUid,
            amount: creditAmount,
          );
        } else if (hasCashPayment) {
          final cashAmount = saleProvider.payments
              .where((p) => p.paymentType == 'Cash')
              .fold<double>(0, (sum, p) => sum + p.amount);
          await _apiService.confirmCashSaleWithNfc(
            cardUid: card.cardUid,
            amount: cashAmount,
          );
        }
      }
    }

    // Check if there's an NFC Card payment - require card scan to confirm
    final hasNfcCardPayment = saleProvider.payments.any(
      (p) => p.paymentType == 'NFC Card',
    );

    String? nfcCardUid; // Store the card UID for payment processing

    if (hasNfcCardPayment && customer != null) {
      final nfcPaymentAmount = saleProvider.payments
          .where((p) => p.paymentType == 'NFC Card')
          .fold<double>(0, (sum, p) => sum + p.amount);

      // Get customer's NFC card
      final cardsResponse = await _apiService.getCustomerCards(customer.personId);
      if (!cardsResponse.isSuccess || cardsResponse.data == null || cardsResponse.data!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer has no NFC card linked'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final card = cardsResponse.data!.first;
      nfcCardUid = card.cardUid;

      // Show NFC confirmation dialog for payment
      final scanResult = await showDialog<NfcScanResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => NfcScanDialog(
          title: 'Confirm NFC Payment',
          subtitle: 'Customer must scan NFC card to pay TZS ${_currencyFormat.format(nfcPaymentAmount)}',
          expectedCardUid: card.cardUid,
          lookupCustomer: false,
        ),
      );

      // Dialog only returns result when correct card is scanned
      // Returns null if user cancelled
      if (scanResult == null || !mounted) {
        return; // User cancelled
      }
    }

    // Enforce Credit Card item restrictions BEFORE creating the sale.
    // Early-warning layer; api/Sales::createSale also rejects server-side as a backstop.
    final hasCreditCardPayment = saleProvider.payments.any(
      (p) => p.paymentType == 'Credit Card',
    );
    if (hasCreditCardPayment && customer != null) {
      final itemIds = saleProvider.cartItems.map((i) => i.itemId).toList();
      final ccResponse = await _apiService.checkCcRestrictions(
        customerId: customer.personId,
        itemIds: itemIds,
      );
      if (!mounted) return;

      // Fail SAFE: if the check could not complete, never silently allow.
      if (!ccResponse.isSuccess || ccResponse.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify credit-card eligibility, try again'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final ccData = ccResponse.data!;
      final allowed = ccData['allowed'] == true;
      if (!allowed) {
        final restricted = (ccData['restricted'] as List?) ?? [];
        final names = restricted
            .map((r) => (r as Map)['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'These items cannot be paid with Credit Card: $names. '
              'Please use cash for these items.',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Create sale
    setState(() => _isProcessing = true);

    try {
      final sale = saleProvider.createSale();
      print('DEBUG: Creating sale with data: ${sale.toCreateJson()}');

      final response = await _apiService.createSale(sale);
      print('DEBUG: API Response - Success: ${response.isSuccess}, Message: ${response.message}');

      // Print debug info
      if (response.data != null && response.data!.toJson().containsKey('debug')) {
        print('DEBUG: Response contains debug info');
        print('DEBUG: Debug data: ${response.data!.toJson()['debug']}');
      }

      setState(() => _isProcessing = false);

      if (response.isSuccess) {
        // Process NFC Card payment - deduct from wallet
        double? nfcAmountUsed;
        double? nfcBalanceAfter;

        if (hasNfcCardPayment && nfcCardUid != null) {
          final nfcPaymentAmount = saleProvider.payments
              .where((p) => p.paymentType == 'NFC Card')
              .fold<double>(0, (sum, p) => sum + p.amount);

          final paymentResponse = await _apiService.payWithNfcCard(
            cardUid: nfcCardUid,
            amount: nfcPaymentAmount,
            saleId: response.data?.saleId,
            description: 'Sale payment',
          );

          if (!paymentResponse.isSuccess) {
            debugPrint('⚠️ NFC wallet payment failed: ${paymentResponse.message}');
            // Note: Sale is already created, so we just log the warning
            // The backend should handle this case
          } else {
            debugPrint('✅ NFC wallet payment successful');
            nfcAmountUsed = nfcPaymentAmount;
            nfcBalanceAfter = paymentResponse.data?.balanceAfter;
          }
        }

        // Mark one-time discounts as used BEFORE clearing cart.
        // Quantity offers are deliberately NOT redeemed here: api/Sales.php already
        // calls record_redemption() while creating the sale, so calling /redeem as
        // well would write a second redemption row for the same sale.
        if (response.data?.saleId != null) {
          final saleId = response.data!.saleId!;
          debugPrint('Sale completed: Marking discounts as used for sale_id=$saleId');
          await saleProvider.markDiscountsAsUsed(saleId);
        }

        // This cart may have come from Resume Sale -- the suspended row it
        // was loaded from is left alone until now (see suspended_sales_screen
        // .dart), so the customer's order was never lost by resuming without
        // finishing it. Now that a real completed sale exists, remove it.
        if (saleProvider.resumedFromSaleId != null) {
          // Surface a failure instead of swallowing it: a silent 403 here is
          // exactly how completed resumes left orphaned suspended rows behind.
          // The sale itself completed fine, so warn rather than error.
          final cleanup = await _apiService
              .deleteSuspendedSale(saleProvider.resumedFromSaleId!);
          if (!cleanup.isSuccess) {
            debugPrint(
                'Complete sale: failed to remove suspended #${saleProvider.resumedFromSaleId}: ${cleanup.message}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Sale completed, but the suspended copy could not be removed: ${cleanup.message}'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          }
        }

        // Clear cart
        saleProvider.clearCart();

        // Show success message and ask about printing
        if (mounted && response.data != null) {
          _showSaleSuccessDialog(
            response.data!,
            nfcAmountUsed: nfcAmountUsed,
            nfcBalanceAfter: nfcBalanceAfter,
            nfcCardUid: nfcCardUid,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale completed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      setState(() => _isProcessing = false);
      print('DEBUG: Exception creating sale: $e');
      print('DEBUG: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Quick action button for app bar (compact, light colors on dark background)
  Widget _buildAppBarButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 11),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods for quick action buttons
  void _navigateToSheet(int sheetNumber) {
    if (sheetNumber == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SuspendedSheetScreen()),
      );
    } else if (sheetNumber == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SuspendedSheet2Screen()),
      );
    } else if (sheetNumber == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SuspendedSheet3Screen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sheet $sheetNumber - Coming soon'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToCustomerCare() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CustomerCareScreen()),
    );
  }

  void _navigateToMapRoute() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapRouteScreen()),
    );
  }

  void _navigateToSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SuspendedSummaryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    // Leruma runs the redesigned layout from design_handoff_sale_screen: no
    // location/Sheet toolbar, no inline cart above the search -- the cart IS
    // the screen. Other clients keep the original tree below.
    if (ApiService.currentClient?.features.hasInlineCartPreview ?? false) {
      return _buildLerumaSaleScreen();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
      appBar: null,
      body: _isLoading
          ? _buildSkeletonGrid(isDark)
          : Column(
              children: [
                // Toolbar row - Location and Sheet only
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Location dropdown
                      if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
                        Expanded(
                          child: PopupMenuButton<StockLocation>(
                            offset: const Offset(0, 40),
                            color: isDark ? AppColors.darkCard : Colors.white,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.store, size: 18, color: isDark ? Colors.white70 : Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      locationProvider.selectedLocation!.locationName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade600),
                                ],
                              ),
                            ),
                            onSelected: (location) async {
                              await locationProvider.selectLocation(location);
                              _loadItems();
                            },
                            itemBuilder: (context) => locationProvider.allowedLocations
                                .map((location) => PopupMenuItem<StockLocation>(
                                      value: location,
                                      child: Row(
                                        children: [
                                          Icon(
                                            location.locationId == locationProvider.selectedLocation?.locationId
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            size: 18,
                                            color: location.locationId == locationProvider.selectedLocation?.locationId
                                                ? AppColors.primary
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            location.locationName,
                                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      // Sheet button - Leruma only
                      if (ApiService.currentClient?.features.hasSaleSheetButton ?? false) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _navigateToSheet(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description, size: 18, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Sheet',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Customer selector - full width above search
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GestureDetector(
                    onTap: _selectCustomer,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: saleProvider.selectedCustomer != null
                            ? (isDark ? AppColors.darkCard : Colors.white)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: saleProvider.selectedCustomer != null
                              ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                              : AppColors.warning,
                          width: saleProvider.selectedCustomer != null ? 1 : 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: saleProvider.selectedCustomer != null
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              saleProvider.selectedCustomer != null ? Icons.person : Icons.person_add,
                              size: 20,
                              color: saleProvider.selectedCustomer != null ? AppColors.primary : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  saleProvider.selectedCustomer != null ? 'Customer' : 'No Customer Selected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  saleProvider.selectedCustomer != null
                                      ? '${saleProvider.selectedCustomer!.firstName} ${saleProvider.selectedCustomer!.lastName}'
                                      : 'Tap to select customer',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: saleProvider.selectedCustomer != null
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Remove customer button - only when a customer is selected
                          if (saleProvider.selectedCustomer != null)
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                              tooltip: 'Remove customer',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => saleProvider.clearCustomer(),
                            ),
                          Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Inline Cart Section - Leruma only (above search)
                if (ApiService.currentClient?.features.hasInlineCartPreview ?? false)
                  Consumer<SaleProvider>(
                    builder: (context, saleProvider, child) {
                      if (!saleProvider.hasItems) {
                        return const SizedBox.shrink();
                      }
                      // With no search running, the space below is idle, so let the
                      // cart claim it and show as many lines as fit instead of
                      // scrolling inside a 180px box while the screen sits empty.
                      // While searching it stays small so results keep the room.
                      final double cartMaxHeight = _cartExpanded
                          ? MediaQuery.of(context).size.height * 0.42
                          : 180;

                      return Container(
                        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        constraints: BoxConstraints(maxHeight: cartMaxHeight),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Cart header -- tapping anywhere on it expands/collapses
                            // the item list, so the cashier can always reach the
                            // cart without losing the search results underneath.
                            InkWell(
                              onTap: () => setState(() => _cartExpanded = !_cartExpanded),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            _cartExpanded ? Icons.expand_less : Icons.expand_more,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.shopping_cart, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _cartExpanded
                                                  ? 'Cart (${saleProvider.itemCount})'
                                                  : 'Cart (${saleProvider.itemCount}) · tap to view',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${_currencyFormat.format(saleProvider.total)} TSh',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    InkWell(
                                      onTap: () => saleProvider.clearCart(),
                                      child: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Cart items (scrollable list) -- hidden while collapsed
                            if (_cartExpanded)
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                itemCount: saleProvider.cartItems.length,
                                itemBuilder: (context, idx) {
                                  final item = saleProvider.cartItems[idx];

                                  // Offer reward lines are read-only
                                  if (item.quantityOfferFree) {
                                    return _OfferFreeLineTile(
                                      item: item,
                                      isDark: isDark,
                                      onRemove: () => saleProvider.removeItem(idx),
                                    );
                                  }

                                  final discountLimit = item.discountLimit ?? 0;
                                  final hasOffer = saleProvider.hasQuantityOffer(item.itemId);
                                  final hasOneTimeDiscount = saleProvider.hasOneTimeDiscount(item.itemId);
                                  final hasPendingOTC = saleProvider.hasPendingOneTimeDiscount(item.itemId);
                                  final hasApprovedDiscount = saleProvider.hasApprovedDiscountRequest(item.itemId);
                                  final hasPendingApproved = saleProvider.hasPendingApprovedDiscount(item.itemId);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkCard : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: hasOneTimeDiscount || hasApprovedDiscount || (hasOffer && saleProvider.getQuantityOffer(item.itemId)!.calculateReward(item.quantity) > 0)
                                            ? AppColors.success.withValues(alpha: 0.5)
                                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Row 1: Name, qty controls, total, delete
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.itemName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  Text('@ ${_currencyFormat.format(item.unitPrice)} TSh', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                                ],
                                              ),
                                            ),
                                            InkWell(
                                              onTap: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is locked by approved discount request'), backgroundColor: AppColors.warning))
                                                  : () => saleProvider.decrementQuantity(idx),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.grey.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Icon(Icons.remove, size: 16, color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.grey : AppColors.error),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is locked by approved discount request'), backgroundColor: AppColors.warning))
                                                  // Redesign: quantity is a keypad bottom sheet with
                                                  // 1/5/10/25/50 presets, not a text dialog -- sellers
                                                  // mostly type 10, 25 or 50.
                                                  : () => _openQuantitySheet(saleProvider, idx),
                                              child: Container(
                                                constraints: const BoxConstraints(minWidth: 40),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                                decoration: BoxDecoration(
                                                  color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.blue.withValues(alpha: 0.08) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.blue.shade300 : (isDark ? Colors.grey.shade600 : Colors.grey.shade300)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (saleProvider.isQuantityLockedByApprovedDiscount(item.itemId))
                                                      Padding(padding: const EdgeInsets.only(right: 3), child: Icon(Icons.lock, size: 10, color: Colors.blue.shade400)),
                                                    Text(item.quantity.toStringAsFixed(0), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is locked by approved discount request'), backgroundColor: AppColors.warning))
                                                  : () => saleProvider.incrementQuantity(idx),
                                              child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.grey.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Icon(Icons.add, size: 16, color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.grey : AppColors.success)),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(width: 60, child: Text('${_currencyFormat.format(item.calculateTotal())}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                                            InkWell(onTap: () => saleProvider.removeItem(idx), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: AppColors.error))),
                                          ],
                                        ),
                                        // Row 2: Discount + Offer badges
                                        if (discountLimit > 0 || hasOffer || hasOneTimeDiscount || hasPendingOTC || hasApprovedDiscount || hasPendingApproved)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (discountLimit > 0)
                                                  InkWell(
                                                    onTap: () {
                                                      final discPerItem = item.discount > 0 ? (item.discount / item.quantity) : 0;
                                                      final controller = TextEditingController(text: discPerItem > 0 ? discPerItem.toStringAsFixed(0) : '');
                                                      showDialog(
                                                        context: context,
                                                        builder: (ctx) => AlertDialog(
                                                          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                                                          title: Text('Discount per item', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                                          content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Max: ${_currencyFormat.format(discountLimit)} TSh', style: TextStyle(fontSize: 12, color: AppColors.warning)), const SizedBox(height: 8), TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Discount (TSh)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))]),
                                                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () { var disc = double.tryParse(controller.text) ?? 0; if (disc > discountLimit) disc = discountLimit.toDouble(); saleProvider.updateDiscount(idx, disc * item.quantity, discountType: 1); Navigator.pop(ctx); }, child: const Text('Apply'))],
                                                        ),
                                                      );
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(color: item.discount > 0 ? AppColors.warning.withValues(alpha: 0.15) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200), borderRadius: BorderRadius.circular(4), border: Border.all(color: item.discount > 0 ? AppColors.warning : Colors.transparent)),
                                                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.discount, size: 12, color: item.discount > 0 ? AppColors.warning : Colors.grey), const SizedBox(width: 4), Text(item.discount > 0 ? '-${_currencyFormat.format(item.discount)}' : 'Disc', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: item.discount > 0 ? AppColors.warning : Colors.grey))]),
                                                    ),
                                                  ),
                                                if (hasOneTimeDiscount)
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_offer, size: 12, color: AppColors.success), const SizedBox(width: 4), Text('OTC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success))])),
                                                if (hasPendingOTC && !hasOneTimeDiscount)
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_offer_outlined, size: 12, color: AppColors.warning), const SizedBox(width: 4), Text('OTC: ${saleProvider.getOneTimeDiscountRequiredQty(item.itemId)?.toStringAsFixed(0) ?? "?"}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning))])),
                                                if (hasApprovedDiscount)
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 12, color: Colors.blue), const SizedBox(width: 4), Text('Approved', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue))])),
                                                if (hasPendingApproved && !hasApprovedDiscount)
                                                  Builder(builder: (context) {
                                                    final req = saleProvider.getApprovedDiscountRequest(item.itemId);
                                                    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_outlined, size: 12, color: Colors.blue.shade300), const SizedBox(width: 4), Text('Approved: ${req?.quantity?.toStringAsFixed(0) ?? "?"}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade300))]));
                                                  }),
                                                if (hasOffer)
                                                  Builder(builder: (context) {
                                                    final offer = saleProvider.getQuantityOffer(item.itemId)!;
                                                    final freeQty = offer.calculateReward(item.quantity);
                                                    final isEligible = freeQty > 0;
                                                    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isEligible ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isEligible ? Icons.card_giftcard : Icons.card_giftcard_outlined, size: 12, color: isEligible ? AppColors.success : AppColors.primary), const SizedBox(width: 4), Text(isEligible ? '+${freeQty.toStringAsFixed(0)} FREE' : 'Buy ${offer.purchaseQuantity.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isEligible ? AppColors.success : AppColors.primary))]));
                                                  }),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Search bar - disabled if no customer selected
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Consumer<SaleProvider>(
                    builder: (context, saleProvider, child) {
                      final hasCustomer = saleProvider.selectedCustomer != null;

                      return GestureDetector(
                        onTap: !hasCustomer ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please select a customer first'),
                              backgroundColor: AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'SELECT',
                                textColor: Colors.white,
                                onPressed: _selectCustomer,
                              ),
                            ),
                          );
                        } : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                          decoration: BoxDecoration(
                            color: hasCustomer
                                ? (isDark ? AppColors.darkCard : Colors.white)
                                : (isDark ? AppColors.darkCard.withValues(alpha: 0.5) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasCustomer
                                  ? AppColors.primary
                                  : AppColors.warning,
                              width: 1.5,
                            ),
                            boxShadow: hasCustomer ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _searchFocusNode.unfocus(),
                            // Tapping anywhere off the field also dismisses the keyboard
                            onTapOutside: (_) => _searchFocusNode.unfocus(),
                            enabled: hasCustomer,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: hasCustomer ? 'Search items by name or barcode...' : 'Select customer first',
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: hasCustomer
                                    ? (isDark ? Colors.grey.shade400 : Colors.grey.shade500)
                                    : AppColors.warning,
                              ),
                              prefixIcon: Container(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  hasCustomer ? Icons.search_rounded : Icons.person_add_outlined,
                                  size: 24,
                                  color: hasCustomer ? AppColors.primary : AppColors.warning,
                                ),
                              ),
                              suffixIcon: _buildSearchSuffix(isDark, hasCustomer),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                            onChanged: _filterItems,
                          ),
                              ),
                            ),
                            // Close control lives OUTSIDE the field on purpose: an
                            // IconButton inside InputDecoration.suffixIcon sits within
                            // the TextField's own tap target, so the tap re-focuses the
                            // field and the keyboard reopens the moment unfocus() runs.
                            if (_searchFocusNode.hasFocus || _searchController.text.isNotEmpty || _filteredItems.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: TextButton.icon(
                                  onPressed: _closeSearch,
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const Text(
                                    'Close',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    backgroundColor: AppColors.error.withValues(alpha: 0.08),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Search Results only.
                // Expanded greedily fills the space between the search field and the
                // action buttons, so the cart-summary / Add Payment + Complete block
                // is anchored to the bottom of the screen ("floats down"). When there
                // are results the list scrolls internally; when empty the area is just
                // blank space above the bottom-anchored buttons.
                Expanded(
                  child: Consumer<LocationProvider>(
                    builder: (context, locationProvider, child) {
                      // Fill the gap between search and the action bar with a hint
                      // instead of leaving a large blank area
                      if (_filteredItems.isEmpty) {
                        final bool searching = _searchController.text.isNotEmpty;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            // An expanded cart can leave this area short; scale the
                            // hint down rather than overflowing it
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  searching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                                  size: 40,
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  searching
                                      ? 'No items match "${_searchController.text}"'
                                      : 'Search by item name or barcode to add to the cart',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];

                          // Get stock quantity for selected location
                          final selectedLocation = locationProvider.selectedLocation;
                          double stockQty = 0;
                          String locationName = '';

                          if (selectedLocation != null && item.quantityByLocation != null) {
                            stockQty = item.quantityByLocation![selectedLocation.locationId] ?? 0;
                            locationName = selectedLocation.locationName;
                          } else {
                            stockQty = item.quantity ?? 0;
                            locationName = 'Total';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            color: isDark ? AppColors.darkCard : Colors.white,
                            elevation: isDark ? 2 : 1,
                            child: ListTile(
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Stock: ${stockQty.toStringAsFixed(0)} ($locationName) | Price: ${_currencyFormat.format(item.unitPrice)} TSh',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.add_shopping_cart,
                                  color: isDark ? AppColors.primary.withValues(alpha: 0.8) : AppColors.primary,
                                ),
                                onPressed: () => _addItemToCart(item),
                              ),
                              onTap: () => _addItemToCart(item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Cart summary and payments
                Consumer<SaleProvider>(
                  builder: (context, saleProvider, child) {
                    if (!saleProvider.hasItems) {
                      return const SizedBox.shrink();
                    }

                    final isLeruma = ApiService.currentClient?.features.hasInlineCartPreview ?? false;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      // Host Scaffold uses extendBody:false, so the body already sits
                      // ABOVE the bottom nav bar — no extra bottom padding needed.
                      // (The old 90px was dead space below the Add Payment/Complete row.)
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Total and items count - hide for Leruma (shown in cart above)
                          if (!isLeruma)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${saleProvider.itemCount} items',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${_currencyFormat.format(saleProvider.total)} TSh',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.primary.withValues(alpha: 0.9) : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),

                          // Payment list (if any)
                          if (saleProvider.hasPayments) ...[
                            if (!isLeruma) const SizedBox(height: 12),
                            if (!isLeruma) Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Payments',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${_currencyFormat.format(saleProvider.totalPayments)} TSh',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...saleProvider.payments.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final payment = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          payment.paymentType,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey.shade300 : Colors.grey[700],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${_currencyFormat.format(payment.amount)} TSh',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? Colors.grey.shade300 : Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => saleProvider.removePayment(index),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 8),
                                Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Amount Due',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${_currencyFormat.format(saleProvider.amountDue)} TSh',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: saleProvider.isFullyPaid ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],

                          if (!isLeruma) const SizedBox(height: 12),
                          // Action buttons.
                          //
                          // Leruma puts all three on ONE medium-height row: the cart
                          // summary already sits above the search field, so the old
                          // two-row block spent ~120px of a phone screen on chrome
                          // that the results list needs. Other clients keep the
                          // original two-row layout because they also show View Cart.
                          Builder(
                            builder: (context) {
                              final double buttonHeight = isLeruma ? 44 : 48;
                              final double labelSize = isLeruma ? 13 : 15;
                              final double iconSize = isLeruma ? 18 : 20;

                              final Widget suspendButton = PermissionWrapper(
                                permissionId: PermissionIds.salesSuspended,
                                child: SizedBox(
                                  height: buttonHeight,
                                  child: OutlinedButton.icon(
                                    onPressed: _isProcessing ? null : _suspendSale,
                                    icon: Icon(Icons.pause_circle_outline, size: isLeruma ? 16 : 18),
                                    label: Text(
                                      'Suspend',
                                      style: TextStyle(
                                        fontSize: isLeruma ? 12 : 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.warning,
                                      side: BorderSide(color: AppColors.warning, width: 1.5),
                                      padding: EdgeInsets.symmetric(horizontal: isLeruma ? 4 : 12),
                                    ),
                                  ),
                                ),
                              );

                              final Widget addPaymentButton = SizedBox(
                                height: buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: (_isProcessing || saleProvider.isFullyPaid)
                                      ? null
                                      : _addPayment,
                                  icon: Icon(Icons.add_card, size: iconSize),
                                  label: Text(
                                    isLeruma ? 'Payment' : 'Add Payment',
                                    style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: saleProvider.isFullyPaid
                                        ? Colors.grey
                                        : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: saleProvider.isFullyPaid ? 0 : 2,
                                    padding: EdgeInsets.symmetric(horizontal: isLeruma ? 4 : 12),
                                  ),
                                ),
                              );

                              final Widget completeButton = SizedBox(
                                height: buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: (_isProcessing || !saleProvider.isFullyPaid)
                                      ? null
                                      : _completeSale,
                                  icon: _isProcessing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          saleProvider.isFullyPaid
                                              ? Icons.check_circle
                                              : Icons.shopping_cart_checkout,
                                          size: iconSize,
                                        ),
                                  label: Text(
                                    'Complete',
                                    style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: saleProvider.isFullyPaid
                                        ? AppColors.success
                                        : Colors.grey.shade400,
                                    foregroundColor: Colors.white,
                                    elevation: saleProvider.isFullyPaid ? 2 : 0,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade600,
                                    padding: EdgeInsets.symmetric(horizontal: isLeruma ? 4 : 12),
                                  ),
                                ),
                              );

                              if (isLeruma) {
                                // Redesigned footer (design_handoff_sale_screen):
                                // subtotal, an order-discount row, the balance due,
                                // then Suspend + a single Charge action.
                                return _buildLerumaTotalsAndActions(saleProvider);
                              }

                              return Column(
                                children: [
                                  // Row 1: View Cart and Suspend
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => const CartScreen(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.shopping_cart, size: 18),
                                            label: const Text(
                                              'View Cart',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: AppColors.primary, width: 1.5),
                                              foregroundColor: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(flex: 2, child: suspendButton),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Row 2: Add Payment and Complete Sale
                                  Row(
                                    children: [
                                      Expanded(child: addPaymentButton),
                                      const SizedBox(width: 8),
                                      Expanded(child: completeButton),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
      // Bottom navigation is now handled by MainNavigation
    );
  }

  Widget _buildSkeletonGrid(bool isDark) {
    return Column(
      children: [
        // Search bar skeleton
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SkeletonLoader(
            width: double.infinity,
            height: 48,
            borderRadius: 12,
            isDark: isDark,
          ),
        ),
        // Items grid skeleton
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) => _buildSkeletonItemCard(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonItemCard(bool isDark) {
    return Card(
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonLoader(width: 50, height: 50, borderRadius: 8, isDark: isDark),
            const SizedBox(height: 8),
            SkeletonLoader(width: 60, height: 12, isDark: isDark),
            const SizedBox(height: 4),
            SkeletonLoader(width: 40, height: 14, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// Cart Screen
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Map<int, TextEditingController> _discountControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};

  @override
  void dispose() {
    for (var controller in _discountControllers.values) {
      controller.dispose();
    }
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: isDark ? AppColors.darkText : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<SaleProvider>().clearCart();
              Navigator.pop(context);
            },
            tooltip: 'Clear Cart',
          ),
        ],
      ),
      body: Consumer<SaleProvider>(
        builder: (context, saleProvider, child) {
          if (!saleProvider.hasItems) {
            return Center(
              child: Text(
                'Cart is empty',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: saleProvider.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = saleProvider.cartItems[index];

                    // Offer reward lines are read-only
                    if (item.quantityOfferFree) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _OfferFreeLineTile(
                          item: item,
                          isDark: isDark,
                          onRemove: () => saleProvider.removeItem(index),
                        ),
                      );
                    }

                    final discountLimit = item.discountLimit ?? 0;

                    // Initialize discount controller for this item. Keyed by item id,
                    // not row index: offer reward lines are inserted and removed as
                    // quantities change, so an index would drift onto another item.
                    if (!_discountControllers.containsKey(item.itemId)) {
                      // Show discount per item, not total
                      final discountPerItem = item.discount > 0 ? (item.discount / item.quantity) : 0;
                      _discountControllers[item.itemId] = TextEditingController(
                        text: discountPerItem > 0 ? discountPerItem.toStringAsFixed(0) : '',
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      color: isDark ? AppColors.darkCard : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDark ? AppColors.darkText : AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@ ${currencyFormat.format(item.unitPrice)} TSh',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                                        ),
                                      ),
                                      if (item.availableStock != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Stock: ${item.availableStock!.toStringAsFixed(0)} available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: item.availableStock! < item.quantity
                                                ? AppColors.error
                                                : item.availableStock! < item.quantity * 2
                                                    ? AppColors.warning
                                                    : AppColors.success,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      // Show "Discount Applied" when quantity meets requirement
                                      if (saleProvider.hasOneTimeDiscount(item.itemId)) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: AppColors.success.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.local_offer,
                                                size: 12,
                                                color: AppColors.success,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'One-time Discount Applied',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      // Show "Discount Available" when quantity NOT yet sufficient
                                      if (saleProvider.hasPendingOneTimeDiscount(item.itemId)) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: AppColors.warning.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.local_offer_outlined,
                                                size: 12,
                                                color: AppColors.warning,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Discount Available (needs ${saleProvider.getOneTimeDiscountRequiredQty(item.itemId)?.toStringAsFixed(0) ?? "?"} qty)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.warning,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      // Show "Approved Discount Applied" badge
                                      if (saleProvider.hasApprovedDiscountRequest(item.itemId)) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.blue.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified, size: 12, color: Colors.blue),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Approved Discount Applied',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      // Show "Approved Discount Available" when quantity not met
                                      if (saleProvider.hasPendingApprovedDiscount(item.itemId)) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.blue.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified_outlined, size: 12, color: Colors.blue.shade300),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Approved Discount (needs ${saleProvider.getApprovedDiscountRequest(item.itemId)?.quantity?.toStringAsFixed(0) ?? "?"} qty)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue.shade300,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (saleProvider.hasQuantityOffer(item.itemId)) ...[
                                        const SizedBox(height: 4),
                                        Builder(
                                          builder: (context) {
                                            final offer = saleProvider.getQuantityOffer(item.itemId)!;
                                            final freeQty = offer.calculateReward(item.quantity);
                                            final isEligible = freeQty > 0;
                                            final offerColor = isEligible ? AppColors.success : AppColors.primary;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: offerColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: offerColor.withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isEligible ? Icons.check_circle : Icons.card_giftcard,
                                                        size: 14,
                                                        color: offerColor,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        offer.offerDescription,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: offerColor,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (isEligible) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'You get ${freeQty.toStringAsFixed(0)} FREE!',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.success,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Need ${(offer.purchaseQuantity - item.quantity).toStringAsFixed(0)} more to qualify',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: offerColor.withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () => saleProvider.removeItem(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Quantity controls
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline,
                                        color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.grey.shade400 : null,
                                      ),
                                      onPressed: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is locked by approved discount request'), backgroundColor: AppColors.warning))
                                          : () => saleProvider.decrementQuantity(index),
                                    ),
                                    InkWell(
                                      onTap: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is locked by approved discount request'), backgroundColor: AppColors.warning))
                                          : () {
                                        // Show dialog to edit quantity
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            final controller = TextEditingController(
                                              text: item.quantity.toStringAsFixed(0),
                                            );
                                            return AlertDialog(
                                              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                                              title: Text(
                                                'Edit Quantity',
                                                style: TextStyle(
                                                  color: isDark ? AppColors.darkText : AppColors.text,
                                                ),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (item.availableStock != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 12),
                                                      child: Text(
                                                        'Available stock: ${item.availableStock!.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isDark ? AppColors.darkTextLight : Colors.grey[700],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  TextField(
                                                    controller: controller,
                                                    keyboardType: TextInputType.number,
                                                    autofocus: true,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Quantity',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final newQuantity = double.tryParse(controller.text) ?? 1;

                                                    // Validate quantity > 0
                                                    if (newQuantity <= 0) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Quantity must be greater than 0'),
                                                          backgroundColor: AppColors.error,
                                                        ),
                                                      );
                                                      return;
                                                    }

                                                    final isLerumaClient = ApiService.currentClient?.features.hasOutOfStockSelling ?? false;

                                                    // Validate against available stock (only for non-Leruma clients)
                                                    if (!isLerumaClient && item.availableStock != null && newQuantity > item.availableStock!) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Cannot exceed available stock of ${item.availableStock!.toStringAsFixed(0)}',
                                                          ),
                                                          backgroundColor: AppColors.error,
                                                          duration: const Duration(seconds: 3),
                                                        ),
                                                      );
                                                      return;
                                                    }

                                                    // Update quantity
                                                    saleProvider.updateQuantity(index, newQuantity);
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Update'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                                ? Colors.blue.shade300
                                                : (isDark
                                                    ? AppColors.darkTextLight.withOpacity(0.3)
                                                    : Colors.grey.shade300),
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                              ? Colors.blue.withOpacity(0.08)
                                              : (isDark
                                                  ? AppColors.darkBackground
                                                  : Colors.grey.shade50),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (saleProvider.isQuantityLockedByApprovedDiscount(item.itemId))
                                              Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Icon(Icons.lock, size: 14, color: Colors.blue.shade400),
                                              ),
                                            Text(
                                              '${item.quantity.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.darkText : AppColors.text,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline,
                                        color: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId) ? Colors.grey.shade400 : null,
                                      ),
                                      onPressed: saleProvider.isQuantityLockedByApprovedDiscount(item.itemId)
                                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is locked by approved discount request'), backgroundColor: AppColors.warning))
                                          : () {
                                        final isLerumaClient = ApiService.currentClient?.features.hasOutOfStockSelling ?? false;

                                        // Check if incrementing would exceed available stock (only for non-Leruma clients)
                                        if (!isLerumaClient &&
                                            item.availableStock != null &&
                                            item.quantity + 1 > item.availableStock!) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Cannot exceed available stock of ${item.availableStock!.toStringAsFixed(0)}',
                                              ),
                                              backgroundColor: AppColors.error,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                          saleProvider.incrementQuantity(index);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                // Price
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${currencyFormat.format(item.unitPrice * item.quantity)} TSh',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDark ? AppColors.darkTextLight : Colors.grey,
                                          decoration: item.discount > 0 ? TextDecoration.lineThrough : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.discount > 0) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${currencyFormat.format(item.calculateTotal())} TSh',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ] else
                                        Text(
                                          '${currencyFormat.format(item.calculateTotal())} TSh',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.darkText : AppColors.primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Only show discount field if item has discount limit
                            if (discountLimit > 0) ...[
                              const SizedBox(height: 8),
                              // Discount input
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _discountControllers[item.itemId],
                                      decoration: InputDecoration(
                                        labelText: 'Discount per item (TSh)',
                                        helperText: 'Limit: ${currencyFormat.format(discountLimit)} TSh',
                                        helperStyle: const TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 11,
                                        ),
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final discountPerItem = double.tryParse(value) ?? 0;

                                        // Validate against discount limit per item
                                        if (discountPerItem > discountLimit) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Discount cannot exceed ${currencyFormat.format(discountLimit)} TSh per item',
                                              ),
                                              backgroundColor: AppColors.error,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          _discountControllers[item.itemId]?.text = discountLimit.toString();
                                          // Total discount = discount per item × quantity
                                          saleProvider.updateDiscount(index, discountLimit.toDouble() * item.quantity, discountType: 1);
                                        } else {
                                          // Total discount = discount per item × quantity
                                          saleProvider.updateDiscount(index, discountPerItem * item.quantity, discountType: 1);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Cart summary
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal:',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(saleProvider.subtotal)} TSh',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    if (saleProvider.totalDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Discount:',
                            style: TextStyle(color: AppColors.error),
                          ),
                          Text(
                            '- ${currencyFormat.format(saleProvider.totalDiscount)} TSh',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ],
                    Divider(
                      height: 16,
                      color: isDark ? AppColors.darkTextLight.withOpacity(0.3) : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(saleProvider.total)} TSh',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Payment Dialog
class PaymentDialog extends StatefulWidget {
  final double total;
  final Customer? customer;
  final double? maxAmount; // Maximum allowed payment amount

  const PaymentDialog({
    super.key,
    required this.total,
    this.customer,
    this.maxAmount,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMethod = 'Cash';
  final TextEditingController _amountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  final ApiService _apiService = ApiService();

  // NFC Card wallet info
  NfcCardBalance? _nfcCardBalance;
  bool _isLoadingNfcBalance = false;
  String? _nfcError;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.total.toStringAsFixed(0);
    debugPrint('💳 PaymentDialog opened');
    debugPrint('💳 Customer: ${widget.customer?.displayName ?? "NULL"} (ID: ${widget.customer?.personId})');
    debugPrint('💳 Total: ${widget.total}');
    // Check if customer has NFC card and load balance
    _checkNfcCardBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkNfcCardBalance() async {
    debugPrint('🔍 _checkNfcCardBalance: Starting...');
    debugPrint('🔍 Customer: ${widget.customer?.displayName ?? "NULL"} (ID: ${widget.customer?.personId})');

    if (widget.customer == null) {
      debugPrint('🔍 _checkNfcCardBalance: No customer selected, returning');
      return;
    }

    // First get customer's cards to find linked NFC card
    debugPrint('🔍 _checkNfcCardBalance: Fetching cards for customer ${widget.customer!.personId}');
    final cardsResponse = await _apiService.getCustomerCards(widget.customer!.personId);

    debugPrint('🔍 _checkNfcCardBalance: Response success=${cardsResponse.isSuccess}, data=${cardsResponse.data?.length ?? 0} cards');

    if (!cardsResponse.isSuccess || cardsResponse.data == null || cardsResponse.data!.isEmpty) {
      debugPrint('🔍 _checkNfcCardBalance: No cards found or error: ${cardsResponse.message}');
      return;
    }

    // Get the first active card
    final card = cardsResponse.data!.first;
    debugPrint('🔍 _checkNfcCardBalance: Found card UID=${card.cardUid}, isActive=${card.isActive}');

    if (!card.isActive) {
      debugPrint('🔍 _checkNfcCardBalance: Card is not active, returning');
      return;
    }

    setState(() {
      _isLoadingNfcBalance = true;
      _nfcError = null;
    });

    debugPrint('🔍 _checkNfcCardBalance: Fetching balance for card ${card.cardUid}');
    final balanceResponse = await _apiService.getNfcCardBalance(card.cardUid);

    debugPrint('🔍 _checkNfcCardBalance: Balance response success=${balanceResponse.isSuccess}');

    if (mounted) {
      setState(() {
        _isLoadingNfcBalance = false;
        if (balanceResponse.isSuccess && balanceResponse.data != null) {
          _nfcCardBalance = balanceResponse.data;
          debugPrint('🔍 _checkNfcCardBalance: Balance loaded = ${_nfcCardBalance?.balance}, paymentEnabled=${_nfcCardBalance?.nfcPaymentEnabled}');
        } else {
          _nfcError = balanceResponse.message;
          debugPrint('🔍 _checkNfcCardBalance: Error loading balance: $_nfcError');
        }
      });
    }
  }

  Widget _buildCreditInfo() {
    if (_paymentMethod != 'Credit Card' || widget.customer == null) {
      return const SizedBox.shrink();
    }

    final customer = widget.customer!;
    final currentBalance = customer.balance;
    // A one-time credit limit is a higher ceiling granted for a single sale.
    // The web register checks it first and consumes it once used, so the
    // ceiling shown here has to be the one the sale will actually be judged
    // against -- otherwise the seller reads "limit exceeded" on a sale the
    // server would accept.
    final usesOneTime = customer.oneTimeCredit && customer.oneTimeCreditLimit > 0;
    final creditLimit =
        usesOneTime ? customer.oneTimeCreditLimit : customer.creditLimit;
    final availableCredit = creditLimit - currentBalance;
    final isAllowedCredit = customer.isAllowedCredit;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.credit_card,
                  size: 20,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Credit Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 12),
          _buildCreditInfoRow(
            'Credit Status',
            isAllowedCredit ? 'ACTIVE' : 'INACTIVE',
            isAllowedCredit ? AppColors.success : AppColors.error,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildCreditInfoRow(
            usesOneTime ? 'Credit Limit (one-time)' : 'Credit Limit',
            '${_currencyFormat.format(creditLimit)} TSh',
            usesOneTime
                ? AppColors.warning
                : (isDark ? Colors.white70 : Colors.grey.shade700),
            isDark,
          ),
          if (usesOneTime) ...[
            const SizedBox(height: 6),
            Text(
              'One-time limit applies to this sale only and is used up '
              'once the sale goes through. Standard limit: '
              '${_currencyFormat.format(customer.creditLimit)} TSh',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildCreditInfoRow(
            'Current Balance',
            '${_currencyFormat.format(currentBalance)} TSh',
            currentBalance > 0 ? Colors.orange : (isDark ? Colors.white70 : Colors.grey.shade700),
            isDark,
          ),
          const SizedBox(height: 10),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 10),
          _buildCreditInfoRow(
            'Available Credit',
            '${_currencyFormat.format(availableCredit)} TSh',
            availableCredit > 0 ? AppColors.success : AppColors.error,
            isDark,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditInfoRow(String label, String value, Color valueColor, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNfcCardInfo() {
    if (_paymentMethod != 'NFC Card') {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.customer == null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Please select a customer to use NFC Card payment',
                style: TextStyle(color: isDark ? Colors.orange[300] : AppColors.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingNfcBalance) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_nfcCardBalance == null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _nfcError ?? 'Customer has no NFC card linked',
                style: TextStyle(color: isDark ? Colors.red[300] : AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final balance = _nfcCardBalance!;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final hasSufficientBalance = balance.balance >= amount;
    final statusColor = hasSufficientBalance ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.nfc,
                  size: 20,
                  color: isDark ? Colors.orange[300] : Colors.orange[700],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'NFC Wallet Balance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.orange[800],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : statusColor.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 12),
          _buildCreditInfoRow(
            'Available Balance',
            '${_currencyFormat.format(balance.balance)} TSh',
            hasSufficientBalance ? AppColors.success : AppColors.error,
            isDark,
            isHighlight: true,
          ),
          const SizedBox(height: 10),
          _buildCreditInfoRow(
            'Total Deposited',
            '${_currencyFormat.format(balance.totalDeposited)} TSh',
            isDark ? Colors.white70 : Colors.grey.shade700,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildCreditInfoRow(
            'Total Spent',
            '${_currencyFormat.format(balance.totalSpent)} TSh',
            isDark ? Colors.white70 : Colors.grey.shade700,
            isDark,
          ),
          if (!hasSufficientBalance) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: isDark ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insufficient balance! Need ${_currencyFormat.format(amount - balance.balance)} TSh more',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _validatePayment() {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount <= 0) {
      return 'Invalid amount';
    }

    // Validate amount doesn't exceed maximum (amount due)
    if (widget.maxAmount != null && amount > widget.maxAmount!) {
      return 'Amount cannot exceed ${_currencyFormat.format(widget.maxAmount)} TSh (amount due)';
    }

    // Validate credit card payment
    if (_paymentMethod == 'Credit Card' && widget.customer != null) {
      final customer = widget.customer!;

      // Check if customer is allowed credit
      if (!customer.isAllowedCredit) {
        return 'Customer is not allowed to make credit purchases.\nPlease pay with cash.';
      }

      // Check credit limit, one-time ceiling first -- same order as the web
      // register and api/Sales.php.
      final currentBalance = customer.balance;
      final usesOneTime =
          customer.oneTimeCredit && customer.oneTimeCreditLimit > 0;
      final creditLimit =
          usesOneTime ? customer.oneTimeCreditLimit : customer.creditLimit;
      final availableCredit = creditLimit - currentBalance;

      if (amount > availableCredit) {
        return 'Credit limit exceeded!\n'
            '${usesOneTime ? 'One-time limit' : 'Available credit'}: '
            '${_currencyFormat.format(availableCredit)} TSh\n'
            'Requested: ${_currencyFormat.format(amount)} TSh';
      }
    }

    // Validate NFC Card payment
    if (_paymentMethod == 'NFC Card') {
      debugPrint('🔍 Validating NFC Card payment...');
      debugPrint('🔍 Customer: ${widget.customer?.displayName ?? "NULL"}');
      debugPrint('🔍 NFC Balance object: $_nfcCardBalance');
      debugPrint('🔍 NFC Error: $_nfcError');

      if (widget.customer == null) {
        debugPrint('❌ Validation failed: No customer selected');
        return 'Please select a customer to use NFC Card payment';
      }

      if (_nfcCardBalance == null) {
        debugPrint('❌ Validation failed: _nfcCardBalance is null');
        debugPrint('❌ This means: No cards found OR card not active OR balance fetch failed');
        return 'Customer has no NFC card linked or wallet not enabled';
      }

      debugPrint('🔍 NFC Balance: ${_nfcCardBalance!.balance}');
      debugPrint('🔍 NFC Payment Enabled: ${_nfcCardBalance!.nfcPaymentEnabled}');

      if (!_nfcCardBalance!.nfcPaymentEnabled) {
        debugPrint('❌ Validation failed: NFC payment not enabled for customer');
        return 'NFC wallet payment is not enabled for this customer';
      }

      if (_nfcCardBalance!.balance < amount) {
        debugPrint('❌ Validation failed: Insufficient balance (${_nfcCardBalance!.balance} < $amount)');
        return 'Insufficient NFC wallet balance!\n'
            'Available: ${_currencyFormat.format(_nfcCardBalance!.balance)} TSh\n'
            'Requested: ${_currencyFormat.format(amount)} TSh';
      }

      debugPrint('✅ NFC Card validation passed');
    }

    return null; // Valid
  }

  @override
  Widget build(BuildContext context) {
    final permissionProvider = context.watch<PermissionProvider>();
    final hasNfcPaymentPermission = permissionProvider.hasPermission(PermissionIds.nfcPayment);
    final hasNfcCard = ApiService.currentClient?.features.hasNfcCard ?? false;

    return AlertDialog(
      title: const Text('Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: [
                const DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                const DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
                // LIPA NAMBA - hidden for Leruma and SADA
                if (ApiService.currentClient?.id != 'leruma' && ApiService.currentClient?.id != 'sada')
                  const DropdownMenuItem(value: 'LIPA NAMBA', child: Text('LIPA NAMBA')),
                // NFC Card payment - requires hasNfcCard feature, hidden for Leruma
                if (ApiService.currentClient?.id != 'leruma' && hasNfcCard && hasNfcPaymentPermission && (_nfcCardBalance != null || widget.customer != null))
                  const DropdownMenuItem(
                    value: 'NFC Card',
                    child: Row(
                      children: [
                        Icon(Icons.nfc, size: 18),
                        SizedBox(width: 8),
                        Text('NFC Card'),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                debugPrint('💳 Payment method changed to: $value');
                debugPrint('💳 Customer: ${widget.customer?.displayName ?? "NULL"}');
                debugPrint('💳 NFC Card Balance: ${_nfcCardBalance?.balance ?? "NULL"}');
                debugPrint('💳 NFC Payment Enabled: ${_nfcCardBalance?.nfcPaymentEnabled ?? "NULL"}');
                debugPrint('💳 NFC Error: $_nfcError');
                setState(() => _paymentMethod = value!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                suffixText: 'TSh',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Trigger rebuild to update NFC balance display
                setState(() {});
              },
            ),
            _buildCreditInfo(),
            _buildNfcCardInfo(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final validationError = _validatePayment();
            if (validationError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(validationError),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }

            final amount = double.tryParse(_amountController.text) ?? 0;
            Navigator.pop(context,
              SalePayment(paymentType: _paymentMethod, amount: amount),
            );
          },
          child: const Text('Add Payment'),
        ),
      ],
    );
  }
}

// Customer Selection Dialog
class CustomerSelectionDialog extends StatefulWidget {
  const CustomerSelectionDialog({super.key});

  @override
  State<CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  final ApiService _apiService = ApiService();
  final NfcService _nfcService = NfcService();
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = false;
  bool _nfcAvailable = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    if (mounted) {
      setState(() => _nfcAvailable = isAvailable);
    }
  }

  Future<void> _scanNfcCard() async {
    final result = await showDialog<NfcScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NfcScanDialog(lookupCustomer: true),
    );

    if (result != null && result.success && mounted) {
      if (result.customer != null) {
        // Customer found - select them
        context.read<SaleProvider>().setCustomer(result.customer!);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.nfc, color: Colors.white),
                const SizedBox(width: 8),
                Text('Customer: ${result.customer!.firstName} ${result.customer!.lastName}'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Card scanned but no customer linked
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Card ${result.cardUid} is not linked to any customer'),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Register',
              textColor: Colors.white,
              onPressed: () => _showRegisterCardPrompt(result.cardUid!),
            ),
          ),
        );
      }
    }
  }

  void _showRegisterCardPrompt(String cardUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register Card'),
        content: const Text('Select a customer from the list to register this card.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerCardToCustomer(Customer customer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NfcRegisterCardDialog(customer: customer),
    );

    if (result == true && mounted) {
      // Card registered successfully - optionally select the customer
      final shouldSelect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Card Registered'),
          content: Text('Select ${customer.firstName} ${customer.lastName} for this sale?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (shouldSelect == true && mounted) {
        context.read<SaleProvider>().setCustomer(customer);
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Check if customers should be filtered by location (Leruma feature)
  bool _hasCustomersByLocationFeature() {
    try {
      // Leruma clients filter customers by stock location's supervisor
      return ApiService.currentClient?.features.hasSuppliersByLocation ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    final connectivityProvider = context.read<ConnectivityProvider>();
    final offlineProvider = context.read<OfflineProvider>();

    // For Leruma: filter customers by selected location's supervisor
    int? locationId;
    if (_hasCustomersByLocationFeature()) {
      final locationProvider = context.read<LocationProvider>();
      locationId = locationProvider.selectedLocation?.locationId;
    }

    // Check if offline AND offline mode is initialized (enabled for this client)
    if (!connectivityProvider.isOnline && offlineProvider.isInitialized) {
      debugPrint('📴 Loading customers from offline database');
      final offlineCustomers = await offlineProvider.getOfflineCustomers(limit: 100);

      if (offlineCustomers.isNotEmpty) {
        setState(() {
          _customers = offlineCustomers.map((data) => Customer.fromJson(data)).toList();
          _filteredCustomers = _customers;
          _isLoading = false;
        });
        return;
      }
    }

    // Online - fetch from API
    final response = await _apiService.getCustomers(
      limit: 100,
      locationId: locationId,
    );

    if (response.isSuccess && response.data != null) {
      setState(() {
        _customers = response.data!;
        _filteredCustomers = _customers;
        _isLoading = false;
      });
    } else {
      // Fallback to offline only for clients that have offline mode enabled
      final offlineCustomers = offlineProvider.isInitialized
          ? await offlineProvider.getOfflineCustomers(limit: 100)
          : const <Map<String, dynamic>>[];

      if (offlineCustomers.isNotEmpty) {
        setState(() {
          _customers = offlineCustomers.map((data) => Customer.fromJson(data)).toList();
          _filteredCustomers = _customers;
          _isLoading = false;
        });
        debugPrint('📴 Loaded ${_customers.length} customers from offline (API fallback)');
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  void _filterCustomers(String query) {
    // Immediate local filter for responsiveness
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers
            .where((customer) =>
                customer.firstName.toLowerCase().contains(query.toLowerCase()) ||
                customer.lastName.toLowerCase().contains(query.toLowerCase()) ||
                (customer.phoneNumber?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });

    // Debounced server-side search for customers beyond initial 100
    _debounce?.cancel();
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _searchCustomersFromApi(query);
      });
    }
  }

  Future<void> _searchCustomersFromApi(String query) async {
    final connectivityProvider = context.read<ConnectivityProvider>();
    if (!connectivityProvider.isOnline) return;

    // Must carry the same location filter as _loadCustomers: the API maps
    // location_id to that location's supervisor and filters on it. Without it a
    // search returned every supervisor's customers and merged them into the
    // list, so searching quietly widened what the seller could reach.
    int? locationId;
    if (_hasCustomersByLocationFeature()) {
      final locationProvider = context.read<LocationProvider>();
      locationId = locationProvider.selectedLocation?.locationId;
    }

    final response = await _apiService.getCustomers(
      search: query,
      limit: 50,
      locationId: locationId,
    );

    if (response.isSuccess && response.data != null && mounted) {
      final apiResults = response.data!;
      // Merge with local results, avoiding duplicates
      final existingIds = _filteredCustomers.map((c) => c.personId).toSet();
      final newCustomers = apiResults.where((c) => !existingIds.contains(c.personId)).toList();

      if (newCustomers.isNotEmpty) {
        setState(() {
          _filteredCustomers = [..._filteredCustomers, ...newCustomers];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // NFC Scan Button
                    if (_nfcAvailable)
                      IconButton(
                        icon: const Icon(Icons.nfc, color: AppColors.primary),
                        onPressed: _scanNfcCard,
                        tooltip: 'Scan NFC Card',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // NFC hint for first-time users
            if (_nfcAvailable)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.nfc, size: 18, color: AppColors.primary.withOpacity(0.8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap NFC card or search below',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Search bar
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _filterCustomers('');
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _filterCustomers(value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Customers list
            Expanded(
              child: _isLoading
                  ? _buildCustomerSkeletonList()
                  : _filteredCustomers.isEmpty
                      ? const Center(child: Text('No customers found'))
                      : ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    customer.firstName[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  '${customer.firstName} ${customer.lastName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (customer.phoneNumber != null)
                                      Text(customer.phoneNumber!),
                                    if (customer.balance != null && customer.balance != 0)
                                      Text(
                                        'Balance: ${NumberFormat('#,###').format(customer.balance)} TSh',
                                        style: TextStyle(
                                          color: customer.balance! > 0
                                              ? AppColors.error
                                              : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: _nfcAvailable
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.nfc,
                                          color: Colors.grey[400],
                                        ),
                                        onPressed: () => _registerCardToCustomer(customer),
                                        tooltip: 'Register NFC card',
                                      )
                                    : null,
                                onTap: () {
                                  context.read<SaleProvider>().setCustomer(customer);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Customer: ${customer.firstName} ${customer.lastName}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSkeletonList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) => _buildCustomerSkeletonCard(),
    );
  }

  Widget _buildCustomerSkeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar skeleton
            const SkeletonLoader(
              width: 40,
              height: 40,
              borderRadius: 20,
              isDark: true,
            ),
            const SizedBox(width: 12),
            // Text content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonLoader(
                    width: 150,
                    height: 16,
                    borderRadius: 4,
                    isDark: true,
                  ),
                  SizedBox(height: 6),
                  SkeletonLoader(
                    width: 100,
                    height: 12,
                    borderRadius: 4,
                    isDark: true,
                  ),
                  SizedBox(height: 4),
                  SkeletonLoader(
                    width: 80,
                    height: 12,
                    borderRadius: 4,
                    isDark: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cart tile for a line the system added as an offer reward.
///
/// Reward lines are derived from the paid line's quantity, so they expose no
/// quantity, price or discount controls -- only a remove action, which declines
/// the offer. Mirrors the web's zero-priced free line.
class _OfferFreeLineTile extends StatelessWidget {
  final SaleItem item;
  final bool isDark;
  final VoidCallback onRemove;

  const _OfferFreeLineTile({
    required this.item,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null)
                  Text(
                    item.description!,
                    style: TextStyle(fontSize: 10, color: AppColors.success),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.quantity.toStringAsFixed(0)} × FREE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          InkWell(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
