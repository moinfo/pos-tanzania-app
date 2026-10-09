import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stock_transfer_service.dart';
import '../../services/api_service.dart';
import '../../models/stock_transfer.dart';
import '../../models/item.dart';
import '../../models/stock_location.dart';
import '../../utils/constants.dart';

/// Subtle fade+rise entrance for list items, staggered by [index].
class _FadeInItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeInItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 40).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
        );
      },
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color color;
    IconData icon;
    if (normalized.contains('confirm')) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (normalized.contains('cancel')) {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.orange;
      icon = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class StockTransfersScreen extends StatefulWidget {
  const StockTransfersScreen({super.key});

  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> {
  final StockTransferService _service = StockTransferService();
  final ApiService _apiService = ApiService();

  StockTransfersPage? _page;
  List<StockLocation> _locations = [];
  final Map<int, List<BatchItem>> _loadedBatchItems = {};
  final Set<int> _expandedBatches = {};
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final transfersResponse = await _service.getTransfers(
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate),
    );
    final locationsResponse = await _apiService.getAllStockLocations();

    if (!mounted) return;

    if (transfersResponse.statusCode == 440) {
      setState(() => _isLoading = false);
      _onSessionExpired();
      return;
    }

    if (transfersResponse.isSuccess && transfersResponse.data != null) {
      setState(() {
        _page = transfersResponse.data;
        _locations = locationsResponse.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = transfersResponse.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _load();
    }
  }

  void _onSessionExpired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log out and log back in.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openIssueShipment() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _IssueShipmentDialog(
        service: _service,
        apiService: _apiService,
        locations: _locations,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _toggleBatchItems(int batchId) async {
    if (_expandedBatches.contains(batchId)) {
      setState(() => _expandedBatches.remove(batchId));
      return;
    }

    setState(() => _expandedBatches.add(batchId));

    if (!_loadedBatchItems.containsKey(batchId)) {
      final response = await _service.getBatchItems(batchId);
      if (!mounted) return;
      if (response.isSuccess && response.data != null) {
        setState(() => _loadedBatchItems[batchId] = response.data!);
      }
      if (response.statusCode == 440) _onSessionExpired();
    }
  }

  Future<void> _confirmBatch(int batchId) async {
    final response = await _service.confirmBatch(batchId);
    if (!mounted) return;
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) _onSessionExpired();
    if (response.isSuccess) _load();
  }

  Future<void> _cancelBatch(int batchId) async {
    final confirmed = await _confirmDialog('Cancel Shipment?', 'This cannot be undone.');
    if (!confirmed) return;

    final response = await _service.cancelBatch(batchId);
    if (!mounted) return;
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) _onSessionExpired();
    if (response.isSuccess) _load();
  }

  Future<void> _confirmSingle(int transferId) async {
    final response = await _service.confirmTransfer(transferId);
    if (!mounted) return;
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) _onSessionExpired();
    if (response.isSuccess) _load();
  }

  Future<void> _cancelSingle(int transferId) async {
    final confirmed = await _confirmDialog('Cancel Transfer?', 'This cannot be undone.');
    if (!confirmed) return;

    final response = await _service.cancelTransfer(transferId);
    if (!mounted) return;
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) _onSessionExpired();
    if (response.isSuccess) _load();
  }

  Future<bool> _confirmDialog(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showResult(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This whole screen's cards/background are hardcoded light (Colors.white
    // cards on 0xFFF6F7FA) and its Text widgets rely on that for contrast -
    // none of it was built to also work against the dark theme's near-white
    // default text color. Forcing light theme here (rather than threading an
    // explicit color through every Text widget) keeps it visually consistent
    // regardless of the app's dark mode setting.
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: AppColors.brandPrimary,
        colorScheme: ThemeData.light().colorScheme.copyWith(primary: AppColors.brandPrimary),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FA),
        appBar: AppBar(title: const Text('Stock Transfers'), backgroundColor: AppColors.brandPrimary),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isLoading
              ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
              : _buildBody(),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.brandPrimary,
          onPressed: _openIssueShipment,
          icon: const Icon(Icons.send, color: Colors.white),
          label: const Text('New Shipment', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final page = _page;

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _sectionHeader(Icons.local_shipping_outlined, 'Pending Shipments',
              count: page?.pendingBatches.length ?? 0),
          const SizedBox(height: 8),
          if (page == null || page.pendingBatches.isEmpty)
            _emptyState('No pending shipments')
          else
            ...page.pendingBatches.asMap().entries.map(
                (e) => _FadeInItem(index: e.key, child: _buildBatchCard(e.value))),
          if (page != null && page.pending.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader(Icons.swap_horiz, 'Pending (Single-item)'),
            const SizedBox(height: 8),
            ...page.pending.asMap().entries.map(
                (e) => _FadeInItem(index: e.key, child: _buildPendingRow(e.value))),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.history, 'History', count: page?.history.length ?? 0),
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: const Text('Change range'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (page == null || page.history.isEmpty)
            _emptyState('No transfer history')
          else
            ...page.history.asMap().entries.map(
                (e) => _FadeInItem(index: e.key, child: _buildHistoryRow(e.value))),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, {int? count}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPrimary),
        const SizedBox(width: 6),
        Text(
          count != null ? '$title ($count)' : title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandPrimary),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey[350], size: 32),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? accentColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: accentColor != null ? Border(left: BorderSide(color: accentColor, width: 4)) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildBatchCard(PendingBatch batch) {
    final expanded = _expandedBatches.contains(batch.batchId);
    final items = _loadedBatchItems[batch.batchId];

    return _card(
      accentColor: Colors.orange,
      child: Column(
        children: [
          ListTile(
            title: Text('Shipment #${batch.batchId}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.lightText)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${batch.fromLocationName}  →  ${batch.toLocationName}\n'
                'By ${batch.issuedByName} · ${batch.issuedDate}'
                '${batch.note.isNotEmpty ? '\nNote: ${batch.note}' : ''}',
                style: const TextStyle(color: AppColors.lightTextLight),
              ),
            ),
            isThreeLine: true,
            onTap: () => _toggleBatchItems(batch.batchId),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${batch.itemCount} Items',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandPrimary)),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: expanded ? 0.5 : 0,
                  child: IconButton(
                    icon: const Icon(Icons.expand_more),
                    onPressed: () => _toggleBatchItems(batch.batchId),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: items == null
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: items
                                .map((i) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, size: 4, color: Colors.black38),
                                          const SizedBox(width: 6),
                                          Expanded(
                                              child: Text('${i.itemName} — ${i.quantity}',
                                                  style: const TextStyle(color: AppColors.lightText))),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.grey.shade50),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmBatch(batch.batchId),
                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  label: const Text('Confirm All', style: TextStyle(color: Colors.green)),
                ),
                TextButton.icon(
                  onPressed: () => _cancelBatch(batch.batchId),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                  label: const Text('Cancel All', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRow(PendingTransfer t) {
    return _card(
      accentColor: Colors.blueGrey,
      child: ListTile(
        title: Text('${t.itemName}  ·  ${t.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.lightText)),
        subtitle: Text(
          '${t.fromLocationName}  →  ${t.toLocationName}\n'
          'By ${t.issuedByName} · ${t.issuedDate}'
          '${t.note.isNotEmpty ? '\nNote: ${t.note}' : ''}',
          style: const TextStyle(color: AppColors.lightTextLight),
        ),
        isThreeLine: true,
        trailing: t.transferId == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Confirm',
                    onPressed: () => _confirmSingle(t.transferId!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Cancel',
                    onPressed: () => _cancelSingle(t.transferId!),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryRow(TransferHistoryRow t) {
    // Plain Padding+Column instead of ListTile: ListTile's isThreeLine
    // locks the subtitle to a fixed Material height budget, and a Column
    // subtitle whose first child is a chip (not text) easily overflows
    // that budget - in release builds the overflow is silently clipped
    // rather than shown as a debug banner, so everything after the chip
    // (and, once the tile's intrinsic height collapses, the title above
    // it too) can end up invisible instead of just scrolling further.
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t.itemName}  ·  ${t.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.lightText),
            ),
            const SizedBox(height: 8),
            _StatusChip(status: t.status),
            const SizedBox(height: 8),
            Text(
              '${t.fromLocationName}  →  ${t.toLocationName}\n'
              'Issued: ${t.issuedByName} · ${t.issuedDate}'
              '${t.confirmedByName.isNotEmpty ? '\nConfirmed: ${t.confirmedByName} · ${t.confirmedDate}' : ''}',
              style: const TextStyle(color: AppColors.lightTextLight, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueShipmentDialog extends StatefulWidget {
  final StockTransferService service;
  final ApiService apiService;
  final List<StockLocation> locations;

  const _IssueShipmentDialog({
    required this.service,
    required this.apiService,
    required this.locations,
  });

  @override
  State<_IssueShipmentDialog> createState() => _IssueShipmentDialogState();
}

class _IssueShipmentDialogState extends State<_IssueShipmentDialog> {
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  List<Item> _itemResults = [];
  Item? _selectedItem;
  int? _fromLocationId;
  int? _toLocationId;
  final List<ShipmentLine> _lines = [];
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _searchItems(String query) async {
    if (query.length < 2) {
      setState(() => _itemResults = []);
      return;
    }
    final response = await widget.apiService.getItems(search: query, limit: 15);
    if (!mounted) return;
    setState(() => _itemResults = response.data ?? []);
  }

  void _addLine() {
    final item = _selectedItem;
    final qty = double.tryParse(_quantityController.text);
    if (item == null || qty == null || qty <= 0) {
      setState(() => _errorMessage = 'Pick an item and a valid quantity');
      return;
    }
    setState(() {
      _lines.add(ShipmentLine(itemId: item.itemId, itemName: item.name, quantity: qty));
      _selectedItem = null;
      _itemController.clear();
      _quantityController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_fromLocationId == null || _toLocationId == null) {
      setState(() => _errorMessage = 'Pick both locations');
      return;
    }
    if (_fromLocationId == _toLocationId) {
      setState(() => _errorMessage = 'From and To locations must differ');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _errorMessage = 'Add at least one item');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final response = await widget.service.issueBatch(
      items: _lines,
      fromLocationId: _fromLocationId!,
      toLocationId: _toLocationId!,
      note: _noteController.text,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = response.message;
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dialogs attach near the root Navigator, so the parent screen's local
    // Theme() override (see StockTransfersScreen.build) doesn't reach here -
    // force light theme on this dialog too, for the same reason.
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: AppColors.brandPrimary,
        colorScheme: ThemeData.light().colorScheme.copyWith(primary: AppColors.brandPrimary),
      ),
      child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.send, color: AppColors.brandPrimary, size: 20),
          const SizedBox(width: 8),
          const Text('Issue Shipment'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _fromLocationId,
              decoration: const InputDecoration(labelText: 'From Location', border: OutlineInputBorder()),
              items: widget.locations
                  .map((l) => DropdownMenuItem(value: l.locationId, child: Text(l.locationName)))
                  .toList(),
              onChanged: (v) => setState(() => _fromLocationId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _toLocationId,
              decoration: const InputDecoration(labelText: 'To Location', border: OutlineInputBorder()),
              items: widget.locations
                  .map((l) => DropdownMenuItem(value: l.locationId, child: Text(l.locationName)))
                  .toList(),
              onChanged: (v) => setState(() => _toLocationId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
            const Divider(height: 28),
            Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _itemController,
              decoration: const InputDecoration(labelText: 'Item', border: OutlineInputBorder()),
              onChanged: _searchItems,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _itemResults.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: _itemResults
                            .map((item) => ListTile(
                                  dense: true,
                                  title: Text(item.name, style: const TextStyle(color: AppColors.lightText)),
                                  onTap: () {
                                    setState(() {
                                      _selectedItem = item;
                                      _itemController.text = item.name;
                                      _itemResults = [];
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                  onPressed: _addLine,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _lines.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No items added yet.', style: TextStyle(color: Colors.black45)),
                    )
                  : Column(
                      children: _lines
                          .asMap()
                          .entries
                          .map((entry) => Card(
                                margin: const EdgeInsets.only(bottom: 4),
                                elevation: 0,
                                color: Colors.grey.shade50,
                                child: ListTile(
                                  dense: true,
                                  title: Text('${entry.value.itemName} — ${entry.value.quantity}',
                                      style: const TextStyle(color: AppColors.lightText)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(() => _lines.removeAt(entry.key)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandPrimary),
          child: _isSaving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Issue Shipment'),
        ),
      ],
      ),
    );
  }
}
