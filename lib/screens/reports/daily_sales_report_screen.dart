import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/horizontal_scroll_table.dart';

class DailySalesReportScreen extends StatefulWidget {
  const DailySalesReportScreen({super.key});

  @override
  State<DailySalesReportScreen> createState() => _DailySalesReportScreenState();
}

class _SalesRow {
  final String itemName;
  final double price;
  final double quantity;
  final double cash;
  final double bank;
  final double lipaNamba;
  final double credit;

  _SalesRow.fromJson(Map<String, dynamic> j)
      : itemName = j['item_name']?.toString() ?? '',
        price = (j['price'] as num?)?.toDouble() ?? 0,
        quantity = (j['quantity'] as num?)?.toDouble() ?? 0,
        cash = (j['cash'] as num?)?.toDouble() ?? 0,
        bank = (j['bank'] as num?)?.toDouble() ?? 0,
        lipaNamba = (j['lipa_namba'] as num?)?.toDouble() ?? 0,
        credit = (j['credit'] as num?)?.toDouble() ?? 0;
}

class _CollectionRow {
  final String customerName;
  final int paidPaymentType;
  final double amountPaid;
  final double remainingBalance;

  _CollectionRow.fromJson(Map<String, dynamic> j)
      : customerName = j['customer_name']?.toString() ?? '',
        paidPaymentType = (j['paid_payment_type'] as num?)?.toInt() ?? 0,
        amountPaid = (j['amount_paid'] as num?)?.toDouble() ?? 0,
        remainingBalance = (j['remaining_balance'] as num?)?.toDouble() ?? 0;

  static const _labels = {1: 'Cash', 2: 'Bank', 3: 'LIPA NAMBA'};
  String get paidVia => _labels[paidPaymentType] ?? '-';
}

class _CreditRow {
  final String customerName;
  final String itemsLabel;
  final double creditAmount;

  _CreditRow.fromJson(Map<String, dynamic> j)
      : customerName = j['customer_name']?.toString() ?? '',
        itemsLabel = j['items_label']?.toString() ?? '',
        creditAmount = (j['credit_amount'] as num?)?.toDouble() ?? 0;
}

class _ExpenseRow {
  final String categoryName;
  final String description;
  final String employeeName;
  final String paymentType;
  final double amount;

  _ExpenseRow.fromJson(Map<String, dynamic> j)
      : categoryName = j['category_name']?.toString() ?? '',
        description = j['description']?.toString() ?? '',
        employeeName = j['employee_name']?.toString() ?? '',
        paymentType = j['payment_type']?.toString() ?? '',
        amount = (j['amount'] as num?)?.toDouble() ?? 0;
}

class _DailySalesReportScreenState extends State<DailySalesReportScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _fmt = NumberFormat('#,##0');

  DateTime _date = DateTime.now();
  int? _stockLocationId;
  bool _isLoading = false;
  String? _errorMessage;

  List<_SalesRow> _salesMain = [];
  List<_SalesRow> _salesRejaReja = [];
  List<_CollectionRow> _collections = [];
  List<_CreditRow> _newCredit = [];
  List<_ExpenseRow> _expenses = [];

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

    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final response = await _apiService.getDailySalesReport(date: dateStr, stockLocationId: _stockLocationId);

    if (!mounted) return;

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
      return;
    }

    final data = response.data!;
    setState(() {
      _salesMain = ((data['sales_main'] as List?) ?? [])
          .map((e) => _SalesRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _salesRejaReja = ((data['sales_reja_reja'] as List?) ?? [])
          .map((e) => _SalesRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _collections = ((data['collections'] as List?) ?? [])
          .map((e) => _CollectionRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _newCredit = ((data['new_credit'] as List?) ?? [])
          .map((e) => _CreditRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _expenses = ((data['expenses'] as List?) ?? [])
          .map((e) => _ExpenseRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  String _formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Business Report'),
        backgroundColor: AppColors.brandPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    )
                  else ...[
                    _sectionTitle('Mauzo (Sales)'),
                    FadeSlideIn(child: _salesSubsection('Jumla (Main)', _salesMain)),
                    const SizedBox(height: 12),
                    FadeSlideIn(child: _salesSubsection('Reja Reja', _salesRejaReja)),
                    const SizedBox(height: 12),
                    FadeSlideIn(child: _grandTotalCard()),
                    const SizedBox(height: 24),
                    _sectionTitle('Makusanyo (Debt Collected)'),
                    FadeSlideIn(child: _collectionsTable()),
                    const SizedBox(height: 24),
                    _sectionTitle('Waliokopa (New Credit)'),
                    FadeSlideIn(child: _creditTable()),
                    const SizedBox(height: 24),
                    _sectionTitle('Matumizi (Expenses)'),
                    FadeSlideIn(child: _expensesTable()),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  child: Text(DateFormat('yyyy-MM-dd').format(_date)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Stock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _stockLocationId,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All stocks')),
                  ...context.watch<LocationProvider>().allowedLocations.map(
                        (loc) => DropdownMenuItem<int?>(
                          value: loc.locationId,
                          child: Text(loc.locationName, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                ],
                onChanged: (value) {
                  setState(() => _stockLocationId = value);
                  _load();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.brandPrimary)),
      );

  Map<String, double> _salesTotals(List<_SalesRow> rows) {
    double cash = 0, bank = 0, lipa = 0, credit = 0, qty = 0;
    for (final r in rows) {
      cash += r.cash;
      bank += r.bank;
      lipa += r.lipaNamba;
      credit += r.credit;
      qty += r.quantity;
    }
    return {'cash': cash, 'bank': bank, 'lipa_namba': lipa, 'credit': credit, 'quantity': qty};
  }

  Widget _salesSubsection(String title, List<_SalesRow> rows) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('$title: no sales on this date.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      );
    }
    final t = _salesTotals(rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        HorizontalScrollTable(
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            dividerThickness: 1,
            headingRowColor: WidgetStateProperty.all(AppColors.brandPrimary.withValues(alpha: 0.08)),
            columns: const [
              DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Lipa Namba', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            ],
            rows: rows
                .map((r) => DataRow(cells: [
                      DataCell(Text(r.itemName, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_fmt.format(r.price), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_formatQty(r.quantity), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(r.cash > 0 ? _fmt.format(r.cash) : '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(r.bank > 0 ? _fmt.format(r.bank) : '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(r.lipaNamba > 0 ? _fmt.format(r.lipaNamba) : '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(r.credit > 0 ? _fmt.format(r.credit) : '-', style: const TextStyle(fontSize: 12))),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Subtotal: ${_fmt.format(t['cash']! + t['bank']! + t['lipa_namba']! + t['credit']!)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _grandTotalCard() {
    final main = _salesTotals(_salesMain);
    final reja = _salesTotals(_salesRejaReja);
    final cash = main['cash']! + reja['cash']!;
    final bank = main['bank']! + reja['bank']!;
    final lipa = main['lipa_namba']! + reja['lipa_namba']!;
    final credit = main['credit']! + reja['credit']!;
    final total = cash + bank + lipa + credit;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text('Grand Total (Jumla + Reja Reja)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Divider(height: 16),
          _summaryRow('Cash', _fmt.format(cash)),
          _summaryRow('Bank', _fmt.format(bank)),
          _summaryRow('Lipa Namba', _fmt.format(lipa)),
          _summaryRow('Credit', _fmt.format(credit)),
          const Divider(height: 16),
          _summaryRow('Total Sales', _fmt.format(total), bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: bold ? AppColors.brandPrimary : Colors.black87,
              )),
        ],
      ),
    );
  }

  Widget _collectionsTable() {
    if (_collections.isEmpty) {
      return Text('No debt collected on this date.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13));
    }
    final total = _collections.fold<double>(0, (s, c) => s + c.amountPaid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HorizontalScrollTable(
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            dividerThickness: 1,
            headingRowColor: WidgetStateProperty.all(AppColors.brandPrimary.withValues(alpha: 0.08)),
            columns: const [
              DataColumn(label: Text('Debtor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Paid Via', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            ],
            rows: _collections
                .map((c) => DataRow(cells: [
                      DataCell(Text(c.customerName, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(c.paidVia, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_fmt.format(c.amountPaid), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_fmt.format(c.remainingBalance), style: const TextStyle(fontSize: 12))),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total Collected: ${_fmt.format(total)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _creditTable() {
    if (_newCredit.isEmpty) {
      return Text('No new credit sold on this date.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13));
    }
    final total = _newCredit.fold<double>(0, (s, c) => s + c.creditAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HorizontalScrollTable(
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            dividerThickness: 1,
            headingRowColor: WidgetStateProperty.all(AppColors.brandPrimary.withValues(alpha: 0.08)),
            columns: const [
              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Item(s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Credit Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            ],
            rows: _newCredit
                .map((c) => DataRow(cells: [
                      DataCell(Text(c.customerName, style: const TextStyle(fontSize: 12))),
                      DataCell(SizedBox(width: 200, child: Text(c.itemsLabel, style: const TextStyle(fontSize: 12)))),
                      DataCell(Text(_fmt.format(c.creditAmount), style: const TextStyle(fontSize: 12))),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total New Credit: ${_fmt.format(total)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _expensesTable() {
    if (_expenses.isEmpty) {
      return Text('No expenses on this date.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13));
    }
    final total = _expenses.fold<double>(0, (s, e) => s + e.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HorizontalScrollTable(
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            dividerThickness: 1,
            headingRowColor: WidgetStateProperty.all(AppColors.brandPrimary.withValues(alpha: 0.08)),
            columns: const [
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Paid By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Payment Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            ],
            rows: _expenses
                .map((e) => DataRow(cells: [
                      DataCell(Text(e.categoryName, style: const TextStyle(fontSize: 12))),
                      DataCell(SizedBox(width: 160, child: Text(e.description, style: const TextStyle(fontSize: 12)))),
                      DataCell(Text(e.employeeName, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(e.paymentType, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_fmt.format(e.amount), style: const TextStyle(fontSize: 12))),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total Expenses: ${_fmt.format(total)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}
