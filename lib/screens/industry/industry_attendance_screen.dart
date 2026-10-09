import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../services/api_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';

class IndustryAttendanceScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryAttendanceScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryAttendanceScreen> createState() => _IndustryAttendanceScreenState();
}

class _IndustryAttendanceScreenState extends State<IndustryAttendanceScreen> {
  final ApiService _apiService = ApiService();

  List<AttendanceRosterEntry> _roster = [];
  List<AttendanceDevice> _devices = [];
  List<UnmatchedPunch> _unmatched = [];
  String? _expectedIn;
  String? _expectedOut;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

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

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final rosterResponse = await widget.service.getRoster(date: dateStr);
    final devicesResponse = await _apiService.getAttendanceDevices();
    final unmatchedResponse = await _apiService.getUnmatchedAttendance();
    final settingsResponse = await widget.service.getSettingsValues();

    if (!mounted) return;

    if (rosterResponse.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    setState(() {
      _isLoading = false;
      if (rosterResponse.isSuccess) {
        _roster = rosterResponse.data ?? [];
      } else {
        _errorMessage = rosterResponse.message;
      }
      _devices = devicesResponse.data ?? [];
      _unmatched = unmatchedResponse.data ?? [];
      if (settingsResponse.isSuccess && settingsResponse.data != null) {
        _expectedIn = settingsResponse.data!.clockInTime;
        _expectedOut = settingsResponse.data!.clockOutTime;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _openAdjustDialog(AttendanceRosterEntry entry) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adjust Pay: ${entry.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (negative to deduct)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text) ?? 0;

    final response = await widget.service.saveWageAdjustment(
      casualLabourerId: entry.casualLabourerId,
      adjustmentDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      amount: amount,
      note: noteController.text,
    );

    if (!mounted) return;

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

    if (response.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody();
  }

  Widget _buildBody() {
    final presentCount = _roster.where((e) => e.present).length;
    final totalEarned = _roster.fold<double>(0, (sum, e) => sum + e.gross);
    final totalPenalty = _roster.fold<double>(0, (sum, e) => sum + e.penalty);
    final totalNet = _roster.fold<double>(0, (sum, e) => sum + e.net);
    final fmt = NumberFormat('#,##0');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_expectedIn != null && _expectedOut != null && _expectedIn!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Expected $_expectedIn – $_expectedOut',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('d MMM yyyy').format(_selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statTile('$presentCount', 'PRESENT'),
              _statTile(fmt.format(totalEarned), 'EARNED', accent: true),
              _statTile(fmt.format(totalPenalty), 'PENALTY'),
              _statTile(fmt.format(totalNet), 'NET PAY', accent: true),
            ],
          ),
          const SizedBox(height: 16),
          Text('Roster (${_roster.length})',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
          const SizedBox(height: 8),
          if (_roster.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No roster data for this date.'),
            )
          else
            ..._roster.map(_buildRosterRow),
          if (_unmatched.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildUnmatchedPanel(),
          ],
          if (_devices.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDevicesPanel(),
          ],
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, {bool accent = false}) {
    return Container(
      width: 150,
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
                fontSize: 20,
                color: accent ? Colors.teal.shade700 : Colors.black87,
              )),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _panelCard({required String title, required IconData icon, required Color headerColor, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: headerColor,
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  Widget _buildUnmatchedPanel() {
    return _panelCard(
      title: 'Unmapped Device Users',
      icon: Icons.warning_amber,
      headerColor: Colors.deepOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These device user IDs have punched but are not linked to any casual labourer. '
            'Set the Device User ID on the labourer to link them - their past attendance will be filled in automatically.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
          ),
          const SizedBox(height: 10),
          ..._unmatched.map((u) => Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(u.deviceUserId, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${u.punchCount} punches', style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(u.lastPunch ?? '-',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDevicesPanel() {
    return _panelCard(
      title: 'Attendance Devices',
      icon: Icons.dns_outlined,
      headerColor: AppColors.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _devices.map((d) {
          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(d.deviceIp, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(d.lastSync ?? '-', style: const TextStyle(fontSize: 12)),
                      if (d.isStale)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Not syncing',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(d.lastPunch ?? '-', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${d.punchCount}',
                      style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRosterRow(AttendanceRosterEntry entry) {
    final fmt = NumberFormat('#,##0');

    Widget infoChip(IconData icon, String text, {Color? color}) => Container(
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
              Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
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
                  child: Text(entry.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.present ? Colors.blue.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: entry.present ? Colors.blue.shade200 : Colors.grey.shade300),
                  ),
                  child: Text(
                    entry.present ? 'Device' : 'Absent',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: entry.present ? Colors.blue.shade800 : Colors.grey.shade600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 20),
                  tooltip: 'Emergency Pay',
                  onPressed: () => _openAdjustDialog(entry),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (entry.phoneNumber != null && entry.phoneNumber!.isNotEmpty)
                  infoChip(Icons.phone_outlined, entry.phoneNumber!),
                if (entry.present) ...[
                  infoChip(Icons.login, entry.clockIn ?? '-'),
                  infoChip(Icons.logout, entry.clockOut ?? '-'),
                  if (entry.hoursDisplay != null && entry.hoursDisplay!.isNotEmpty)
                    infoChip(Icons.schedule, entry.hoursDisplay!),
                  if (entry.late)
                    infoChip(Icons.warning_amber, '${entry.minutesLate}min',
                        color: Colors.orange.shade50),
                ],
                infoChip(Icons.payments_outlined, fmt.format(entry.gross)),
                if (entry.penalty > 0)
                  infoChip(Icons.remove_circle_outline, '-${fmt.format(entry.penalty)}',
                      color: Colors.red.shade50),
                infoChip(Icons.account_balance_wallet_outlined, fmt.format(entry.net),
                    color: Colors.green.shade50),
                if (entry.adjustmentAmount != 0)
                  infoChip(Icons.card_giftcard, '+${fmt.format(entry.adjustmentAmount)}',
                      color: Colors.teal.shade50),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
