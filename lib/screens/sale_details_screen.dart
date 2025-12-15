import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/skeleton_loader.dart';

class SaleDetailsScreen extends StatefulWidget {
  final int saleId;

  const SaleDetailsScreen({
    super.key,
    required this.saleId,
  });

  @override
  State<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends State<SaleDetailsScreen> {
  final ApiService _apiService = ApiService();

  Sale? _saleDetails;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSaleDetails();
  }

  Future<void> _loadSaleDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getSaleDetails(widget.saleId);

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _saleDetails = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sale #${widget.saleId}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? _buildSkeletonContent()
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSaleDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _saleDetails == null
                  ? const Center(child: Text('No sale details found'))
                  : Column(
                      children: [
                        _buildSaleInfo(),
                        const Divider(height: 1, thickness: 2),
                        Expanded(child: _buildItemsList()),
                        const Divider(height: 1, thickness: 2),
                        _buildSummary(),
                      ],
                    ),
    );
  }

  Widget _buildSaleInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sale Date',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, y HH:mm')
                  .format(DateTime.parse(_saleDetails!.saleTime)),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      itemCount: _saleDetails!.items?.length ?? 0,
      itemBuilder: (context, index) {
        final item = _saleDetails!.items![index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantity: ${item.quantity.toInt()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${NumberFormat('#,###').format(item.unitPrice)} TSh',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (item.discount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Discount: ${NumberFormat('#,###').format(item.discount)} TSh',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,###').format(item.lineTotal)} TSh',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Items',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_saleDetails!.items?.length ?? 0}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${NumberFormat('#,###').format(_saleDetails!.total)} TSh',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLoader(width: 100, height: 16, isDark: false),
                      SkeletonLoader(width: 80, height: 20, borderRadius: 4, isDark: false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SkeletonLoader(width: 150, height: 12, isDark: false),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 120, height: 12, isDark: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Items skeleton
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 80, height: 16, isDark: false),
                  const SizedBox(height: 12),
                  ...List.generate(4, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonLoader(width: 120, height: 14, isDark: false),
                              const SizedBox(height: 4),
                              SkeletonLoader(width: 80, height: 12, isDark: false),
                            ],
                          ),
                        ),
                        SkeletonLoader(width: 70, height: 14, isDark: false),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Total skeleton
          SkeletonLoader(width: double.infinity, height: 80, borderRadius: 8, isDark: false),
        ],
      ),
    );
  }
}
