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

  /// Field names (category / reorder_level / is_verified) with an
  /// outstanding item_change_requests row -- field-scoped on purpose: a
  /// pending "verify" request must not block an unrelated category or
  /// reorder_level edit on the same item. Server-sourced, so it survives
  /// leaving and reopening the screen, not just a local flag that a reload
  /// would forget.
  final List<String> pendingFields;

  /// True when a FULL item edit (the Add/Edit Item form, not this page's
  /// own per-field edit) is pending -- that resubmits every field at once,
  /// so it conflicts with any field here, regardless of pendingFields.
  final bool pendingFullEdit;

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
    this.pendingFields = const [],
    this.pendingFullEdit = false,
  });

  bool get isLowStock => reorderLevel > 0 && stockQty <= reorderLevel;

  /// Whether this item has ANY pending change at all -- drives the row's
  /// "Waiting approval" badge (informational; doesn't by itself say which
  /// field is blocked, see [isFieldPending]).
  bool get isPendingApproval => pendingFullEdit || pendingFields.isNotEmpty;

  /// Whether submitting $field now would be refused -- matches the
  /// backend's Item_change_request::has_conflicting_pending_request().
  bool isFieldPending(String field) =>
      pendingFullEdit || pendingFields.contains(field);

  /// Local, in-place update after a successful inline edit (category /
  /// reorder level / verified) -- mirrors the web page's applyDisplay()
  /// updating the cell directly rather than reloading the whole table.
  /// Also used to optimistically add to pendingFields the moment a save
  /// comes back staged, without waiting for the next full reload.
  ItemHierarchyNode copyWith({
    String? category,
    double? reorderLevel,
    bool? isVerified,
    List<ItemHierarchyNode>? children,
    List<String>? pendingFields,
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
      pendingFields: pendingFields ?? this.pendingFields,
      pendingFullEdit: pendingFullEdit,
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
      pendingFields: (item['pending_fields'] as List<dynamic>? ?? [])
          .map((f) => f.toString())
          .toList(),
      pendingFullEdit: item['pending_full_edit'] as bool? ?? false,
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
