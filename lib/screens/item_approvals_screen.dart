import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/item_approval.dart';
import '../models/permission_model.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

/// Review queue for item add/edit/inventory changes staged by employees who
/// lack the `items_approve` grant. The list endpoint returns pending rows
/// only, so there is no status filter here -- once acted on, a row leaves.
class ItemApprovalsScreen extends StatefulWidget {
  const ItemApprovalsScreen({super.key});

  @override
  State<ItemApprovalsScreen> createState() => _ItemApprovalsScreenState();
}

class _ItemApprovalsScreenState extends State<ItemApprovalsScreen> {
  final ApiService _apiService = ApiService();
  List<ItemApproval> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

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

    final response = await _apiService.getItemApprovals();

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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return DateFormat('dd MMM, HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  IconData _typeIcon(ItemApproval r) {
    if (r.isAdd) return Icons.add_box_outlined;
    if (r.isInventory) return Icons.inventory_outlined;
    return Icons.edit_outlined;
  }

  Color _typeColor(ItemApproval r) {
    if (r.isAdd) return AppColors.success;
    if (r.isInventory) return AppColors.info;
    return AppColors.warning;
  }

  Future<void> _openDetail(ItemApproval summary) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApprovalDetailSheet(requestId: summary.requestId),
    );

    // Acted on (approved/rejected) -- the row is no longer pending.
    if (changed == true) {
      _loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Item Approvals'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRequests,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _requests.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Icon(Icons.inbox_outlined,
                              size: 56, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'Nothing waiting for approval',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextLight : Colors.grey[500],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) => _buildCard(_requests[i], isDark),
                      ),
                    ),
    );
  }

  Widget _buildCard(ItemApproval r, bool isDark) {
    final color = _typeColor(r);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(r),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(r), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${r.changeTypeLabel} · ${r.requesterName ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(r.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextLight : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail + act. Fetches on open because the list response carries no diffs.
class _ApprovalDetailSheet extends StatefulWidget {
  final int requestId;

  const _ApprovalDetailSheet({required this.requestId});

  @override
  State<_ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends State<_ApprovalDetailSheet> {
  final ApiService _apiService = ApiService();
  ItemApproval? _request;
  bool _isLoading = true;
  bool _isActing = false;
  String? _errorMessage;
  bool _showUnchanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await _apiService.getItemApproval(widget.requestId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _request = response.data;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve change'),
        content: Text(
          _request!.isInventory
              ? 'Apply this stock adjustment? It moves inventory immediately.'
              : 'Apply this change to ${_request!.displayName}?',
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
    if (confirmed != true) return;

    setState(() => _isActing = true);
    final response = await _apiService.approveItemApproval(widget.requestId);
    if (!mounted) return;
    setState(() => _isActing = false);
    _finish(response.isSuccess, response.message);
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The requester keeps their draft; nothing is applied.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
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
    if (confirmed != true) {
      controller.dispose();
      return;
    }

    setState(() => _isActing = true);
    final reason = controller.text.trim();
    controller.dispose();
    final response = await _apiService.rejectItemApproval(
      widget.requestId,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _isActing = false);
    _finish(response.isSuccess, response.message);
  }

  void _finish(bool success, String message) {
    // Grab the messenger BEFORE popping: afterwards this State's context is
    // deactivated and ScaffoldMessenger.of(context) would throw. The snackbar
    // still lands on the list screen, which is what we want.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, success);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  /// Column names are raw DB fields; make the common ones readable and
  /// fall back to a de-underscored version for the rest.
  static const Map<String, String> _fieldLabels = {
    'name': 'Name',
    'category': 'Category',
    'item_number': 'Item number',
    'description': 'Description',
    'cost_price': 'Cost price',
    'unit_price': 'Selling price',
    'reorder_level': 'Reorder level',
    'receiving_quantity': 'Receiving qty',
    'supplier_id': 'Supplier',
    'child': 'Child item',
    'low_sell_item_id': 'Low-sell item',
    'tax_category_id': 'Tax category',
    'qty_per_pack': 'Qty per pack',
    'pack_name': 'Pack name',
    'discount_limit': 'Discount limit',
    'stock_type': 'Stock type',
    'item_type': 'Item type',
    'dormant': 'Dormant',
    'deleted': 'Deleted',
    'allow_alt_description': 'Allow alt description',
    'is_serialized': 'Serialized',
  };

  String _label(String field) {
    final known = _fieldLabels[field];
    if (known != null) return known;
    return field
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _locationLabel(BuildContext context, String locationId) {
    final locations = context.read<LocationProvider>().allowedLocations;
    for (final loc in locations) {
      if (loc.locationId.toString() == locationId) return loc.locationName;
    }
    // The approver may not be scoped to every location in the diff.
    return 'Location $locationId';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canAct = permissions.hasPermission(PermissionIds.itemsApprove);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            )
          else ...[
            Flexible(child: _buildBody(isDark)),
            _buildActions(isDark, canAct),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final r = _request!;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.displayName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.changeTypeLabel} · requested by ${r.requesterName ?? 'Unknown'}',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const Divider(height: 24),

          if (r.isInventory && r.inventoryDiff != null)
            _buildInventoryDiff(r.inventoryDiff!, isDark)
          else ...[
            _buildFieldDiffs(r, isDark),
            if (r.changedQuantities.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Quantities',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              ...r.changedQuantities.map(
                (d) => _diffRow(_locationLabel(context, d.field), d.beforeLabel,
                    d.afterLabel, isDark, changed: d.changed),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFieldDiffs(ItemApproval r, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final changed = r.changedFields;
    final unchanged = r.unchangedFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (changed.isEmpty)
          Text(
            r.isAdd
                ? 'All values below are new.'
                : 'No field values changed in this request.',
            style: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
          )
        else ...[
          Text('${changed.length} change${changed.length == 1 ? '' : 's'}',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          ...changed.map((d) =>
              _diffRow(_label(d.field), d.beforeLabel, d.afterLabel, isDark,
                  changed: true)),
        ],

        // Everything else is collapsed: an item row is ~40 columns and
        // showing them all buries the handful that actually moved.
        if (unchanged.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _showUnchanged = !_showUnchanged),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(_showUnchanged ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _showUnchanged
                        ? 'Hide unchanged fields'
                        : 'Show ${unchanged.length} unchanged fields',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          if (_showUnchanged)
            ...unchanged.map((d) =>
                _diffRow(_label(d.field), d.beforeLabel, d.afterLabel, isDark,
                    changed: false)),
        ],
      ],
    );
  }

  Widget _buildInventoryDiff(InventoryDiff d, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final positive = d.delta >= 0;
    final qty = NumberFormat('#,##0.##');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _diffRow('Location', d.location, d.location, isDark, changed: false),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(positive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: positive ? AppColors.success : AppColors.error, size: 20),
              const SizedBox(width: 6),
              Text(
                '${positive ? '+' : ''}${qty.format(d.delta)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: positive ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ),
        if (d.beforeQty != null && d.afterQty != null)
          _diffRow('Quantity', qty.format(d.beforeQty), qty.format(d.afterQty),
              isDark, changed: true),
        if (d.transComment != null && d.transComment!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Comment', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 3),
          Text(d.transComment!,
              style: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[700])),
        ],
      ],
    );
  }

  /// [changed] comes from the server, which compares type-aware:
  /// "12000.00" and 12000 are equal there. Deciding from the rendered text
  /// instead would draw a before -> after arrow on rows that never moved,
  /// which is exactly what a DECIMAL column looks like next to a plain int.
  Widget _diffRow(String label, String before, String after, bool isDark,
      {required bool changed}) {
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 13, color: subColor)),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    // An unchanged row is one value, not a before and an
                    // after that happen to match.
                    changed ? before : after,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: changed
                          ? subColor
                          : (isDark ? AppColors.darkText : AppColors.lightText),
                      decoration:
                          changed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (changed) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 13, color: subColor),
                  ),
                  Flexible(
                    child: Text(
                      after,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark, bool canAct) {
    if (!canAct) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'You do not have permission to approve or reject changes.',
          style: TextStyle(color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isActing ? null : _reject,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isActing ? null : _approve,
              icon: _isActing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
