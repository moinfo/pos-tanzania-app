import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../models/physical_stock.dart';
import '../../providers/permission_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'physical_stock_report_screen.dart';

/// Per-row auto-save state, shown as a small indicator on the item row.
enum _RowSaveStatus { saving, saved, error }

/// Physical Stock Count screen (mobile version of web /items/physical_stock).
///
/// The month is split into 4 fixed weeks. The counter picks a location and a
/// week and enters the physically counted quantity per item; each entry
/// auto-saves shortly after typing stops (no manual save button). The backend
/// snapshots the system quantity on the first save of the month for that
/// item/location/week, so the surplus/shortage difference stays honest across
/// re-saves.
class PhysicalStockScreen extends StatefulWidget {
  const PhysicalStockScreen({super.key});

  @override
  State<PhysicalStockScreen> createState() => _PhysicalStockScreenState();
}

class _PhysicalStockScreenState extends State<PhysicalStockScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  PhysicalStockData? _data;
  bool _isLoading = true;
  String? _error;

  int? _selectedLocationId;
  int _activeWeek = 1;
  String _search = '';

  /// itemId -> controller holding the physical qty being entered.
  final Map<int, TextEditingController> _qtyControllers = {};

  /// itemId -> debounce timer for auto-save after typing stops.
  final Map<int, Timer> _saveDebounce = {};

  /// itemId -> context of a not-yet-fired auto-save, so pending entries can
  /// be flushed (saved immediately) before a week/location switch overwrites
  /// the input fields.
  final Map<int, ({PhysicalStockItem item, int week, int locationId})>
      _pendingSaves = {};

  /// itemId -> auto-save status indicator for the row.
  final Map<int, _RowSaveStatus> _saveStatus = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Flush pending saves so leaving the screen can't lose a typed count.
    for (final entry in _pendingSaves.entries.toList()) {
      _saveDebounce[entry.key]?.cancel();
      final p = entry.value;
      _autoSaveItem(p.item, p.week, p.locationId);
    }
    _pendingSaves.clear();
    for (final t in _saveDebounce.values) {
      t.cancel();
    }
    _searchController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData({int? locationId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _apiService.getPhysicalStock(locationId: locationId);

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final data = PhysicalStockData.fromJson(result.data!);
      setState(() {
        _data = data;
        _selectedLocationId = data.locationId;
        _activeWeek = data.currentWeek;
        _isLoading = false;
      });
      _prefillControllers();
    } else {
      setState(() {
        _error = result.message;
        _isLoading = false;
      });
    }
  }

  /// Fill the qty inputs with the active week's saved counts.
  void _prefillControllers() {
    final data = _data;
    if (data == null) return;
    final weekCounts = data.counts[_activeWeek] ?? {};

    // Pending auto-saves were typed against the previous week/location view
    // and their input text is about to be overwritten — flush them NOW.
    // _autoSaveItem reads the controller text synchronously on entry, so
    // firing before the overwrite below saves what the counter typed.
    for (final entry in _pendingSaves.entries.toList()) {
      _saveDebounce[entry.key]?.cancel();
      final p = entry.value;
      _autoSaveItem(p.item, p.week, p.locationId);
    }
    _pendingSaves.clear();
    _saveDebounce.clear();
    _saveStatus.clear();

    for (final item in data.items) {
      final controller =
          _qtyControllers.putIfAbsent(item.itemId, () => TextEditingController());
      final existing = weekCounts[item.itemId];
      controller.text = existing != null ? _formatQty(existing.physicalQty) : '';
    }
    setState(() {});
  }

  String _formatQty(double qty) {
    return qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toString();
  }

  void _onWeekChanged(int week) {
    if (week == _activeWeek) return;
    setState(() => _activeWeek = week);
    _prefillControllers();
  }

  List<PhysicalStockItem> get _filteredItems {
    final data = _data;
    if (data == null) return const [];
    if (_search.isEmpty) return data.items;
    final q = _search.toLowerCase();
    return data.items
        .where((i) =>
            i.name.toLowerCase().contains(q) ||
            i.category.toLowerCase().contains(q) ||
            (i.itemNumber?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  /// Debounced auto-save: fires shortly after the counter stops typing in a
  /// row. Week and location are captured at scheduling time so a save can't
  /// land on the wrong week if the user switches tabs while it's pending.
  void _scheduleAutoSave(PhysicalStockItem item) {
    final week = _activeWeek;
    final locationId = _selectedLocationId;
    if (locationId == null) return;

    _saveDebounce[item.itemId]?.cancel();
    _pendingSaves[item.itemId] =
        (item: item, week: week, locationId: locationId);
    _saveDebounce[item.itemId] = Timer(const Duration(milliseconds: 900), () {
      _pendingSaves.remove(item.itemId);
      _autoSaveItem(item, week, locationId);
    });
  }

  Future<void> _autoSaveItem(
      PhysicalStockItem item, int week, int locationId) async {
    final text = _qtyControllers[item.itemId]?.text.trim() ?? '';
    if (text.isEmpty) return; // cleared field: nothing to save
    final qty = double.tryParse(text);
    if (qty == null || qty < 0) return;

    if (!mounted) return;
    setState(() => _saveStatus[item.itemId] = _RowSaveStatus.saving);

    final result = await _apiService.savePhysicalStock(
      locationId: locationId,
      weekNumber: week,
      entries: [
        {'item_id': item.itemId, 'physical_qty': qty}
      ],
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // Update the local count so the surplus/shortage chip and the counted
      // total refresh without refetching. The system qty snapshot follows the
      // backend rule: an existing count for this week keeps its snapshot,
      // a first count snapshots the current system quantity.
      final weekCounts = _data?.counts.putIfAbsent(week, () => {});
      final systemQty =
          weekCounts?[item.itemId]?.systemQty ?? item.systemQty;
      weekCounts?[item.itemId] = PhysicalStockCount(
        systemQty: systemQty,
        physicalQty: qty,
        difference: qty - systemQty,
        countDate: null,
      );
      setState(() => _saveStatus[item.itemId] = _RowSaveStatus.saved);
    } else {
      setState(() => _saveStatus[item.itemId] = _RowSaveStatus.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save ${item.name}: ${result.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canViewReport = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.itemsPhysicalStockReport);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Physical Stock'),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (canViewReport)
            IconButton(
              icon: const Icon(Icons.assessment_outlined),
              tooltip: 'Report',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PhysicalStockReportScreen()),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(isDark),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Failed to load'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadData(locationId: _selectedLocationId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final data = _data!;
    final items = _filteredItems;
    final weekCounts = data.counts[_activeWeek] ?? {};

    return Column(
      children: [
        _buildHeaderCanopy(data, weekCounts),
        _buildSearchField(isDark),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 2, bottom: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildItemRow(items[index], weekCounts, isDark),
                ),
        ),
      ],
    );
  }

  /// Brand-colored header fused with the app bar: location + month, week
  /// selector, and a live count-progress ribbon for the active week.
  Widget _buildHeaderCanopy(
      PhysicalStockData data, Map<int, PhysicalStockCount> weekCounts) {
    final counted = weekCounts.length;
    final total = data.items.length;
    final fraction = total == 0 ? 0.0 : counted / total;
    final complete = total > 0 && counted >= total;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // Location + month
          Row(
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(child: _buildLocationSelector(data)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.monthName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Week selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [1, 2, 3, 4].map((week) {
                final isActive = week == _activeWeek;
                final isCurrent = week == data.currentWeek;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onWeekChanged(week),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Wk $week',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? AppColors.brandPrimary
                                      : Colors.white,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 3),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.warning,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            data.weekRanges[week] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? AppColors.brandPrimary.withOpacity(0.7)
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          // Count progress ribbon
          Row(
            children: [
              Text(
                complete ? 'Week $_activeWeek complete' : 'Counted this week',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '$counted / $total',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(
                    complete ? AppColors.success : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(PhysicalStockData data) {
    if (data.locations.length <= 1) {
      return Text(
        data.locations.isNotEmpty
            ? data.locations.first.locationName
            : 'No location',
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _selectedLocationId,
        isDense: true,
        dropdownColor: AppColors.brandPrimaryDark,
        iconEnabledColor: Colors.white70,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        items: data.locations
            .map((l) => DropdownMenuItem(
                  value: l.locationId,
                  child: Text(l.locationName, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (id) {
          if (id != null && id != _selectedLocationId) {
            _loadData(locationId: id);
          }
        },
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search items...',
          prefixIcon: Icon(Icons.search,
              size: 20,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight),
          isDense: true,
          filled: true,
          fillColor: isDark ? AppColors.darkCard : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.brandPrimary, width: 1.5),
          ),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                ),
        ),
        onChanged: (v) => setState(() => _search = v.trim()),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 44,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight),
          const SizedBox(height: 10),
          Text(
            _search.isEmpty ? 'No items found' : 'No items match "$_search"',
            style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(PhysicalStockItem item,
      Map<int, PhysicalStockCount> weekCounts, bool isDark) {
    final count = weekCounts[item.itemId];
    final controller =
        _qtyControllers.putIfAbsent(item.itemId, () => TextEditingController());
    // Indent children under their parent (parent -> child order from the API)
    final indent = 18.0 * item.hierDepth.clamp(0, 3);

    // Left rail encodes the count state of this row for the active week.
    final Color railColor;
    if (count == null) {
      railColor = Colors.transparent;
    } else if (count.difference > 0) {
      railColor = AppColors.success;
    } else if (count.difference < 0) {
      railColor = AppColors.error;
    } else {
      railColor = Colors.blueGrey;
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16 + indent, 3, 16, 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, color: railColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.hierDepth > 0) ...[
                                  const Icon(Icons.subdirectory_arrow_right,
                                      size: 14, color: Colors.blueGrey),
                                  const SizedBox(width: 3),
                                ],
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandPrimary
                                        .withOpacity(isDark ? 0.25 : 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Sys ${NumberFormat('#,###.##').format(count?.systemQty ?? item.systemQty)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.primaryLight
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (item.category.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      item.category,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextLight
                                            : AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (count != null) ...[
                              const SizedBox(height: 5),
                              _buildDifferenceChip(count.difference),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildSaveStatusIcon(item.itemId),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 78,
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight.withOpacity(0.5)
                                  : AppColors.textLight.withOpacity(0.5),
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkAccent
                                : AppColors.lightBackground,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppColors.brandPrimary, width: 1.5),
                            ),
                          ),
                          onChanged: (_) => _scheduleAutoSave(item),
                        ),
                      ),
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

  /// Small auto-save indicator shown next to the qty input.
  Widget _buildSaveStatusIcon(int itemId) {
    switch (_saveStatus[itemId]) {
      case _RowSaveStatus.saving:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _RowSaveStatus.saved:
        return const Icon(Icons.check_circle,
            size: 18, color: AppColors.success);
      case _RowSaveStatus.error:
        return const Icon(Icons.error, size: 18, color: AppColors.error);
      case null:
        return const SizedBox(width: 18);
    }
  }

  Widget _buildDifferenceChip(double difference) {
    final Color color;
    final String label;
    if (difference > 0) {
      color = AppColors.success;
      label = 'Surplus +${NumberFormat('#,###.##').format(difference)}';
    } else if (difference < 0) {
      color = AppColors.error;
      label = 'Shortage ${NumberFormat('#,###.##').format(difference)}';
    } else {
      color = Colors.blueGrey;
      label = 'Matched';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
