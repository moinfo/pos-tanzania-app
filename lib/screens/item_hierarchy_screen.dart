import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_hierarchy_node.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Mirrors the web Items -> Item Hierarchy page: table + expand/collapse +
/// search, and the same three inline edits the web page offers --
/// category, reorder level, verified -- each tapped and saved individually
/// through the same api/items/update_fields endpoint (staged for approval
/// when the employee lacks that grant, exactly as on web).
class ItemHierarchyScreen extends StatefulWidget {
  const ItemHierarchyScreen({super.key});

  @override
  State<ItemHierarchyScreen> createState() => _ItemHierarchyScreenState();
}

class _ItemHierarchyScreenState extends State<ItemHierarchyScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<ItemHierarchyNode>? _tree;
  List<String> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// item_id of every root/branch node currently collapsed (hides its
  /// children). Empty = everything expanded, the default.
  final Set<int> _collapsed = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _apiService.getItemHierarchy();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess && result.data != null) {
        _tree = result.data!.tree;
        _categories = result.data!.categories;
      } else {
        _errorMessage = result.message;
      }
    });
  }

  /// Replaces one node (by item_id) in place, wherever it sits in the tree,
  /// after a successful inline edit -- mirrors the web page's applyDisplay()
  /// updating the cell directly rather than reloading the whole table.
  void _updateNode(int itemId, ItemHierarchyNode Function(ItemHierarchyNode) update) {
    List<ItemHierarchyNode> walk(List<ItemHierarchyNode> nodes) {
      return nodes.map((n) {
        if (n.itemId == itemId) return update(n);
        if (n.children.isEmpty) return n;
        return n.copyWith(children: walk(n.children));
      }).toList();
    }

    if (_tree == null) return;
    setState(() => _tree = walk(_tree!));
  }

  void _showToast(String message, {bool isError = false, bool isPending = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : (isPending ? AppColors.warning : AppColors.success),
      ),
    );
  }

  Future<void> _editCategory(ItemHierarchyNode node) async {
    // Same list the web page's <select> offers: every active item's
    // distinct category, plus this item's own category even if it's the
    // only one with it (so it's never missing from its own picker).
    final options = [..._categories];
    if (!options.contains(node.category)) options.insert(0, node.category);

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Category'),
        children: options
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Row(
                    children: [
                      if (c == node.category)
                        const Icon(Icons.check, size: 18, color: AppColors.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (selected == null || selected == node.category) return;

    final response =
        await _apiService.updateItemFields(node.itemId, category: selected);
    if (response.isPending) {
      _showToast(response.message, isPending: true);
    } else if (response.isSuccess) {
      _updateNode(node.itemId, (n) => n.copyWith(category: selected));
      _showToast('Saved');
    } else {
      _showToast(response.message, isError: true);
    }
  }

  Future<void> _editReorderLevel(ItemHierarchyNode node) async {
    final controller = TextEditingController(
        text: Formatters.formatCurrency(node.reorderLevel));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reorder at'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.replaceAll(',', '').trim());
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value < 0 || value == node.reorderLevel) return;

    final response =
        await _apiService.updateItemFields(node.itemId, reorderLevel: value);
    if (response.isPending) {
      _showToast(response.message, isPending: true);
    } else if (response.isSuccess) {
      _updateNode(node.itemId, (n) => n.copyWith(reorderLevel: value));
      _showToast('Saved');
    } else {
      _showToast(response.message, isError: true);
    }
  }

  Future<void> _toggleVerified(ItemHierarchyNode node) async {
    final next = !node.isVerified;
    final response =
        await _apiService.updateItemFields(node.itemId, isVerified: next);
    if (response.isPending) {
      _showToast(response.message, isPending: true);
    } else if (response.isSuccess) {
      _updateNode(node.itemId, (n) => n.copyWith(isVerified: next));
      _showToast('Saved');
    } else {
      _showToast(response.message, isError: true);
    }
  }

  int get _totalCount {
    int count = 0;
    void walk(List<ItemHierarchyNode> nodes) {
      for (final n in nodes) {
        count++;
        walk(n.children);
      }
    }

    if (_tree != null) walk(_tree!);
    return count;
  }

  /// Flattens the tree into visible rows: respects collapse state, and --
  /// while a search term is active -- shows only nodes that match (by name
  /// or id) plus every ancestor leading down to a match, ignoring collapse.
  List<ItemHierarchyNode> _visibleRows() {
    if (_tree == null) return [];
    final rows = <ItemHierarchyNode>[];

    if (_query.isEmpty) {
      void walk(List<ItemHierarchyNode> nodes) {
        for (final n in nodes) {
          rows.add(n);
          if (!_collapsed.contains(n.itemId)) walk(n.children);
        }
      }

      walk(_tree!);
      return rows;
    }

    bool matches(ItemHierarchyNode n) =>
        n.name.toLowerCase().contains(_query) ||
        n.itemId.toString().contains(_query);

    bool subtreeMatches(ItemHierarchyNode n) =>
        matches(n) || n.children.any(subtreeMatches);

    void walk(List<ItemHierarchyNode> nodes) {
      for (final n in nodes) {
        if (!subtreeMatches(n)) continue;
        rows.add(n);
        walk(n.children);
      }
    }

    walk(_tree!);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Item Hierarchy'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.unfold_more),
            tooltip: 'Expand all',
            onPressed: () => setState(() => _collapsed.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.unfold_less),
            tooltip: 'Collapse all',
            onPressed: () {
              if (_tree == null) return;
              setState(() {
                _collapsed
                  ..clear()
                  ..addAll(_tree!
                      .where((n) => n.children.isNotEmpty)
                      .map((n) => n.itemId));
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError(isDark)
              : _buildBody(isDark),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 56),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.text)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final tree = _tree ?? [];
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statChip('${tree.length}', 'breakdown chains', isDark),
                  const SizedBox(width: 16),
                  _statChip('$_totalCount', 'active items', isDark),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search items…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tree.isEmpty
              ? _buildEmpty(isDark)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildRows(isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              Icon(Icons.account_tree_outlined,
                  size: 48,
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight),
              const SizedBox(height: 12),
              Text(
                'No sack-to-packet chains yet.',
                style: TextStyle(
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRows(bool isDark) {
    final rows = _visibleRows();
    if (rows.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Text('No items match that search.',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight)),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, color: isDark ? AppColors.darkDivider : AppColors.divider),
      itemBuilder: (context, i) => _buildRow(rows[i], isDark),
    );
  }

  Widget _buildRow(ItemHierarchyNode node, bool isDark) {
    final hasChildren = node.children.isNotEmpty;
    final collapsed = _collapsed.contains(node.itemId);
    final isWholesale =
        node.category.toUpperCase().contains('WHOLE') || node.depth == 0;

    // Only the chevron toggles expand/collapse, same as the web page --
    // there the toggle-btn arrow is the one clickable thing on the row
    // that isn't an editable field; clicking the name itself does nothing.
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + node.depth * 18, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: hasChildren
                ? InkWell(
                    onTap: () => setState(() {
                      if (collapsed) {
                        _collapsed.remove(node.itemId);
                      } else {
                        _collapsed.add(node.itemId);
                      }
                    }),
                    child: Icon(
                      collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight,
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (node.isVerified) ...[
                      const Icon(Icons.verified, size: 13, color: AppColors.info),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        node.name,
                        style: TextStyle(
                          fontWeight: node.depth == 0
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: node.depth == 0 ? 14.5 : 13.5,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ),
                    if (node.depth > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.secondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '×${_trimYield(node.receivingQuantity)}',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.secondary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _editCategory(node),
                      child: _tag(
                          node.category,
                          isWholesale ? AppColors.warning : AppColors.success,
                          isDark,
                          editable: true),
                    ),
                    InkWell(
                      onTap: () => _editReorderLevel(node),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Reorder at: '),
                            TextSpan(
                              text: Formatters.formatCurrency(node.reorderLevel),
                              style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  decorationStyle: TextDecorationStyle.dashed),
                            ),
                          ],
                        ),
                        style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextLight
                                : AppColors.textLight),
                      ),
                    ),
                    InkWell(
                      onTap: () => _toggleVerified(node),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: node.isVerified
                              ? AppColors.info.withOpacity(isDark ? 0.25 : 0.12)
                              : Colors.transparent,
                          border: Border.all(
                              color: node.isVerified
                                  ? AppColors.info
                                  : (isDark
                                      ? AppColors.darkDivider
                                      : AppColors.divider)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          node.isVerified ? '✓ Verified' : 'Mark verified',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: node.isVerified
                                ? AppColors.info
                                : (isDark
                                    ? AppColors.darkTextLight
                                    : AppColors.textLight),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Stock: ${Formatters.formatCurrency(node.stockQty)}'
                      '${node.isLowStock ? ' (low)' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: node.isLowStock ? FontWeight.bold : null,
                        color: node.isLowStock
                            ? AppColors.error
                            : (isDark
                                ? AppColors.darkTextLight
                                : AppColors.textLight),
                      ),
                    ),
                    Text(
                      'Cost ${Formatters.formatCurrency(node.costPrice)} · '
                      'Sell ${Formatters.formatCurrency(node.unitPrice)}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color, bool isDark, {bool editable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
          if (editable) ...[
            const SizedBox(width: 3),
            Icon(Icons.edit, size: 9, color: color.withOpacity(0.7)),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text)),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
      ],
    );
  }

  String _trimYield(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
