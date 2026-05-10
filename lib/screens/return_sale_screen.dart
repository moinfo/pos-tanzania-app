import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/skeleton_loader.dart';

class ReturnSaleScreen extends StatefulWidget {
  final int saleId;

  const ReturnSaleScreen({super.key, required this.saleId});

  @override
  State<ReturnSaleScreen> createState() => _ReturnSaleScreenState();
}

class _ReturnSaleScreenState extends State<ReturnSaleScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  ReturnModalData? _modalData;
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;

  // line → qty to return (only non-zero entries matter)
  final Map<int, int> _selectedQty = {};

  @override
  void initState() {
    super.initState();
    _loadReturnData();
  }

  Future<void> _loadReturnData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getReturnModalData(widget.saleId);

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _modalData = response.data;
        // Default all returnable items to 0
        for (final item in _modalData!.items) {
          if (!item.quantityOfferFree && item.remainingQty > 0) {
            _selectedQty[item.line] = 0;
          }
        }
      } else {
        _errorMessage = response.message;
      }
    });
  }

  // Returnable items only (exclude free offer items)
  List<ReturnableItem> get _returnableItems =>
      _modalData?.items.where((i) => !i.quantityOfferFree && i.remainingQty > 0).toList() ?? [];

  bool get _hasSelection => _selectedQty.values.any((q) => q > 0);

  double get _estimatedRefund {
    if (_modalData == null) return 0;
    double total = 0;
    for (final item in _returnableItems) {
      final qty = _selectedQty[item.line] ?? 0;
      if (qty > 0 && item.quantity > 0) {
        total += (qty / item.quantity) * item.lineTotal;
      }
    }
    return total;
  }

  void _setQty(int line, int qty, int max) {
    setState(() => _selectedQty[line] = qty.clamp(0, max));
  }

  Future<void> _processReturn() async {
    final lines = Map<int, int>.from(_selectedQty)
      ..removeWhere((_, v) => v == 0);

    if (lines.isEmpty) return;

    setState(() => _isProcessing = true);

    final response = await _apiService.processReturn(
      saleId: widget.saleId,
      lines: lines,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      _showSuccessDialog(response.data!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(ReturnResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Return Processed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Return Sale #', '${result.returnSaleId}'),
            _resultRow('Items Returned', '${result.itemsReturned}'),
            const Divider(height: 24),
            Text(
              'Refund Breakdown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...result.refundPayments.map((p) {
              final amount = (p['payment_amount'] as num).toDouble().abs();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p['payment_type'] as String,
                        style: const TextStyle(fontSize: 14)),
                    Text(
                      '${_currencyFormat.format(amount)} TSh',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Refund',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${_currencyFormat.format(result.refundTotal)} TSh',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close return screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return — Sale #${widget.saleId}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _errorMessage != null
              ? _buildError()
              : _modalData == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _buildCustomerBanner(),
                        if (_modalData!.hasAnyReturn)
                          _buildPartialReturnBanner(),
                        Expanded(child: _buildItemList()),
                        _buildBottomBar(),
                      ],
                    ),
    );
  }

  Widget _buildCustomerBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            _modalData!.customerName,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          const Spacer(),
          Text(
            'Original sale #${widget.saleId}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialReturnBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          SizedBox(width: 8),
          Text(
            'Some items have already been returned. Only remaining quantities are shown.',
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    final items = _returnableItems;

    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
            SizedBox(height: 16),
            Text('All items have already been returned.',
                style: TextStyle(fontSize: 16, color: AppColors.success)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index]),
    );
  }

  Widget _buildItemCard(ReturnableItem item) {
    final selectedQty = _selectedQty[item.line] ?? 0;
    final maxQty = item.remainingQty.toInt();
    final isSelected = selectedQty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.error.withOpacity(0.06)
            : Colors.white,
        border: Border.all(
          color: isSelected
              ? AppColors.error.withOpacity(0.4)
              : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity.toStringAsFixed(0)} sold  ·  '
                        '${_currencyFormat.format(item.price)} TSh each',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (item.alreadyReturned > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${item.alreadyReturned.toStringAsFixed(0)} already returned',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.warning),
                          ),
                        ),
                    ],
                  ),
                ),
                // Line total
                Text(
                  '${_currencyFormat.format(item.lineTotal)} TSh',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Return qty  (max $maxQty):',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const Spacer(),
                _QtyStepper(
                  value: selectedQty,
                  max: maxQty,
                  onDecrement: () => _setQty(item.line, selectedQty - 1, maxQty),
                  onIncrement: () => _setQty(item.line, selectedQty + 1, maxQty),
                  onEdit: (v) => _setQty(item.line, v, maxQty),
                ),
              ],
            ),
            // Estimated refund for this item
            if (isSelected) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Est. refund: ${_currencyFormat.format((selectedQty / item.quantity) * item.lineTotal)} TSh',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, -3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Refund',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(
                '${_currencyFormat.format(_estimatedRefund)} TSh',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _hasSelection && !_isProcessing ? _processReturn : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.undo),
              label: Text(_isProcessing ? 'Processing...' : 'Process Return'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadReturnData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(width: 180, height: 16, isDark: false),
              const SizedBox(height: 8),
              SkeletonLoader(width: 120, height: 12, isDark: false),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SkeletonLoader(width: 120, height: 36, borderRadius: 8, isDark: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact quantity stepper widget
class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<int> onEdit;

  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          color: value > 0 ? AppColors.error : Colors.grey.shade300,
          onTap: value > 0 ? onDecrement : null,
        ),
        GestureDetector(
          onTap: () => _showEditDialog(context),
          child: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(
              '$value',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          color: value < max ? AppColors.primary : Colors.grey.shade300,
          onTap: value < max ? onIncrement : null,
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: '$value');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '0 – $max'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 0;
              onEdit(v);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
