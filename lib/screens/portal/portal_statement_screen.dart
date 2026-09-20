import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../services/pdf_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// Classic date/credit/debit/balance statement with opening/closing
/// balances -- defaults to the current month, matching the backend's own
/// default when no range is given. Shareable as a PDF (parity with web's
/// "Pakua PDF" window.print()).
class PortalStatementScreen extends StatefulWidget {
  final Contract contract;

  const PortalStatementScreen({super.key, required this.contract});

  @override
  State<PortalStatementScreen> createState() => _PortalStatementScreenState();
}

class _PortalStatementScreenState extends State<PortalStatementScreen> {
  final _service = CustomerApiService();
  List<StatementEntry>? _statement;
  bool _isLoading = true;
  bool _isSharing = false;
  String? _error;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _tenantName;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _tenantName ??= await _service.getTenantName();
    final response = await _service.getContractStatement(
      widget.contract.id,
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _statement = response.data!.statement;
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
      _load();
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _endDate = date);
      _load();
    }
  }

  Future<void> _share() async {
    if (_statement == null || _statement!.isEmpty) return;
    setState(() => _isSharing = true);
    try {
      await PdfService.shareContractStatementPdf(
        contractName: widget.contract.name,
        contractDescription: widget.contract.contractDescription,
        statement: _statement!,
        startDate: Formatters.formatDateForApi(_startDate),
        endDate: Formatters.formatDateForApi(_endDate),
        companyName: _tenantName,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Taarifa (Statement)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.ios_share),
            tooltip: 'Shiriki PDF',
            onPressed: (_statement == null || _statement!.isEmpty || _isSharing)
                ? null
                : _share,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text(
                        Formatters.formatDate(
                            Formatters.formatDateForApi(_startDate)),
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('hadi', style: TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text(
                        Formatters.formatDate(
                            Formatters.formatDateForApi(_endDate)),
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : (_statement == null || _statement!.isEmpty)
                          ? ListView(children: const [
                              SizedBox(height: 60),
                              Center(
                                  child: Text('Hakuna data kwa kipindi hiki.')),
                            ])
                          : _buildTable(_statement!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<StatementEntry> statement) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: statement.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _statementRow(statement[index]),
    );
  }

  Widget _statementRow(StatementEntry entry) {
    final isSpecial = entry.type == 'opening' || entry.type == 'closing';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSpecial ? AppColors.primary.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isSpecial
                ? AppColors.primary.withOpacity(0.2)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.description,
                  style: TextStyle(
                      fontSize: isSpecial ? 13 : 12.5,
                      fontWeight:
                          isSpecial ? FontWeight.bold : FontWeight.w500)),
              Text(entry.date,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textLight)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _amountCol('Credit', entry.credit, AppColors.success)),
              Expanded(
                  child: _amountCol('Debit', entry.debit, AppColors.error)),
              Expanded(
                child: _amountCol(
                  'Balance',
                  entry.balance,
                  entry.balance >= 0 ? AppColors.text : AppColors.error,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountCol(String label, double value, Color color,
      {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
        Text(
            value == 0 && label != 'Balance'
                ? '—'
                : Formatters.formatCurrency(value),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color)),
      ],
    );
  }
}
