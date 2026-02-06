import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/discount_request.dart';
import '../models/customer.dart';
import '../models/item.dart';
import '../models/permission_model.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class DiscountRequestsScreen extends StatefulWidget {
  const DiscountRequestsScreen({super.key});

  @override
  State<DiscountRequestsScreen> createState() => _DiscountRequestsScreenState();
}

class _DiscountRequestsScreenState extends State<DiscountRequestsScreen> {
  final ApiService _apiService = ApiService();
  final currencyFormat = NumberFormat('#,##0', 'en_US');
  List<DiscountRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getDiscountRequests(
      status: _statusFilter,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _requests = response.data!.requests;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'used':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'used':
        return Icons.shopping_cart_checkout;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM, HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _approveRequest(DiscountRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Discount Request'),
        content: Text(
          'Approve discount of TSh ${currencyFormat.format(request.discount)} '
          'for ${request.itemName} (Qty: ${request.quantity.toStringAsFixed(0)})?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.approveDiscountRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.isSuccess ? 'Request approved' : response.message),
            backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
          ),
        );
        if (response.isSuccess) _loadRequests();
      }
    }
  }

  Future<void> _rejectRequest(DiscountRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Discount Request'),
        content: Text('Reject discount request for ${request.itemName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.rejectDiscountRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.isSuccess ? 'Request rejected' : response.message),
            backgroundColor: response.isSuccess ? AppColors.warning : AppColors.error,
          ),
        );
        if (response.isSuccess) _loadRequests();
      }
    }
  }

  Future<void> _deleteRequest(DiscountRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Discount Request'),
        content: Text('Delete discount request for ${request.itemName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteDiscountRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.isSuccess ? 'Request deleted' : response.message),
            backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
          ),
        );
        if (response.isSuccess) _loadRequests();
      }
    }
  }

  void _showEditDialog(DiscountRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditDiscountRequestSheet(
        request: request,
        onUpdated: _loadRequests,
      ),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CreateDiscountRequestSheet(
        onCreated: _loadRequests,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final canAdd = permissionProvider.hasPermission(PermissionIds.customerDiscountRequestsAdd);
    final canApprove = permissionProvider.hasPermission(PermissionIds.customerDiscountRequestsApprove);
    final canReject = permissionProvider.hasPermission(PermissionIds.customerDiscountRequestsReject);
    final canEdit = permissionProvider.hasPermission(PermissionIds.customerDiscountRequestsEdit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.customerDiscountRequestsDelete);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Discount Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Search + filters section
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by item or customer...',
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextLight : Colors.grey[400], size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText, fontSize: 14),
                  onChanged: (value) => _searchQuery = value,
                  onSubmitted: (_) => _loadRequests(),
                ),
                const SizedBox(height: 10),

                // Status filter chips
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All', null, isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Pending', 'pending', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Approved', 'approved', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Rejected', 'rejected', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Used', 'used', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, style: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[600]), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _loadRequests,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _requests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 56, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  _statusFilter != null
                                      ? 'No ${_statusFilter} requests'
                                      : 'No discount requests yet',
                                  style: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[500], fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRequests,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final request = _requests[index];
                                return _buildRequestCard(request, canApprove, canReject, canDelete, canEdit, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status, bool isDark) {
    final isSelected = _statusFilter == status;
    final statusCol = status != null ? _statusColor(status) : AppColors.primary;

    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = status);
        _loadRequests();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? statusCol.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.darkCard : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? statusCol : (isDark ? AppColors.darkDivider : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? statusCol : (isDark ? AppColors.darkTextLight : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(DiscountRequest request, bool canApprove, bool canReject, bool canDelete, bool canEdit, bool isDark) {
    final statusCol = _statusColor(request.status);
    final totalDiscount = request.discount * request.quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status color bar
              Container(width: 4, color: statusCol),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Item name + Status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.itemName ?? 'Item #${request.itemId}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusCol.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(request.status), size: 12, color: statusCol),
                                const SizedBox(width: 3),
                                Text(
                                  request.status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusCol,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Customer name + phone
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: isDark ? AppColors.darkTextLight : Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              request.customerName ?? 'Customer #${request.customerId}',
                              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (request.customerPhone != null && request.customerPhone!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              request.customerPhone!,
                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : Colors.grey[500]),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => launchUrl(Uri.parse('tel:${request.customerPhone}'), mode: LaunchMode.externalApplication),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.call, size: 16, color: AppColors.success),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Discount info - using Wrap to prevent overflow
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _infoTag(
                            'Qty: ${request.quantity.toStringAsFixed(0)}',
                            AppColors.info,
                            isDark,
                          ),
                          _infoTag(
                            'Disc: ${currencyFormat.format(request.discount)} /unit',
                            AppColors.success,
                            isDark,
                          ),
                          _infoTag(
                            'Total: TSh ${currencyFormat.format(totalDiscount)}',
                            AppColors.primary,
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Footer: Requested by + date
                      Row(
                        children: [
                          Icon(Icons.edit_note, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              request.requestedByName ?? '-',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.access_time, size: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(
                            _formatDate(request.createdAt),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          ),
                        ],
                      ),

                      // Action buttons for pending requests
                      if (request.isPending && (canApprove || canReject || canDelete || canEdit)) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade200)),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                if (canDelete)
                                  _actionButton(
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    color: Colors.grey,
                                    isDark: isDark,
                                    onTap: () => _deleteRequest(request),
                                  ),
                                if (canEdit)
                                  _actionButton(
                                    icon: Icons.edit_outlined,
                                    label: 'Edit',
                                    color: AppColors.info,
                                    isDark: isDark,
                                    onTap: () => _showEditDialog(request),
                                  ),
                                if (canReject)
                                  _actionButton(
                                    icon: Icons.close,
                                    label: 'Reject',
                                    color: AppColors.error,
                                    isDark: isDark,
                                    onTap: () => _rejectRequest(request),
                                  ),
                                if (canApprove)
                                  _actionButton(
                                    icon: Icons.check,
                                    label: 'Approve',
                                    color: AppColors.success,
                                    isDark: isDark,
                                    filled: true,
                                    onTap: () => _approveRequest(request),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Show approved/used info
                      if (request.isApproved || request.isUsed) ...[
                        if (request.approvedByName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 12, color: AppColors.success.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                'Approved by ${request.approvedByName}',
                                style: TextStyle(fontSize: 11, color: AppColors.success.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    if (filled) {
      return Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: color.withValues(alpha: isDark ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Create Discount Request Bottom Sheet ====================

class _CreateDiscountRequestSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateDiscountRequestSheet({required this.onCreated});

  @override
  State<_CreateDiscountRequestSheet> createState() => _CreateDiscountRequestSheetState();
}

class _CreateDiscountRequestSheetState extends State<_CreateDiscountRequestSheet> {
  final ApiService _apiService = ApiService();
  final currencyFormat = NumberFormat('#,##0', 'en_US');

  // Form state
  Customer? _selectedCustomer;
  Item? _selectedItem;
  final _quantityController = TextEditingController(text: '1');
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();

  // Search state
  List<Customer> _customers = [];
  List<Item> _items = [];
  bool _searchingCustomers = false;
  bool _searchingItems = false;

  // Item price info
  ItemPricesResponse? _itemPrices;
  bool _loadingPrices = false;

  bool _isSubmitting = false;

  Future<void> _searchCustomers(String query) async {
    if (query.length < 2) return;
    setState(() => _searchingCustomers = true);

    final response = await _apiService.getCustomers(search: query, limit: 10);
    if (mounted) {
      setState(() {
        _searchingCustomers = false;
        if (response.isSuccess && response.data != null) {
          _customers = response.data!;
        }
      });
    }
  }

  Future<void> _searchItems(String query) async {
    if (query.length < 2) return;
    setState(() => _searchingItems = true);

    final locationId = 1; // Default location
    final response = await _apiService.getItems(search: query, limit: 10, locationId: locationId);
    if (mounted) {
      setState(() {
        _searchingItems = false;
        if (response.isSuccess && response.data != null) {
          _items = response.data!;
        }
      });
    }
  }

  Future<void> _loadItemPrices(int itemId) async {
    setState(() => _loadingPrices = true);

    final response = await _apiService.getItemPrices(itemId);
    if (mounted) {
      setState(() {
        _loadingPrices = false;
        if (response.isSuccess && response.data != null) {
          _itemPrices = response.data;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null || _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select customer and item'), backgroundColor: AppColors.error),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;

    if (quantity <= 0 || discount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity and discount must be greater than 0'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Validate against max discount
    if (_itemPrices != null && discount > _itemPrices!.maxDiscount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discount cannot exceed TSh ${currencyFormat.format(_itemPrices!.maxDiscount)}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final response = await _apiService.createDiscountRequest(
      customerId: _selectedCustomer!.personId,
      itemId: _selectedItem!.itemId,
      quantity: quantity,
      discount: discount,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (response.isSuccess) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount request created'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Discount Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 20),

              // Customer search
              _sectionLabel('Customer', isDark),
              const SizedBox(height: 6),
              if (_selectedCustomer != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedCustomer = null),
                        child: Icon(Icons.close, size: 18, color: isDark ? AppColors.darkTextLight : Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Autocomplete<Customer>(
                  optionsBuilder: (textEditingValue) async {
                    if (textEditingValue.text.length < 2) return [];
                    await _searchCustomers(textEditingValue.text);
                    return _customers;
                  },
                  displayStringForOption: (c) => '${c.firstName} ${c.lastName}',
                  onSelected: (c) => setState(() => _selectedCustomer = c),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return _buildSearchField(
                      controller: controller,
                      focusNode: focusNode,
                      hint: 'Search customer...',
                      icon: Icons.person_search,
                      isLoading: _searchingCustomers,
                      isDark: isDark,
                    );
                  },
                ),
              const SizedBox(height: 16),

              // Item search
              _sectionLabel('Item', isDark),
              const SizedBox(height: 6),
              if (_selectedItem != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedItem!.name,
                          style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedItem = null;
                          _itemPrices = null;
                        }),
                        child: Icon(Icons.close, size: 18, color: isDark ? AppColors.darkTextLight : Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Autocomplete<Item>(
                  optionsBuilder: (textEditingValue) async {
                    if (textEditingValue.text.length < 2) return [];
                    await _searchItems(textEditingValue.text);
                    return _items;
                  },
                  displayStringForOption: (i) => i.name,
                  onSelected: (i) {
                    setState(() => _selectedItem = i);
                    _loadItemPrices(i.itemId);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return _buildSearchField(
                      controller: controller,
                      focusNode: focusNode,
                      hint: 'Search item...',
                      icon: Icons.search,
                      isLoading: _searchingItems,
                      isDark: isDark,
                    );
                  },
                ),

              // Price info
              if (_loadingPrices)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
              if (_itemPrices != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkAccent : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _priceItem('Selling', currencyFormat.format(_itemPrices!.sellingPrice), AppColors.info, isDark),
                          _priceItem('Cost', currencyFormat.format(_itemPrices!.costPrice), AppColors.warning, isDark),
                          _priceItem('Max Disc', currencyFormat.format(_itemPrices!.maxDiscount), AppColors.success, isDark),
                        ],
                      ),
                      if (_itemPrices!.isSembe) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 13, color: AppColors.info.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Sembe category - can sell at cost',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Quantity + Discount
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _quantityController,
                      label: 'Quantity',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      controller: _discountController,
                      label: 'Discount (TSh)',
                      helper: _itemPrices != null ? 'Max: ${currencyFormat.format(_itemPrices!.maxDiscount)}' : null,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Notes
              _buildInputField(
                controller: _notesController,
                label: 'Notes (optional)',
                isDark: isDark,
                maxLines: 2,
                isNumber: false,
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: isDark ? AppColors.darkTextLight : Colors.grey[700],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required bool isLoading,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: isDark ? AppColors.darkTextLight : Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        isDense: true,
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              )
            : null,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    String? helper,
    int maxLines = 1,
    bool isNumber = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[500], fontSize: 13),
        helperText: helper,
        helperStyle: TextStyle(fontSize: 11, color: AppColors.warning),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _priceItem(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextLight : Colors.grey[500])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ==================== Edit Discount Request Bottom Sheet ====================

class _EditDiscountRequestSheet extends StatefulWidget {
  final DiscountRequest request;
  final VoidCallback onUpdated;

  const _EditDiscountRequestSheet({required this.request, required this.onUpdated});

  @override
  State<_EditDiscountRequestSheet> createState() => _EditDiscountRequestSheetState();
}

class _EditDiscountRequestSheetState extends State<_EditDiscountRequestSheet> {
  final ApiService _apiService = ApiService();
  final currencyFormat = NumberFormat('#,##0', 'en_US');

  late final TextEditingController _quantityController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  ItemPricesResponse? _itemPrices;
  bool _loadingPrices = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.request.quantity.toStringAsFixed(0));
    _discountController = TextEditingController(text: widget.request.discount.toStringAsFixed(0));
    _notesController = TextEditingController(text: widget.request.notes ?? '');
    _loadItemPrices();
  }

  Future<void> _loadItemPrices() async {
    setState(() => _loadingPrices = true);
    final response = await _apiService.getItemPrices(widget.request.itemId);
    if (mounted) {
      setState(() {
        _loadingPrices = false;
        if (response.isSuccess && response.data != null) {
          _itemPrices = response.data;
        }
      });
    }
  }

  Future<void> _submit() async {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;

    if (quantity <= 0 || discount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity and discount must be greater than 0'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_itemPrices != null && discount > _itemPrices!.maxDiscount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discount cannot exceed TSh ${currencyFormat.format(_itemPrices!.maxDiscount)}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final response = await _apiService.updateDiscountRequest(
      id: widget.request.id,
      quantity: quantity,
      discount: discount,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (response.isSuccess) {
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount request updated'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit Discount Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 20),

              // Customer (read-only)
              _readOnlyField(
                icon: Icons.person,
                label: 'Customer',
                value: widget.request.customerName ?? 'Customer #${widget.request.customerId}',
                color: AppColors.info,
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              // Item (read-only)
              _readOnlyField(
                icon: Icons.inventory_2,
                label: 'Item',
                value: widget.request.itemName ?? 'Item #${widget.request.itemId}',
                color: AppColors.success,
                isDark: isDark,
              ),

              // Price info
              if (_loadingPrices)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
              if (_itemPrices != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkAccent : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _priceItem('Selling', currencyFormat.format(_itemPrices!.sellingPrice), AppColors.info, isDark),
                          _priceItem('Cost', currencyFormat.format(_itemPrices!.costPrice), AppColors.warning, isDark),
                          _priceItem('Max Disc', currencyFormat.format(_itemPrices!.maxDiscount), AppColors.success, isDark),
                        ],
                      ),
                      if (_itemPrices!.isSembe) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 13, color: AppColors.info.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Sembe category - can sell at cost',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Quantity + Discount (editable)
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _quantityController,
                      label: 'Quantity',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      controller: _discountController,
                      label: 'Discount (TSh)',
                      helper: _itemPrices != null ? 'Max: ${currencyFormat.format(_itemPrices!.maxDiscount)}' : null,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Notes
              _buildInputField(
                controller: _notesController,
                label: 'Notes (optional)',
                isDark: isDark,
                maxLines: 2,
                isNumber: false,
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppColors.darkTextLight : Colors.grey[700])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                ),
              ),
              Icon(Icons.lock_outline, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    String? helper,
    int maxLines = 1,
    bool isNumber = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[500], fontSize: 13),
        helperText: helper,
        helperStyle: const TextStyle(fontSize: 11, color: AppColors.warning),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _priceItem(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextLight : Colors.grey[500])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
