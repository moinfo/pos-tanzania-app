import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_hierarchy_node.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Hierarchy accent tints -- built from this app's own brand/status colors
/// (AppColors.brandPrimary/warning/success/error), not a new palette.
/// Wholesale = warning amber, retail/verified = success green, low stock =
/// error red -- the same status colors already used everywhere else in the
/// app, just tinted for a chip background.
class _Hier {
  static Color ochreBg(bool isDark) =>
      AppColors.warning.withOpacity(isDark ? 0.28 : 0.14);
  static Color tealBg(bool isDark) =>
      AppColors.success.withOpacity(isDark ? 0.28 : 0.14);
  static Color rail(bool isDark) =>
      isDark ? AppColors.darkDivider : AppColors.divider;
}

/// One rail segment drawn to the left of a row, one per ancestor depth.
enum _RailSeg {
  blank, // ancestor at this level had no further siblings -- nothing to draw
  pass, // ancestor at this level has more siblings below -- trunk continues
  branchLast, // this row's own connector, and it's the last child here
  branchMore, // this row's own connector, with siblings still below it
}

/// A flattened tree row plus the rail segments needed to draw its branch
/// lines -- rail[i] is true when the ancestor at depth i+1 was the LAST
/// child among its siblings (so the trunk stops there rather than passing
/// through). Mirrors the web page's render_hier_nodes() $rail array.
class _HierRow {
  final ItemHierarchyNode node;
  final List<bool> rail;
  const _HierRow(this.node, this.rail);
}

/// Mirrors the web Items -> Item Hierarchy page: a manifest of how bulk
/// sacks/cartons break down into retail packets, with the branch structure
/// drawn as literal connecting lines (not just indentation), and the same
/// three inline edits the web page offers -- category, reorder level,
/// verified -- each saved individually through api/items/update_fields
/// (staged for approval when the employee lacks that grant, as on web).
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
  void _updateNode(
      int itemId, ItemHierarchyNode Function(ItemHierarchyNode) update) {
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

  void _showToast(String message,
      {bool isError = false, bool isPending = false}) {
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
                        const Icon(Icons.check,
                            size: 18, color: AppColors.primary)
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

  /// Flattens the tree into visible rows -- respecting collapse state, and
  /// while a search term is active, showing only nodes that match (by name
  /// or id) plus every ancestor leading down to a match -- while computing
  /// each row's rail (branch-line) segments. "Last sibling" is judged
  /// against the currently VISIBLE sibling set, so a search filter never
  /// draws a trunk line continuing toward a hidden sibling.
  List<_HierRow> _visibleRows() {
    final out = <_HierRow>[];
    if (_tree == null) return out;
    final searching = _query.isNotEmpty;

    bool matches(ItemHierarchyNode n) =>
        n.name.toLowerCase().contains(_query) ||
        n.itemId.toString().contains(_query);
    bool subtreeMatches(ItemHierarchyNode n) =>
        matches(n) || n.children.any(subtreeMatches);

    void walk(List<ItemHierarchyNode> nodes, List<bool> parentRail) {
      final visible = searching ? nodes.where(subtreeMatches).toList() : nodes;
      for (var i = 0; i < visible.length; i++) {
        final n = visible[i];
        final rail = [...parentRail, i == visible.length - 1];
        out.add(_HierRow(n, rail));
        final expanded = searching || !_collapsed.contains(n.itemId);
        if (expanded && n.children.isNotEmpty) walk(n.children, rail);
      }
    }

    walk(_tree!, []);
    return out;
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

  /// Header band matches the AppBar exactly (brand blue in light mode, dark
  /// surface in dark mode) so the two read as one continuous bar, not a
  /// second, unrelated color dropped in underneath it.
  Widget _buildBody(bool isDark) {
    final tree = _tree ?? [];
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;
    return Column(
      children: [
        Container(
          color: headerColor,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statFigure('${tree.length}', 'breakdown chains'),
                  const SizedBox(width: 28),
                  _statFigure('$_totalCount', 'active items'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search items',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: Colors.white.withOpacity(0.65)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 16, color: Colors.white.withOpacity(0.65)),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.25)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
              ),
              if (tree.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _legendDot(AppColors.warning, 'Wholesale unit'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.success, 'Retail unit'),
                  ],
                ),
              ],
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

  Widget _statFigure(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1.0)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.72))),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.72))),
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
                  size: 44,
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight),
              const SizedBox(height: 12),
              Text(
                'No sack-to-packet chains yet.',
                style: TextStyle(
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight),
              ),
              const SizedBox(height: 4),
              Text(
                'Link a bulk item to its retail breakdown from the item\'s edit page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
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

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, i) => _buildRow(rows[i], isDark),
    );
  }

  Widget _buildRow(_HierRow row, bool isDark) {
    final node = row.node;
    final hasChildren = node.children.isNotEmpty;
    final collapsed = _collapsed.contains(node.itemId);
    final isWholesale =
        node.category.toUpperCase().contains('WHOLE') || node.depth == 0;
    final accent = isWholesale ? AppColors.warning : AppColors.success;
    final accentBg = isWholesale ? _Hier.ochreBg(isDark) : _Hier.tealBg(isDark);
    final railColor = _Hier.rail(isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              width: 1),
          left: BorderSide(
              color: node.depth == 0 ? accent : Colors.transparent, width: 3),
        ),
      ),
      padding: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 11),
            for (var i = 1; i < row.rail.length; i++)
              SizedBox(
                width: 16,
                child: CustomPaint(
                  painter: _RailPainter(
                    seg: i == row.rail.length - 1
                        ? (row.rail[i]
                            ? _RailSeg.branchLast
                            : _RailSeg.branchMore)
                        : (row.rail[i] ? _RailSeg.blank : _RailSeg.pass),
                    color: railColor,
                  ),
                ),
              ),
            SizedBox(
              width: 22,
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
                        collapsed ? Icons.add : Icons.remove,
                        size: 15,
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
                        const Icon(Icons.verified,
                            size: 13, color: AppColors.success),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          node.name,
                          style: TextStyle(
                            fontWeight: node.depth == 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: node.depth == 0 ? 14.5 : 13.5,
                            letterSpacing: -0.1,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ),
                      if (node.depth > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            '×${_trimYield(node.receivingQuantity)}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(3),
                        onTap: () => _editCategory(node),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentBg,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(node.category,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1,
                                      color: accent)),
                              const SizedBox(width: 3),
                              Icon(Icons.expand_more,
                                  size: 12, color: accent.withOpacity(0.8)),
                            ],
                          ),
                        ),
                      ),
                      _editField(
                        label: 'Reorder',
                        value: Formatters.formatCurrency(node.reorderLevel),
                        isDark: isDark,
                        onTap: () => _editReorderLevel(node),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(3),
                        onTap: () => _toggleVerified(node),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: node.isVerified
                                ? AppColors.success
                                    .withOpacity(isDark ? 0.28 : 0.12)
                                : Colors.transparent,
                            border: Border.all(
                                color: node.isVerified
                                    ? AppColors.success
                                    : (isDark
                                        ? AppColors.darkDivider
                                        : AppColors.divider)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                node.isVerified
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 11,
                                color: node.isVerified
                                    ? AppColors.success
                                    : (isDark
                                        ? AppColors.darkTextLight
                                        : AppColors.textLight),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                node.isVerified ? 'Verified' : 'Verify',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: node.isVerified
                                      ? AppColors.success
                                      : (isDark
                                          ? AppColors.darkTextLight
                                          : AppColors.textLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        Formatters.formatCurrency(node.stockQty),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: node.isLowStock
                              ? AppColors.error
                              : (isDark ? AppColors.darkText : AppColors.text),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('in stock',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight)),
                      if (node.isLowStock) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.warning_amber_rounded,
                            size: 12, color: AppColors.error),
                      ],
                      const Spacer(),
                      Text(
                        '${Formatters.formatCurrency(node.costPrice)} → ${Formatters.formatCurrency(node.unitPrice)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A small tappable "field" chip -- label above, value below with a
  /// dashed underline -- reads as a form field you can edit, not plain
  /// text with an icon bolted on.
  Widget _editField({
    required String label,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final dim = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final text = isDark ? AppColors.darkText : AppColors.text;
    return InkWell(
      borderRadius: BorderRadius.circular(3),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dim, width: 1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label ', style: TextStyle(fontSize: 10.5, color: dim)),
            Text(value,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: text)),
          ],
        ),
      ),
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

/// Draws one column's branch-line segment for a hierarchy row -- a vertical
/// trunk passing through, an elbow where a branch meets the trunk, or
/// nothing at all. Mirrors the web page's CSS .rail/.stem/::after lines as
/// literal canvas strokes, since Flutter has no CSS-pseudo-element
/// equivalent to lean on.
class _RailPainter extends CustomPainter {
  final _RailSeg seg;
  final Color color;

  const _RailPainter({required this.seg, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (seg == _RailSeg.blank) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final midX = size.width / 2;
    final midY = size.height / 2;

    switch (seg) {
      case _RailSeg.pass:
        canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
        break;
      case _RailSeg.branchMore:
        canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
        canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
        break;
      case _RailSeg.branchLast:
        canvas.drawLine(Offset(midX, 0), Offset(midX, midY), paint);
        canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
        break;
      case _RailSeg.blank:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) =>
      oldDelegate.seg != seg || oldDelegate.color != color;
}
