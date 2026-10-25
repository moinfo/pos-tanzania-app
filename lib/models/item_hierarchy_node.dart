/// One node in the item breakdown tree (bulk sack/carton -> retail
/// packets) -- mirrors the web Items -> Item Hierarchy page's
/// Item::get_hierarchy_tree() shape (api/Items::hierarchy()).
class ItemHierarchyNode {
  final int itemId;
  final String name;
  final String category;
  final double costPrice;
  final double unitPrice;

  /// How many units of this item one unit of its parent converts into.
  /// Meaningless (always effectively 1) at depth 0 -- the root IS the
  /// whole unit, not a conversion of something else.
  final double receivingQuantity;
  final double reorderLevel;
  final bool isVerified;
  final double stockQty;
  final int depth;
  final List<ItemHierarchyNode> children;

  const ItemHierarchyNode({
    required this.itemId,
    required this.name,
    required this.category,
    required this.costPrice,
    required this.unitPrice,
    required this.receivingQuantity,
    required this.reorderLevel,
    required this.isVerified,
    required this.stockQty,
    required this.depth,
    required this.children,
  });

  bool get isLowStock => reorderLevel > 0 && stockQty <= reorderLevel;

  /// Local, in-place update after a successful inline edit (category /
  /// reorder level / verified) -- mirrors the web page's applyDisplay()
  /// updating the cell directly rather than reloading the whole table.
  ItemHierarchyNode copyWith({
    String? category,
    double? reorderLevel,
    bool? isVerified,
    List<ItemHierarchyNode>? children,
  }) {
    return ItemHierarchyNode(
      itemId: itemId,
      name: name,
      category: category ?? this.category,
      costPrice: costPrice,
      unitPrice: unitPrice,
      receivingQuantity: receivingQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      isVerified: isVerified ?? this.isVerified,
      stockQty: stockQty,
      depth: depth,
      children: children ?? this.children,
    );
  }

  factory ItemHierarchyNode.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>;
    return ItemHierarchyNode(
      itemId: item['item_id'] as int,
      name: item['name'] as String? ?? '',
      category: item['category'] as String? ?? '',
      costPrice: (item['cost_price'] as num?)?.toDouble() ?? 0,
      unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
      receivingQuantity: (item['receiving_quantity'] as num?)?.toDouble() ?? 0,
      reorderLevel: (item['reorder_level'] as num?)?.toDouble() ?? 0,
      isVerified: item['is_verified'] as bool? ?? false,
      stockQty: (item['stock_qty'] as num?)?.toDouble() ?? 0,
      depth: json['depth'] as int? ?? 0,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => ItemHierarchyNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Full api/items/hierarchy payload -- the tree plus the same category list
/// the web page's inline category editor offers (distinct categories across
/// this tenant's active items, from Item::get_categories() -- NOT the
/// item_categories master table, a different, broader set).
class ItemHierarchyResult {
  final List<ItemHierarchyNode> tree;
  final int total;
  final List<String> categories;

  const ItemHierarchyResult({
    required this.tree,
    required this.total,
    required this.categories,
  });

  factory ItemHierarchyResult.fromJson(Map<String, dynamic> json) {
    return ItemHierarchyResult(
      tree: (json['tree'] as List<dynamic>? ?? [])
          .map((n) => ItemHierarchyNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((c) => c.toString())
          .toList(),
    );
  }
}
