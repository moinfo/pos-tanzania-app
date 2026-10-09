import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';

class IndustryAttendanceLogScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryAttendanceLogScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryAttendanceLogScreen> createState() => _IndustryAttendanceLogScreenState();
}

class _IndustryAttendanceLogScreenState extends State<IndustryAttendanceLogScreen> {
  AttendanceLogPage? _page;
  bool _isLoading = false;
  String? _errorMessage;
  bool _unmappedOnly = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();
  int _currentPage = 1;

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

    final response = await widget.service.getAttendanceLog(
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      unmappedOnly: _unmappedOnly,
      page: _currentPage,
    );

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess && response.data != null) {
      setState(() {
        _page = response.data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody();
  }

  Widget _buildBody() {
    final page = _page;
    final summary = page?.summary ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          const Text('Attendance Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statTile('${summary['total_punches'] ?? 0}', 'PUNCHES'),
              _statTile('${summary['distinct_users'] ?? 0}', 'DEVICE USERS', accent: true),
              _statTile('${summary['distinct_days'] ?? 0}', 'DAYS COVERED'),
              _statTile('${summary['unmapped_punches'] ?? 0}', 'UNMAPPED PUNCHES', accent: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('d MMM').format(_startDate)} - ${DateFormat('d MMM yyyy').format(_endDate)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: const Text('Change range'),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Unmapped only', style: TextStyle(fontSize: 14)),
            value: _unmappedOnly,
            onChanged: (v) {
              setState(() {
                _unmappedOnly = v;
                _currentPage = 1;
              });
              _load();
            },
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 4),
          if (page == null || page.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No punches for this range.')),
            )
          else
            ...page.rows.map(_buildRow),
          if (page != null && page.totalPages > 1) _buildPager(page),
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

  Widget _buildRow(AttendanceLogRow row) {
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
        side: BorderSide(color: row.mapped ? Colors.grey.shade200 : Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.labourerName?.isNotEmpty == true ? row.labourerName! : 'Device user ${row.deviceUserId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: row.mapped ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: row.mapped ? Colors.green.shade200 : Colors.orange.shade200),
                  ),
                  child: Text(
                    row.mapped ? 'Mapped' : 'Unmapped',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: row.mapped ? Colors.green.shade800 : Colors.orange.shade800,
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
                infoChip(Icons.access_time, row.punchTime ?? '-'),
                infoChip(Icons.calendar_today, row.workDate ?? '-'),
                infoChip(Icons.router_outlined, row.deviceIp),
                infoChip(Icons.fingerprint, 'ID: ${row.deviceUserId}'),
                if (row.syncedDate != null && row.syncedDate!.isNotEmpty)
                  infoChip(Icons.sync, row.syncedDate!, color: Colors.blue.shade50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPager(AttendanceLogPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _load();
                  }
                : null,
          ),
          Text('Page $_currentPage of ${page.totalPages}'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < page.totalPages
                ? () {
                    setState(() => _currentPage++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
