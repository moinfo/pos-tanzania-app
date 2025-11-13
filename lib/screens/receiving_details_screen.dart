import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receiving.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ReceivingDetailsScreen extends StatefulWidget {
  final int receivingId;

  const ReceivingDetailsScreen({
    Key? key,
    required this.receivingId,
  }) : super(key: key);

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

    final response = await _apiService.getReceivingDetails(widget.receivingId);

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _receiving = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receiving #${widget.receivingId}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReceivingDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _receiving == null
                  ? const Center(child: Text('No receiving details found'))
                  : Column(
                      children: [
                        _buildReceivingInfo(),
                        const Divider(height: 1, thickness: 2),
                        Expanded(child: _buildItemsList()),
                        const Divider(height: 1, thickness: 2),
                        _buildSummary(),
                      ],
                    ),
    );
  }

  Widget _buildReceivingInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _receiving!.supplierName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Date',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _receiving!.receivingTime,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment Type',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _receiving!.paymentType,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_receiving!.reference.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Reference',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _receiving!.reference,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
            if (_receiving!.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Comment',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _receiving!.comment,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      itemCount: _receiving!.items.length,
      itemBuilder: (context, index) {
        final item = _receiving!.items[index];
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
                if (item.itemNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Item #: ${item.itemNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
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
                '${_receiving!.items.length}',
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
                '${NumberFormat('#,###').format(_receiving!.total)} TSh',
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
}
