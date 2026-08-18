// Production module: batches, recipes, sand lots and settings.
//
// Backend: application/controllers/api/Production.php, engine in
// application/libraries/Production_lib.php. Schema in
// application/migrations/sqlscripts/production_module.sql.
//
// Money and quantity columns are DECIMAL, so they arrive as strings
// ("55000.00") not numbers -- every numeric read goes through _toDouble.

double _toDouble(dynamic v, {double fallback = 0.0}) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? fallback;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

class ProductionBatch {
  final int batchId;
  final String batchNo;
  final String productionDate;
  final int itemId;
  final String? itemName;
  final int? recipeId;
  final String? recipeName;
  final int? lotId;
  final String? lotNo;

  final double bagsUsed;
  final double expectedOutput;

  /// NULL until the batch is closed -- see the schema comment
  /// "NULL mpaka draft ifungwe".
  final double? actualOutput;
  final double rejects;
  final double? efficiencyPct;

  /// STANDARD cost (cost_map rates x qty). This is what COGS uses, on
  /// purpose: a late expense entry must not move the price of stock.
  final double directCostTotal;

  /// ACTUAL cost (sum of linked expenses).
  final double actualCostTotal;

  /// Generated stored column: actual - standard.
  final double costVariance;
  final double? costPerUnit;

  /// 'draft' | 'curing' | 'ready' | 'closed'
  final String status;

  ProductionBatch({
    required this.batchId,
    required this.batchNo,
    required this.productionDate,
    required this.itemId,
    this.itemName,
    this.recipeId,
    this.recipeName,
    this.lotId,
    this.lotNo,
    required this.bagsUsed,
    required this.expectedOutput,
    this.actualOutput,
    required this.rejects,
    this.efficiencyPct,
    required this.directCostTotal,
    required this.actualCostTotal,
    required this.costVariance,
    this.costPerUnit,
    required this.status,
  });

  factory ProductionBatch.fromJson(Map<String, dynamic> json) {
    return ProductionBatch(
      batchId: _toInt(json['batch_id']),
      batchNo: json['batch_no']?.toString() ?? '',
      productionDate: json['production_date']?.toString() ?? '',
      itemId: _toInt(json['item_id']),
      itemName: json['item_name']?.toString(),
      recipeId: _toIntOrNull(json['recipe_id']),
      recipeName: json['recipe_name']?.toString(),
      lotId: _toIntOrNull(json['lot_id']),
      lotNo: json['lot_no']?.toString(),
      bagsUsed: _toDouble(json['bags_used']),
      expectedOutput: _toDouble(json['expected_output']),
      actualOutput: _toDoubleOrNull(json['actual_output']),
      rejects: _toDouble(json['rejects']),
      efficiencyPct: _toDoubleOrNull(json['efficiency_pct']),
      directCostTotal: _toDouble(json['direct_cost_total']),
      actualCostTotal: _toDouble(json['actual_cost_total']),
      costVariance: _toDouble(json['cost_variance']),
      costPerUnit: _toDoubleOrNull(json['cost_per_unit']),
      status: json['status']?.toString() ?? 'draft',
    );
  }

  bool get isDraft => status == 'draft';
  bool get isCuring => status == 'curing';
  bool get isReady => status == 'ready';

  /// Only a draft can be closed -- close_batch() rejects anything else.
  bool get canClose => isDraft;

  /// No expense has been linked, so the actual cost is unknown. The
  /// Expense Reconciliation report treats this as "production unrecorded".
  bool get hasNoLinkedExpense => actualCostTotal == 0;
}

class ProductionBatchListResponse {
  final List<ProductionBatch> batches;
  final int total;
  final int limit;
  final int offset;

  ProductionBatchListResponse({
    required this.batches,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ProductionBatchListResponse.fromJson(Map<String, dynamic> json) {
    return ProductionBatchListResponse(
      batches: (json['batches'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ProductionBatch.fromJson)
              .toList() ??
          [],
      total: _toInt(json['total']),
      limit: _toInt(json['limit'], fallback: 50),
      offset: _toInt(json['offset']),
    );
  }
}

/// A batch plus the cost lines and expense links only the detail call returns.
class ProductionBatchDetail {
  final ProductionBatch batch;
  final List<Map<String, dynamic>> costs;
  final List<Map<String, dynamic>> expenses;

  ProductionBatchDetail({
    required this.batch,
    required this.costs,
    required this.expenses,
  });

  factory ProductionBatchDetail.fromJson(Map<String, dynamic> json) {
    return ProductionBatchDetail(
      batch: ProductionBatch.fromJson(
          (json['batch'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      costs: (json['costs'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
      expenses: (json['expenses'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
    );
  }
}

class RecipeItem {
  final int itemId;
  final String? itemName;
  final double qtyPerBag;

  RecipeItem({required this.itemId, this.itemName, required this.qtyPerBag});

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      itemId: _toInt(json['item_id']),
      itemName: json['name']?.toString() ?? json['item_name']?.toString(),
      qtyPerBag: _toDouble(json['qty_per_bag']),
    );
  }
}

class ProductionRecipe {
  final int recipeId;
  final int itemId;
  final String name;
  final double standardYieldPerBag;

  /// NULL means "fall back to settings.default_curing_days".
  final int? curingDays;
  final String? effectiveFrom;
  final bool isActive;
  final List<RecipeItem> items;

  ProductionRecipe({
    required this.recipeId,
    required this.itemId,
    required this.name,
    required this.standardYieldPerBag,
    this.curingDays,
    this.effectiveFrom,
    required this.isActive,
    required this.items,
  });

  factory ProductionRecipe.fromJson(Map<String, dynamic> json) {
    return ProductionRecipe(
      recipeId: _toInt(json['recipe_id']),
      itemId: _toInt(json['item_id']),
      name: json['name']?.toString() ?? '',
      standardYieldPerBag: _toDouble(json['standard_yield_per_bag']),
      curingDays: _toIntOrNull(json['curing_days']),
      effectiveFrom: json['effective_from']?.toString(),
      // tinyint(1) arrives as "1"/"0" or 1/0.
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active']?.toString() == '1',
      items: (json['items'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(RecipeItem.fromJson)
              .toList() ??
          [],
    );
  }
}

class ProductionLot {
  final int lotId;
  final String lotNo;
  final String openedOn;
  final double materialCost;
  final double transportCost;
  final double utilityCost;
  final double totalCost;
  final double expectedBags;
  final double bagsConsumed;
  final double costPerBag;

  /// 'active' | 'closed'
  final String status;
  final String? closedOn;
  final String? notes;

  ProductionLot({
    required this.lotId,
    required this.lotNo,
    required this.openedOn,
    required this.materialCost,
    required this.transportCost,
    required this.utilityCost,
    required this.totalCost,
    required this.expectedBags,
    required this.bagsConsumed,
    required this.costPerBag,
    required this.status,
    this.closedOn,
    this.notes,
  });

  factory ProductionLot.fromJson(Map<String, dynamic> json) {
    return ProductionLot(
      lotId: _toInt(json['lot_id']),
      lotNo: json['lot_no']?.toString() ?? '',
      openedOn: json['opened_on']?.toString() ?? '',
      materialCost: _toDouble(json['material_cost']),
      transportCost: _toDouble(json['transport_cost']),
      utilityCost: _toDouble(json['utility_cost']),
      totalCost: _toDouble(json['total_cost']),
      expectedBags: _toDouble(json['expected_bags']),
      bagsConsumed: _toDouble(json['bags_consumed']),
      costPerBag: _toDouble(json['cost_per_bag']),
      status: json['status']?.toString() ?? 'active',
      closedOn: json['closed_on']?.toString(),
      notes: (json['notes']?.toString().isEmpty ?? true)
          ? null
          : json['notes'].toString(),
    );
  }

  bool get isActive => status == 'active';
  double get bagsRemaining => expectedBags - bagsConsumed;
}

/// What a lot actually produced -- returned by lots/yield and lots/close.
class LotYield {
  final int batches;
  final double blocksProduced;
  final double expectedProfit;

  LotYield({
    required this.batches,
    required this.blocksProduced,
    required this.expectedProfit,
  });

  factory LotYield.fromJson(Map<String, dynamic> json) {
    return LotYield(
      batches: _toInt(json['batches']),
      blocksProduced: _toDouble(json['blocks_produced']),
      expectedProfit: _toDouble(json['expected_profit']),
    );
  }
}

class ProductionSettings {
  final int settingId;
  final int productionLocationId;
  final int? curingLocationId;
  final int defaultCuringDays;

  /// 'AVG' (purchase average, recommended) or 'COST' (static cost price).
  final String rawValuation;
  final bool blockOnShortStock;
  final bool reserveForSale;
  final double tolerancePct;
  final bool autoReleaseCured;

  ProductionSettings({
    required this.settingId,
    required this.productionLocationId,
    this.curingLocationId,
    required this.defaultCuringDays,
    required this.rawValuation,
    required this.blockOnShortStock,
    required this.reserveForSale,
    required this.tolerancePct,
    required this.autoReleaseCured,
  });

  factory ProductionSettings.fromJson(Map<String, dynamic> json) {
    bool flag(dynamic v) =>
        v == 1 || v == true || v?.toString() == '1';

    return ProductionSettings(
      settingId: _toInt(json['setting_id']),
      productionLocationId: _toInt(json['production_location_id']),
      curingLocationId: _toIntOrNull(json['curing_location_id']),
      defaultCuringDays: _toInt(json['default_curing_days'], fallback: 14),
      rawValuation: json['raw_valuation']?.toString() ?? 'AVG',
      blockOnShortStock: flag(json['block_on_short_stock']),
      reserveForSale: flag(json['reserve_for_sale']),
      tolerancePct: _toDouble(json['tolerance_pct'], fallback: 5),
      autoReleaseCured: flag(json['auto_release_cured']),
    );
  }

  /// The lib skips the curing hop entirely when this resolves to 0
  /// (commit dd75a7a54), so "no curing" is a real configuration.
  bool get hasCuringStep => curingLocationId != null && defaultCuringDays > 0;
}
