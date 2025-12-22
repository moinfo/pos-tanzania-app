import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/suspended_summary.dart';
import '../models/stock_location.dart';
import '../models/item_comment.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../widgets/skeleton_loader.dart';

/// Suspended Items Summary Screen
/// Aggregates all items from all suspended sales
class SuspendedSummaryScreen extends StatefulWidget {
  const SuspendedSummaryScreen({super.key});

  @override
  State<SuspendedSummaryScreen> createState() => _SuspendedSummaryScreenState();
}

class _SuspendedSummaryScreenState extends State<SuspendedSummaryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  final NumberFormat _decimalFormat = NumberFormat('#,##0.00', 'en_US');

  List<SuspendedSummaryItem> _items = [];
  List<SuspendedSummaryItem> _filteredItems = [];
  SuspendedSummaryTotals? _totals;
  bool _isLoading = true;
  String? _error;

  // Store comments for each item (key: itemId_locationId)
  final Map<String, ItemComment?> _comments = {};

  // Use app brand colors
  static const Color _headerColor = AppColors.primary;
  static const Color _headerColorDark = AppColors.primaryDark;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items.where((item) {
          return item.itemName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final locationProvider = context.read<LocationProvider>();
    final locationId = locationProvider.selectedLocation?.locationId;

    if (locationId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No location selected';
      });
      return;
    }

    final response = await _apiService.getSuspendedSummary(locationId: locationId);

    if (response.isSuccess && response.data != null) {
      setState(() {
        _items = response.data!.items;
        _totals = response.data!.totals;
        _isLoading = false;
      });
      _filterItems();
      // Load comments for all items
      _loadAllComments();
    } else {
      setState(() {
        _isLoading = false;
        _error = response.message;
      });
    }
  }

  Future<void> _loadAllComments() async {
    for (final item in _items) {
      _loadComment(item.itemId, item.locationId);
    }
  }

  Future<void> _loadComment(int itemId, int locationId) async {
    final key = '${itemId}_$locationId';
    final response = await _apiService.getItemComment(
      itemId: itemId,
      locationId: locationId,
    );

    if (response.isSuccess && response.data != null) {
      setState(() {
        _comments[key] = response.data!.comment;
      });
    }
  }

  void _showCommentDialog(SuspendedSummaryItem item) {
    showDialog(
      context: context,
      builder: (context) => _CommentDialog(
        itemId: item.itemId,
        locationId: item.locationId,
        itemName: item.itemName,
        apiService: _apiService,
        onCommentSaved: (comment) {
          setState(() {
            _comments['${item.itemId}_${item.locationId}'] = comment;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
        title: const Text('Summary', style: TextStyle(fontSize: 18)),
        actions: [
          // Location selector
          if (locationProvider.allowedLocations.isNotEmpty &&
              locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        locationProvider.selectedLocation!.locationName,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadData();
                  },
                  itemBuilder: (context) => locationProvider.allowedLocations
                      .map((location) => PopupMenuItem<StockLocation>(
                            value: location,
                            child: Row(
                              children: [
                                Icon(
                                  location.locationId ==
                                          locationProvider.selectedLocation?.locationId
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: location.locationId ==
                                          locationProvider.selectedLocation?.locationId
                                      ? _headerColor
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    return Column(
      children: [
        // Search Bar and Totals
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search item name...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 18,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Summary totals row
              if (_totals != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 16, color: _headerColor),
                        const SizedBox(width: 4),
                        Text(
                          '${_filteredItems.length} items',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.monetization_on, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${_currencyFormat.format(_totals!.grandTotal)} TSh',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? _buildSkeletonList(isDark)
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(_error!,
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _headerColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.summarize_outlined,
                                  size: 64,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No items found'
                                    : 'No suspended items',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: _headerColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredItems.length + 1, // +1 for totals
                            itemBuilder: (context, index) {
                              if (index == _filteredItems.length) {
                                return _buildTotalsCard(isDark);
                              }
                              return _buildItemCard(
                                  _filteredItems[index], index + 1, isDark);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildItemCard(SuspendedSummaryItem item, int number, bool isDark) {
    final commentKey = '${item.itemId}_${item.locationId}';
    final comment = _comments[commentKey];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDark ? 2 : 3,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with number, item name, and action button
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _headerColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.itemName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action button for comment
                IconButton(
                  icon: Icon(
                    comment != null ? Icons.comment : Icons.add_comment_outlined,
                    color: comment != null ? _headerColor : Colors.grey,
                    size: 22,
                  ),
                  onPressed: () => _showCommentDialog(item),
                  tooltip: 'Add/Edit Comment',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Data grid
            Row(
              children: [
                Expanded(
                  child: _buildDataItem(
                    'Suspended',
                    _currencyFormat.format(item.suspendedQuantity),
                    Colors.blue,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildDataItem(
                    'Bonge',
                    _currencyFormat.format(item.bongeQuantity),
                    Colors.purple,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildDataItem(
                    'Diff',
                    _currencyFormat.format(item.difference),
                    item.difference > 0 ? Colors.orange : Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDataItem(
                    'Total Amount',
                    '${_currencyFormat.format(item.totalAmount)} TSh',
                    Colors.green,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildDataItem(
                    'Weight',
                    '${_decimalFormat.format(item.weight)} kg',
                    Colors.grey,
                    isDark,
                  ),
                ),
              ],
            ),
            // Comment row (if exists)
            if (comment != null && comment.comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Comment',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          comment.commentDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.comment,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(bool isDark) {
    if (_totals == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 3,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _headerColor, width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _headerColor.withOpacity(0.1),
              _headerColorDark.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: _headerColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Grand Totals',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTotalItem(
                    'Items',
                    '${_totals!.itemCount}',
                    Icons.inventory_2,
                    Colors.blue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTotalItem(
                    'Total Qty',
                    _currencyFormat.format(_totals!.totalQuantity),
                    Icons.numbers,
                    Colors.purple,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTotalItem(
                    'Grand Total',
                    '${_currencyFormat.format(_totals!.grandTotal)} TSh',
                    Icons.monetization_on,
                    Colors.green,
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTotalItem(
                    'Total Weight',
                    '${_decimalFormat.format(_totals!.totalWeight)} kg',
                    Icons.scale,
                    Colors.orange,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: isDark ? AppColors.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonLoader(
                      width: 28, height: 28, borderRadius: 14, isDark: isDark),
                  const SizedBox(width: 10),
                  SkeletonLoader(
                      width: 150, height: 16, borderRadius: 4, isDark: isDark),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: SkeletonLoader(
                          width: double.infinity,
                          height: 40,
                          borderRadius: 6,
                          isDark: isDark)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: SkeletonLoader(
                          width: double.infinity,
                          height: 40,
                          borderRadius: 6,
                          isDark: isDark)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: SkeletonLoader(
                          width: double.infinity,
                          height: 40,
                          borderRadius: 6,
                          isDark: isDark)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comment Dialog for adding/editing comments
class _CommentDialog extends StatefulWidget {
  final int itemId;
  final int locationId;
  final String itemName;
  final ApiService apiService;
  final Function(ItemComment?) onCommentSaved;

  const _CommentDialog({
    required this.itemId,
    required this.locationId,
    required this.itemName,
    required this.apiService,
    required this.onCommentSaved,
  });

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  List<CommentHistoryItem> _history = [];
  ItemComment? _currentComment;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadComment();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadComment() async {
    final response = await widget.apiService.getItemComment(
      itemId: widget.itemId,
      locationId: widget.locationId,
    );

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _currentComment = response.data!.comment;
        _history = response.data!.history;

        if (_currentComment != null) {
          _commentController.text = _currentComment!.comment;
          _dateController.text = _currentComment!.commentDate;
        }
      }
    });
  }

  Future<void> _saveComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final response = await widget.apiService.saveItemComment(
      itemId: widget.itemId,
      locationId: widget.locationId,
      comment: _commentController.text.trim(),
      commentDate: _dateController.text,
      commentId: _currentComment?.id,
    );

    setState(() => _isSaving = false);

    if (response.isSuccess && response.data != null) {
      widget.onCommentSaved(response.data!.comment);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteComment() async {
    if (_currentComment?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    final response = await widget.apiService.deleteItemComment(
      commentId: _currentComment!.id!,
    );

    setState(() => _isSaving = false);

    if (response.isSuccess) {
      widget.onCommentSaved(null);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item Comment',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.itemName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date field
                          TextField(
                            controller: _dateController,
                            readOnly: true,
                            onTap: _selectDate,
                            decoration: InputDecoration(
                              labelText: 'Date',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Comment field
                          TextField(
                            controller: _commentController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Comment',
                              alignLabelWithHint: true,
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 50),
                                child: Icon(Icons.message),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              if (_currentComment?.id != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSaving ? null : _deleteComment,
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                ),
                              if (_currentComment?.id != null) const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _saveComment,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: Text(_isSaving ? 'Saving...' : 'Save'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Comment History
                          if (_history.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.history, size: 18, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Comment History',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _history.length,
                              itemBuilder: (context, index) {
                                final item = _history[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.fullName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            item.createdAt ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.comment,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Date: ${item.commentDate}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
