// Report models for the Reports API

/// Column definition for dynamic table rendering
class ReportColumn {
  final String key;
  final String label;
  final String type; // 'string', 'number', 'currency', 'date', 'percent'

  ReportColumn({
    required this.key,
    required this.label,
    required this.type,
  });

  factory ReportColumn.fromJson(Map<String, dynamic> json) {
    return ReportColumn(
      key: json['key'] as String,
      label: json['label'] as String,
      type: json['type'] as String? ?? 'string',
    );
  }
}

/// Generic report data structure
class ReportData {
  final String reportType;
  final Map<String, dynamic> filters;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? totals;

  ReportData({
    required this.reportType,
    required this.filters,
    required this.columns,
    required this.rows,
    this.totals,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      reportType: json['report_type'] as String? ?? '',
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      columns: (json['columns'] as List?)
              ?.map((c) => ReportColumn.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      rows: (json['rows'] as List?)
              ?.map((r) => r as Map<String, dynamic>)
              .toList() ??
          [],
      totals: json['totals'] as Map<String, dynamic>?,
    );
  }
}

/// Graphical report data for charts
class GraphicalReportData {
  final String reportType;
  final String chartType; // 'line', 'bar', 'pie'
  final ChartData chartData;
  final Map<String, dynamic> summary;

  GraphicalReportData({
    required this.reportType,
    required this.chartType,
    required this.chartData,
    required this.summary,
  });

  factory GraphicalReportData.fromJson(Map<String, dynamic> json) {
    return GraphicalReportData(
      reportType: json['report_type'] as String? ?? '',
      chartType: json['chart_type'] as String? ?? 'line',
      chartData: ChartData.fromJson(json['chart_data'] as Map<String, dynamic>? ?? {}),
      summary: json['summary'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Chart data structure
class ChartData {
  final List<String> labels;
  final List<ChartDataset> datasets;

  ChartData({
    required this.labels,
    required this.datasets,
  });

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      labels: (json['labels'] as List?)?.map((l) => l.toString()).toList() ?? [],
      datasets: (json['datasets'] as List?)
              ?.map((d) => ChartDataset.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Chart dataset
class ChartDataset {
  final String label;
  final List<double> data;
  final String color;

  ChartDataset({
    required this.label,
    required this.data,
    required this.color,
  });

  factory ChartDataset.fromJson(Map<String, dynamic> json) {
    return ChartDataset(
      label: json['label'] as String? ?? '',
      data: (json['data'] as List?)?.map((d) => (d as num).toDouble()).toList() ?? [],
      color: json['color'] as String? ?? '#000000',
    );
  }
}

/// Inventory report item
class InventoryReportItem {
  final int itemId;
  final String itemName;
  final String? itemNumber;
  final String? category;
  final double quantity;
  final double? reorderLevel;
  final double? costPrice;
  final double? unitPrice;
  final double? totalCost;
  final double? totalValue;

  InventoryReportItem({
    required this.itemId,
    required this.itemName,
    this.itemNumber,
    this.category,
    required this.quantity,
    this.reorderLevel,
    this.costPrice,
    this.unitPrice,
    this.totalCost,
    this.totalValue,
  });

  factory InventoryReportItem.fromJson(Map<String, dynamic> json) {
    return InventoryReportItem(
      itemId: json['item_id'] as int? ?? 0,
      itemName: json['item_name'] as String? ?? '',
      itemNumber: json['item_number'] as String?,
      category: json['category'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      totalValue: (json['total_value'] as num?)?.toDouble(),
    );
  }
}

/// Specific customer/employee report data
class SpecificReportData {
  final String reportType;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic> filters;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? totals;

  SpecificReportData({
    required this.reportType,
    this.customer,
    this.employee,
    required this.filters,
    required this.columns,
    required this.rows,
    this.totals,
  });

  factory SpecificReportData.fromJson(Map<String, dynamic> json) {
    return SpecificReportData(
      reportType: json['report_type'] as String? ?? '',
      customer: json['customer'] as Map<String, dynamic>?,
      employee: json['employee'] as Map<String, dynamic>?,
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      columns: (json['columns'] as List?)
              ?.map((c) => ReportColumn.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      rows: (json['rows'] as List?)
              ?.map((r) => r as Map<String, dynamic>)
              .toList() ??
          [],
      totals: json['totals'] as Map<String, dynamic>?,
    );
  }
}

/// Report types enumeration
enum ReportType {
  // Summary Reports
  summarySales,
  summaryItems,
  summaryCategories,
  summaryCustomers,
  summaryEmployees,
  summaryPayments,
  summaryExpenses,
  summaryDiscounts,
  summaryTaxes,
  summarySalesTaxes,
  summarySuppliers,

  // Detailed Reports
  detailedSales,
  detailedReceivings,
  detailedCustomers,
  detailedEmployees,
  detailedDiscounts,

  // Inventory Reports
  inventorySummary,
  inventoryLow,

  // Specific Reports
  specificCustomer,
  specificEmployee,

  // Graphical Reports
  graphicalSales,
  graphicalItems,
  graphicalCategories,
}

extension ReportTypeExtension on ReportType {
  String get apiPath {
    switch (this) {
      case ReportType.summarySales:
        return 'reports/summary/sales';
      case ReportType.summaryItems:
        return 'reports/summary/items';
      case ReportType.summaryCategories:
        return 'reports/summary/categories';
      case ReportType.summaryCustomers:
        return 'reports/summary/customers';
      case ReportType.summaryEmployees:
        return 'reports/summary/employees';
      case ReportType.summaryPayments:
        return 'reports/summary/payments';
      case ReportType.summaryExpenses:
        return 'reports/summary/expenses';
      case ReportType.summaryDiscounts:
        return 'reports/summary/discounts';
      case ReportType.summaryTaxes:
        return 'reports/summary/taxes';
      case ReportType.summarySalesTaxes:
        return 'reports/summary/sales_taxes';
      case ReportType.summarySuppliers:
        return 'reports/summary/suppliers';
      case ReportType.detailedSales:
        return 'reports/detailed/sales';
      case ReportType.detailedReceivings:
        return 'reports/detailed/receivings';
      case ReportType.detailedCustomers:
        return 'reports/detailed/customers';
      case ReportType.detailedEmployees:
        return 'reports/detailed/employees';
      case ReportType.detailedDiscounts:
        return 'reports/detailed/discounts';
      case ReportType.inventorySummary:
        return 'reports/inventory/summary';
      case ReportType.inventoryLow:
        return 'reports/inventory/low';
      case ReportType.specificCustomer:
        return 'reports/specific/customer';
      case ReportType.specificEmployee:
        return 'reports/specific/employee';
      case ReportType.graphicalSales:
        return 'reports/graphical/sales';
      case ReportType.graphicalItems:
        return 'reports/graphical/items';
      case ReportType.graphicalCategories:
        return 'reports/graphical/categories';
    }
  }

  String get displayName {
    switch (this) {
      case ReportType.summarySales:
        return 'Sales Summary';
      case ReportType.summaryItems:
        return 'Items Summary';
      case ReportType.summaryCategories:
        return 'Categories Summary';
      case ReportType.summaryCustomers:
        return 'Customers Summary';
      case ReportType.summaryEmployees:
        return 'Employees Summary';
      case ReportType.summaryPayments:
        return 'Payments Summary';
      case ReportType.summaryExpenses:
        return 'Expenses Summary';
      case ReportType.summaryDiscounts:
        return 'Discounts Summary';
      case ReportType.summaryTaxes:
        return 'Taxes Summary';
      case ReportType.summarySalesTaxes:
        return 'Sales Taxes Summary';
      case ReportType.summarySuppliers:
        return 'Suppliers Summary';
      case ReportType.detailedSales:
        return 'Detailed Sales';
      case ReportType.detailedReceivings:
        return 'Detailed Receivings';
      case ReportType.detailedCustomers:
        return 'Detailed Customers';
      case ReportType.detailedEmployees:
        return 'Detailed Employees';
      case ReportType.detailedDiscounts:
        return 'Detailed Discounts';
      case ReportType.inventorySummary:
        return 'Inventory Summary';
      case ReportType.inventoryLow:
        return 'Low Stock Items';
      case ReportType.specificCustomer:
        return 'Customer Report';
      case ReportType.specificEmployee:
        return 'Employee Report';
      case ReportType.graphicalSales:
        return 'Sales Chart';
      case ReportType.graphicalItems:
        return 'Items Chart';
      case ReportType.graphicalCategories:
        return 'Categories Chart';
    }
  }

  String get iconName {
    switch (this) {
      case ReportType.summarySales:
      case ReportType.detailedSales:
      case ReportType.graphicalSales:
        return 'shopping_cart';
      case ReportType.summaryItems:
      case ReportType.graphicalItems:
        return 'inventory_2';
      case ReportType.summaryCategories:
      case ReportType.graphicalCategories:
        return 'category';
      case ReportType.summaryCustomers:
      case ReportType.detailedCustomers:
      case ReportType.specificCustomer:
        return 'people';
      case ReportType.summaryEmployees:
      case ReportType.detailedEmployees:
      case ReportType.specificEmployee:
        return 'badge';
      case ReportType.summaryPayments:
        return 'payments';
      case ReportType.summaryExpenses:
        return 'receipt_long';
      case ReportType.summaryDiscounts:
      case ReportType.detailedDiscounts:
        return 'local_offer';
      case ReportType.summaryTaxes:
      case ReportType.summarySalesTaxes:
        return 'account_balance';
      case ReportType.summarySuppliers:
        return 'local_shipping';
      case ReportType.detailedReceivings:
        return 'move_to_inbox';
      case ReportType.inventorySummary:
        return 'inventory';
      case ReportType.inventoryLow:
        return 'warning';
    }
  }
}
