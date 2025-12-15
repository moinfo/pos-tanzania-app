import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';

import 'package:intl/intl.dart';
import '../../models/receiving.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/skeleton_loader.dart';

class ReceivingDetailsScreen extends StatefulWidget {
  final int receivingId;

  const ReceivingDetailsScreen({
    super.key,
    required this.receivingId,
  });

  @override
  State<ReceivingDetailsScreen> createState() => _ReceivingDetailsScreenState();
}

class _ReceivingDetailsScreenState extends State<ReceivingDetailsScreen> {
  final ApiService _apiService = ApiService();

  ReceivingDetails? _receiving;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReceivingDetails();
  }

  Future<void> _loadReceivingDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getReceivingDetails(widget.receivingId);

      if (response.isSuccess && response.data != null) {
        setState(() {
          _receiving = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load receiving details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Delete functionality commented out for future use
  // Future<void> _deleteReceiving() async {
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete Receiving'),
  //       content: const Text(
  //         'Are you sure you want to delete this receiving?\n\n'
  //         'This will reverse the inventory changes (decrease stock).',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: AppColors.error,
  //           ),
  //           child: const Text('Delete'),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   if (confirmed != true) return;
  //
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     final response = await _apiService.deleteReceiving(widget.receivingId);
  //
  //     if (response.isSuccess) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('Receiving deleted successfully'),
  //             backgroundColor: AppColors.success,
  //           ),
  //         );
  //         Navigator.pop(context, true);
  //       }
  //     } else {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(response.message ?? 'Failed to delete receiving'),
  //             backgroundColor: AppColors.error,
  //           ),
  //         );
  //         setState(() => _isLoading = false);
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error: $e'),
  //           backgroundColor: AppColors.error,
  //         ),
  //       );
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '${formatter.format(amount)} TSh';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Receiving #${widget.receivingId}'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.success,
        foregroundColor: Colors.white,
        // Delete functionality commented out for future use
        // actions: [
        //   if (_receiving != null)
        //     IconButton(
        //       icon: const Icon(Icons.delete_outline),
        //       onPressed: _deleteReceiving,
        //       tooltip: 'Delete Receiving',
        //     ),
        // ],
      ),
      body: _isLoading
          ? _buildSkeletonContent(isDark)
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadReceivingDetails,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _receiving == null
                  ? const Center(child: Text('No data'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header info
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: isDark ? AppColors.darkSurface : AppColors.primary,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(_receiving!.receivingTime),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.business,
                                        color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Supplier: ',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _receiving!.supplierName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.payment,
                                        color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Payment Type: ',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      _receiving!.paymentType,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_receiving!.reference.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    icon: Icons.receipt_long,
                                    label: 'Reference',
                                    value: _receiving!.reference,
                                  ),
                                ],
                                if (_receiving!.comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    icon: Icons.comment,
                                    label: 'Comment',
                                    value: _receiving!.comment,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Items list
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Items Received (${_receiving!.items.length})',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkText : AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._receiving!.items.map((item) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.itemName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? AppColors.darkText : AppColors.text,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(item.lineTotal),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (item.itemNumber.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4),
                                              child: Text(
                                                'Item #${item.itemNumber}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? AppColors.darkTextLight : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildItemDetail(
                                                'Quantity',
                                                item.quantity
                                                    .toStringAsFixed(0),
                                                isDark,
                                              ),
                                              const SizedBox(width: 16),
                                              _buildItemDetail(
                                                'Cost Price',
                                                _formatCurrency(
                                                    item.costPrice),
                                                isDark,
                                              ),
                                              const SizedBox(width: 16),
                                              _buildItemDetail(
                                                'Unit Price',
                                                _formatCurrency(
                                                    item.unitPrice),
                                                isDark,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),

                          // Total
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Cost',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(_receiving!.total),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white70,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemDetail(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkText : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLoader(width: 100, height: 20, isDark: isDark),
                      SkeletonLoader(width: 70, height: 24, borderRadius: 4, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 60, height: 10, isDark: isDark),
                            const SizedBox(height: 4),
                            SkeletonLoader(width: 100, height: 14, isDark: isDark),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 60, height: 10, isDark: isDark),
                            const SizedBox(height: 4),
                            SkeletonLoader(width: 80, height: 14, isDark: isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Items skeleton
          Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 80, height: 16, isDark: isDark),
                  const SizedBox(height: 16),
                  ...List.generate(4, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonLoader(width: 120, height: 14, isDark: isDark),
                              const SizedBox(height: 4),
                              SkeletonLoader(width: 80, height: 12, isDark: isDark),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SkeletonLoader(width: 50, height: 12, isDark: isDark),
                              const SizedBox(height: 4),
                              SkeletonLoader(width: 70, height: 14, isDark: isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
