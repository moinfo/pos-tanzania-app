import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';

class IndustryWagesVerificationHistoryScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryWagesVerificationHistoryScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryWagesVerificationHistoryScreen> createState() =>
      _IndustryWagesVerificationHistoryScreenState();
}

class _IndustryWagesVerificationHistoryScreenState
    extends State<IndustryWagesVerificationHistoryScreen> {
  List<WageVerificationRow> _rows = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = '';

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

    final response = await widget.service.getVerificationHistory(status: _statusFilter);

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess && response.data != null) {
      setState(() {
        _rows = response.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification History'),
        backgroundColor: AppColors.brandPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '', child: Text('All')),
                DropdownMenuItem(value: 'unpaid', child: Text('Verified & Not Paid')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v ?? '');
                _load();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _rows.isEmpty
                            ? ListView(children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Center(child: Text('No verification history found.')),
                                ),
                              ])
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    16, 0, 16, 16 + MediaQuery.of(context).size.height * 0.05),
                                itemCount: _rows.length,
                                itemBuilder: (context, i) => _buildRow(_rows[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(WageVerificationRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(row.labourerName),
        subtitle: Text(
          '${row.weekStartDate} - ${row.weekEndDate} · ${row.daysAttended} day(s)\n'
          'Verified by ${row.verifiedByName ?? '-'} on ${row.verifiedAt ?? '-'}'
          '${row.paid ? '\nPaid by ${row.paidByName ?? '-'} on ${row.paidDate ?? '-'}' : ''}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(row.amount.toStringAsFixed(0),
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: row.paid ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.paid ? 'Paid' : 'Unpaid',
                style: TextStyle(
                  fontSize: 11,
                  color: row.paid ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
