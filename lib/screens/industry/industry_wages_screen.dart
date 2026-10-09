import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_wages_verification_history_screen.dart';

class IndustryWagesScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryWagesScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryWagesScreen> createState() => _IndustryWagesScreenState();
}

class _IndustryWagesScreenState extends State<IndustryWagesScreen> with SingleTickerProviderStateMixin {
  WagesWeekData? _data;
  bool _isLoading = false;
  String? _errorMessage;
  int? _markingPaidId;
  int? _verifyingId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load({String? weekDate}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.service.getWagesCurrentWeek(weekDate: weekDate);

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      _tabController?.dispose();
      _tabController = TabController(length: data.groups.length, vsync: this);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickWeekOf() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_data?.referenceDate ?? '') ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _load(weekDate: DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _markPaid(int casualLabourerId) async {
    setState(() => _markingPaidId = casualLabourerId);

    final response = await widget.service.markWagePaid(casualLabourerId);

    if (!mounted) return;
    setState(() => _markingPaidId = null);

    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message),
        backgroundColor: response.isSuccess ? Colors.green : Colors.red,
      ),
    );

    if (response.isSuccess) _load(weekDate: _data?.referenceDate);
  }

  /// A wage can't be marked paid until verified (backend now enforces this -
  /// "Require attendance verification before a wage payment can be marked
  /// paid"). Shows the pay-week's day-by-day attendance before confirming,
  /// same as the web's verification modal.
  Future<void> _openVerifyDialog(WagesWeekRow row) async {
    final attendanceResponse = await widget.service.getAttendanceDetail(row.casualLabourerId);
    if (!mounted) return;

    if (attendanceResponse.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    final days = attendanceResponse.data ?? [];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Verify: ${row.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: days.isEmpty
              ? const Text('No attendance detail available.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: days
                      .map((d) => ListTile(
                            dense: true,
                            leading: Icon(
                              d.present ? Icons.check_circle : Icons.cancel,
                              color: d.present ? Colors.green : Colors.grey,
                              size: 18,
                            ),
                            title: Text(d.date),
                            subtitle: d.present
                                ? Text('${d.clockIn ?? '-'} – ${d.clockOut ?? '-'}'
                                    '${d.late ? ' (Late)' : ''}')
                                : null,
                            trailing: d.penalty > 0
                                ? Text('-${d.penalty.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.red, fontSize: 12))
                                : null,
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _verifyingId = row.casualLabourerId);
    final response = await widget.service.verifyWage(row.casualLabourerId);
    if (!mounted) return;
    setState(() => _verifyingId = null);

    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message),
        backgroundColor: response.isSuccess ? Colors.green : Colors.red,
      ),
    );

    if (response.isSuccess) _load(weekDate: _data?.referenceDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      );
    }
    return _buildBody();
  }

  Widget _statTile(String value, String label, {bool accent = false}) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: accent ? Colors.teal : Colors.black87, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: accent ? Colors.teal.shade700 : Colors.black87,
              )),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (data == null || data.groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: industryScrollPadding(context),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No labourer data for this week.')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final group in data.groups) _statTile(group.unpaidTotal, '${group.name} -- Unpaid'),
                  _statTile(data.totalUnpaid, 'Jumla -- Unpaid', accent: true),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 18, color: Colors.black87),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${data.isCurrentWeek ? 'Current Week' : 'Week Of'} — ${data.weekRangeDisplay}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              if (!data.isCurrentWeek)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Viewing a past week -- Verify/Mark Paid only apply to the current week',
                      style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800)),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('View Week Of', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _pickWeekOf,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(data.referenceDate.isEmpty ? 'Pick date' : data.referenceDate),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IndustryWagesVerificationHistoryScreen(
                          service: widget.service,
                          onSessionExpired: widget.onSessionExpired,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (_tabController != null)
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.brandPrimary,
              indicatorColor: AppColors.brandPrimary,
              unselectedLabelColor: Colors.black54,
              tabs: data.groups.map((g) => Tab(text: g.name)).toList(),
            ),
          ),
        Expanded(
          flex: 3,
          child: TabBarView(
            controller: _tabController,
            children: data.groups
                .map((group) => RefreshIndicator(
                      onRefresh: () => _load(weekDate: data.referenceDate),
                      child: group.labourers.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Center(child: Text('Hakuna wafanyakazi')),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: industryScrollPadding(context),
                              itemCount: group.labourers.length,
                              itemBuilder: (context, i) => _buildLabourerCard(group, group.labourers[i]),
                            ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLabourerCard(WagesWeekGroup group, WagesWeekRow row) {
    final isMarking = _markingPaidId == row.casualLabourerId;
    final isVerifying = _verifyingId == row.casualLabourerId;

    Widget infoChip(IconData icon, String label, String value, {Color? color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color ?? Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('$label: $value', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(row.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (!row.isPaidFlag)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Is Paid: No', style: TextStyle(fontSize: 9)),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: row.paid ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: row.paid ? Colors.green.shade200 : Colors.orange.shade200),
                  ),
                  child: Text(
                    row.paid ? 'Paid' : 'Unpaid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: row.paid ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                infoChip(Icons.checklist, group.isPieceRate ? 'CTN/Kibegi' : 'Days', row.quantityOrDays),
                infoChip(Icons.payments_outlined, 'Earned', row.gross),
                infoChip(
                  group.isPieceRate ? Icons.card_giftcard : Icons.remove_circle_outline,
                  group.isPieceRate ? 'Bonus' : 'Penalty',
                  row.bonusOrPenalty,
                  color: row.bonusOrPenaltyIsNegative ? Colors.red.shade50 : null,
                ),
                infoChip(Icons.volunteer_activism_outlined, 'Emergency', row.adjustment),
                infoChip(Icons.account_balance_wallet_outlined, 'Amount', row.amount,
                    color: Colors.green.shade50),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (row.verified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Verified', style: TextStyle(fontSize: 11, color: Colors.green)),
                  )
                else if (row.canVerify)
                  isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : OutlinedButton(
                          onPressed: () => _openVerifyDialog(row),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Verify', style: TextStyle(fontSize: 12)),
                        )
                else
                  Text('Not Verified', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const Spacer(),
                if (row.canMarkPaid)
                  isMarking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton(
                          onPressed: () => _markPaid(row.casualLabourerId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
