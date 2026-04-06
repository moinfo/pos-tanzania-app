import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/api_response.dart';
import '../models/stock_location.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class CreateTransferScreen extends StatefulWidget {
  const CreateTransferScreen({super.key});

  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  final _apiService = ApiService();
  final _qtyController = TextEditingController();

  bool _loadingInit = true;
  bool _loadingInventory = false;
  bool _submitting = false;
  String? _error;

  List<StockLocation> _locations = [];
  List<Map<String, dynamic>> _items = [];

  StockLocation? _selectedLocation;
  Map<String, dynamic>? _selectedItem;
  Map<String, dynamic>? _inventory; // parent + child inventory details

  @override
  void initState() {
    super.initState();
    _loadInit();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  // Load locations and items in parallel
  Future<void> _loadInit() async {
    setState(() {
      _loadingInit = true;
      _error = null;
    });

    final results = await Future.wait([
      _apiService.getAllStockLocations(),
      _apiService.getTransferItems(),
    ]);

    if (!mounted) return;

    final locResult = results[0] as ApiResponse<List<StockLocation>>;
    final itemResult = results[1] as ApiResponse<List<Map<String, dynamic>>>;

    if (!locResult.isSuccess) {
      setState(() {
        _error = locResult.message ?? 'Failed to load locations';
        _loadingInit = false;
      });
      return;
    }

    setState(() {
      _locations = locResult.data ?? [];
      _items = (itemResult.data ?? []);
      if (_locations.isNotEmpty) _selectedLocation = _locations.first;
      _loadingInit = false;
    });
  }

  Future<void> _loadInventory() async {
    if (_selectedItem == null || _selectedLocation == null) return;

    setState(() {
      _loadingInventory = true;
      _inventory = null;
      _qtyController.clear();
    });

    final result = await _apiService.getTransferInventory(
      _selectedItem!['item_id'] as int,
      _selectedLocation!.locationId,
    );

    if (!mounted) return;

    setState(() {
      _loadingInventory = false;
      if (result.isSuccess) {
        _inventory = result.data;
      } else {
        _showSnack(result.message ?? 'Failed to load inventory', isError: true);
      }
    });
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      _showSnack('Enter a valid quantity', isError: true);
      return;
    }

    if (_inventory == null || !(_inventory!['prices_match'] as bool? ?? false)) {
      _showSnack('Price mismatch — cannot transfer', isError: true);
      return;
    }

    final parent = _inventory!['parent'] as Map<String, dynamic>;
    final currentStock = (parent['current_stock'] as num?)?.toDouble() ?? 0;
    if (qty > currentStock) {
      _showSnack(
          'Only ${currentStock % 1 == 0 ? currentStock.toInt() : currentStock} CTN available',
          isError: true);
      return;
    }

    setState(() => _submitting = true);

    final result = await _apiService.createTransfer(
      itemId: _selectedItem!['item_id'] as int,
      stockId: _selectedLocation!.locationId,
      quantity: qty,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isSuccess) {
      final data = result.data!;
      final recvId = data['receiving_id'];
      final srcQty = (data['source']?['quantity'] as num?)?.toDouble() ?? qty;
      final destQty = (data['destination']?['quantity'] as num?)?.toDouble() ?? 0;
      final destName = data['destination']?['name'] ?? '';

      _showSuccessDialog(recvId, srcQty, destQty, destName);
    } else {
      _showSnack(result.message ?? 'Transfer failed', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _showSuccessDialog(dynamic recvId, double srcQty, double destQty, String destName) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Transfer #$recvId Complete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${srcQty % 1 == 0 ? srcQty.toInt() : srcQty} CTN → '
              '${destQty % 1 == 0 ? destQty.toInt() : destQty} PC\n$destName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context, true); // screen → signals reload
            },
            child: const Text('Done',
                style: TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        title: Text(
          'New Transfer',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppColors.darkText : AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loadingInit
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoNote(isDark),
                      const SizedBox(height: 16),
                      _buildLocationPicker(isDark),
                      const SizedBox(height: 12),
                      _buildItemPicker(isDark),
                      if (_loadingInventory) ...[
                        const SizedBox(height: 24),
                        const Center(child: CircularProgressIndicator()),
                      ] else if (_inventory != null) ...[
                        const SizedBox(height: 20),
                        _buildInventoryPanel(isDark),
                        const SizedBox(height: 20),
                        _buildQuantityInput(isDark),
                        const SizedBox(height: 24),
                        _buildSubmitButton(isDark),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadInit, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildInfoNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.info, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Transfer converts wholesale cartons (CTN) to retail units (PC) within the same location.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText : AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Stock Location', isDark),
        const SizedBox(height: 6),
        Container(
          decoration: _dropdownDecoration(isDark),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<StockLocation>(
              value: _selectedLocation,
              isExpanded: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              dropdownColor: isDark ? AppColors.darkCard : Colors.white,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkText : AppColors.text),
              hint: Text('Select location',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight)),
              items: _locations
                  .map((l) => DropdownMenuItem(
                        value: l,
                        child: Text(l.locationName),
                      ))
                  .toList(),
              onChanged: (loc) {
                setState(() {
                  _selectedLocation = loc;
                  _inventory = null;
                  _qtyController.clear();
                });
                if (_selectedItem != null) _loadInventory();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Item (Wholesale / CTN)', isDark),
        const SizedBox(height: 6),
        Container(
          decoration: _dropdownDecoration(isDark),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              value: _selectedItem,
              isExpanded: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              dropdownColor: isDark ? AppColors.darkCard : Colors.white,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkText : AppColors.text),
              hint: Text('Select item',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight)),
              items: _items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item['name'] as String? ?? ''),
                      ))
                  .toList(),
              onChanged: (item) {
                setState(() {
                  _selectedItem = item;
                  _inventory = null;
                  _qtyController.clear();
                });
                _loadInventory();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryPanel(bool isDark) {
    final parent = _inventory!['parent'] as Map<String, dynamic>;
    final child = _inventory!['child'] as Map<String, dynamic>;
    final pricesMatch = _inventory!['prices_match'] as bool? ?? false;
    final check = _inventory!['price_check'] as Map<String, dynamic>? ?? {};

    final ctnStock = (parent['current_stock'] as num?)?.toDouble() ?? 0;
    final pcStock = (child['current_stock'] as num?)?.toDouble() ?? 0;
    final ctnSize = (parent['ctn_size'] as num?)?.toDouble() ?? 0;
    final ctnPrice = (parent['cost_price'] as num?)?.toDouble() ?? 0;
    final pcPrice = (child['cost_price'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price match status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (pricesMatch ? AppColors.success : AppColors.error)
                .withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (pricesMatch ? AppColors.success : AppColors.error)
                  .withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                pricesMatch
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                size: 18,
                color: pricesMatch ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pricesMatch
                      ? 'Prices match — ${_fmt(ctnPrice)} = ${_fmt(pcPrice)} × ${_fmtQty(ctnSize)}'
                      : 'Price mismatch: ${_fmt(ctnPrice)} ≠ ${_fmt(pcPrice)} × ${_fmtQty(ctnSize)} = ${_fmt((check['expected_ctn_price'] as num?)?.toDouble() ?? 0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: pricesMatch ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Source ←→ Destination cards
        Row(
          children: [
            Expanded(
              child: _stockCard(
                label: 'Source (CTN)',
                name: parent['name'] as String? ?? '',
                stock: ctnStock,
                price: ctnPrice,
                ctnSize: null,
                color: AppColors.brandPrimary,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded,
                  color: AppColors.brandPrimary, size: 24),
            ),
            Expanded(
              child: _stockCard(
                label: 'Destination (PC)',
                name: child['name'] as String? ?? '',
                stock: pcStock,
                price: pcPrice,
                ctnSize: ctnSize,
                color: AppColors.success,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stockCard({
    required String label,
    required String name,
    required double stock,
    required double price,
    required double? ctnSize,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          _infoRow('Stock', '${_fmtQty(stock)} ${ctnSize == null ? "CTN" : "PC"}', isDark),
          _infoRow('Price', _fmt(price), isDark),
          if (ctnSize != null)
            _infoRow('CTN size', '${_fmtQty(ctnSize)} PC', isDark),
        ],
      ),
    );
  }

  Widget _infoRow(String key, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextLight
                      : AppColors.textLight)),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.text)),
        ],
      ),
    );
  }

  Widget _buildQuantityInput(bool isDark) {
    final parent = _inventory!['parent'] as Map<String, dynamic>;
    final ctnSize = (parent['ctn_size'] as num?)?.toDouble() ?? 1;
    final child = _inventory!['child'] as Map<String, dynamic>;
    final childName = child['name'] as String? ?? '';
    final pricesMatch = _inventory!['prices_match'] as bool? ?? false;

    // Live calculation of PCs
    final qtyText = _qtyController.text.trim();
    final qty = double.tryParse(qtyText) ?? 0;
    final pcs = qty * ctnSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Quantity to Transfer (CTN)', isDark),
        const SizedBox(height: 6),
        TextField(
          controller: _qtyController,
          enabled: pricesMatch,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: pricesMatch
                ? 'e.g. 5'
                : 'Fix price mismatch to enable',
            hintStyle: TextStyle(
                color: isDark
                    ? AppColors.darkTextLight
                    : AppColors.textLight),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppColors.brandPrimary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            suffixText: 'CTN',
          ),
          style: TextStyle(
              color: isDark ? AppColors.darkText : AppColors.text,
              fontSize: 15),
        ),
        if (pricesMatch && pcs > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_fmtQty(qty)} CTN  →  ${_fmtQty(pcs)} PC ($childName)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final pricesMatch = _inventory?['prices_match'] as bool? ?? false;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    final canSubmit = pricesMatch && qty > 0 && !_submitting;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: (isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider)
              .withOpacity(0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.swap_horiz_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Transfer Stock',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
      ),
    );
  }

  BoxDecoration _dropdownDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
    );
  }

  String _fmt(double v) =>
      'TZS ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _fmtQty(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();
}
