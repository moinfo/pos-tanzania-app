import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class PortalContractDetailScreen extends StatefulWidget {
  final Contract contract;

  const PortalContractDetailScreen({super.key, required this.contract});

  @override
  State<PortalContractDetailScreen> createState() =>
      _PortalContractDetailScreenState();
}

class _PortalContractDetailScreenState
    extends State<PortalContractDetailScreen> {
  final _service = CustomerApiService();
  ContractStatement? _statement;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await _service.getContractDetail(widget.contract.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _statement = response.data;
      } else {
        _error = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.contract;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(contract.contractDescription.isNotEmpty
            ? contract.contractDescription
            : 'Contract #${contract.id}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('Balance',
                              Formatters.formatCurrency(contract.balance)),
                          _row('Total Paid',
                              Formatters.formatCurrency(contract.payments)),
                          _row('Daily Rate',
                              Formatters.formatCurrency(contract.returnAmount)),
                          if (contract.penalty > 0)
                            _row('Late Fee (included)',
                                Formatters.formatCurrency(contract.penalty),
                                color: AppColors.error),
                          if (contract.repossessionFeeCharged > 0)
                            _row(
                                'Repossession Fee (included)',
                                Formatters.formatCurrency(
                                    contract.repossessionFeeCharged),
                                color: AppColors.error),
                          if (contract.isTerminated) ...[
                            const Divider(),
                            Text(
                              'This contract has been terminated'
                              '${(contract.terminationReason?.isNotEmpty ?? false) ? ': ${contract.terminationReason}' : '.'}',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.error,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    )
                  else if (_statement != null) ...[
                    const Text('Statement',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _buildStatementTable(_statement!),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatementTable(ContractStatement statement) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 32,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Paid')),
              DataColumn(label: Text('Balance')),
            ],
            rows: statement.statement.map((row) {
              final isSummary = row.type == 'opening' || row.type == 'closing';
              return DataRow(cells: [
                DataCell(Text(row.date, style: const TextStyle(fontSize: 12))),
                DataCell(Text(row.description,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSummary ? FontWeight.bold : FontWeight.normal))),
                DataCell(Text(
                    row.debit > 0 ? Formatters.formatCurrency(row.debit) : '—',
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(Formatters.formatCurrency(row.balance),
                    style: const TextStyle(fontSize: 12))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
