import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/approval.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/state_views.dart';
import 'create_credit_limit_request_screen.dart';
import 'credit_limits_screen.dart' show OutcomeBadge, outcomeColour;

/// One customer's whole credit-limit story.
///
/// The web equivalent is customer_credit_limits/customer_history: who the
/// customer is, what allowance they hold now, four quick counts, and a
/// timeline of every record they have ever had.
///
/// The headline is the ONE-TIME allowance, not people.credit_limit. This
/// module writes people.one_time_credit_limit and customers.one_time_credit;
/// it has never touched the standing limit, which is 0 for most customers on
/// this system and would be a misleading thing to lead with.
class CustomerCreditHistoryScreen extends StatefulWidget {
  const CustomerCreditHistoryScreen({
    super.key,
    required this.customerId,
    this.customerName,
  });

  final int customerId;

  /// Shown in the app bar while the body is still loading, when the caller
  /// already knows it.
  final String? customerName;

  @override
  State<CustomerCreditHistoryScreen> createState() =>
      _CustomerCreditHistoryScreenState();
}

class _CustomerCreditHistoryScreenState
    extends State<CustomerCreditHistoryScreen> {
  final _api = ApiService();
  final _money = NumberFormat('#,##0', 'en_US');

  CustomerCreditHistory? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final response = await _api.getCustomerCreditHistory(widget.customerId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (response.isSuccess && response.data != null) {
        _data = response.data;
      } else {
        _error = FriendlyError.of(response.message);
      }
    });
  }

  Future<void> _requestMore() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCreditLimitRequestScreen(
          customerId: widget.customerId,
          customerName: _data?.customer.customerName ?? widget.customerName,
        ),
      ),
    );
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_data?.customer.customerName ??
            widget.customerName ??
            'Credit History'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(isDark),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) return _skeleton(isDark);

    final data = _data;
    if (data == null) {
      return ErrorStateView(
        message: _error ?? 'Could not load',
        onRetry: FriendlyError.isPermanent(_error) ? null : _load,
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _headline(data, isDark),
          const SizedBox(height: 12),
          _quickStats(data.statistics, isDark),
          const SizedBox(height: 12),
          if (data.current != null) ...[
            _currentCard(data.current!, isDark),
            const SizedBox(height: 12),
          ],
          if (data.statistics.staleStatusRows > 0) ...[
            _staleNotice(data.statistics.staleStatusRows, isDark),
            const SizedBox(height: 12),
          ],
          _sectionTitle('Every request for this customer', isDark),
          const SizedBox(height: 8),
          if (data.history.isEmpty)
            EmptyStateView(
              icon: Icons.history_toggle_off,
              title: 'No credit limit records',
              message: 'Nothing has ever been requested for this customer.',
              isDark: isDark,
            )
          else
            for (var i = 0; i < data.history.length; i++) ...[
              _TimelineEntry(
                row: data.history[i],
                index: i + 1,
                isLast: i == data.history.length - 1,
                money: _money,
                isDark: isDark,
              ),
            ],
          if (data.truncated) ...[
            const SizedBox(height: 6),
            Text(
              'Showing the most recent ${data.history.length} of '
              '${_money.format(data.statistics.total)} records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _requestMore,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Request an allowance for this customer'),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SkeletonLoader(
            width: double.infinity, height: 176, borderRadius: 16, isDark: isDark),
        const SizedBox(height: 12),
        SkeletonLoader(
            width: double.infinity, height: 82, borderRadius: 14, isDark: isDark),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++) ...[
          SkeletonLoader(
              width: double.infinity, height: 96, borderRadius: 14, isDark: isDark),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// What the customer is holding right now — the number a seller standing in
  /// the shop actually needs.
  Widget _headline(CustomerCreditHistory data, bool isDark) {
    final customer = data.customer;
    final holding = customer.hasOneTimeCredit && customer.oneTimeLimit > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D7DC4), Color(0xFF155E92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            holding ? 'UNSPENT ONE-TIME ALLOWANCE' : 'NO ALLOWANCE HELD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_money.format(holding ? customer.oneTimeLimit : 0)} TSh',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            holding
                ? 'the next credit sale will use this up'
                : 'nothing granted and unspent right now',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          _line('Owed now', '${_money.format(customer.currentBalance)} TSh'),
          _line('Standing limit',
              '${_money.format(customer.creditLimit)} TSh'),
          if (customer.phoneNumber != null)
            _line('Phone', customer.phoneNumber!),
          if (customer.supervisorName != null)
            _line('Supervisor', customer.supervisorName!),
          if (!customer.creditAllowed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This customer cannot buy on credit. An allowance will '
                      'not help until that is granted.',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The web's four quick-statistics tiles. "Rejected" is one of them, and on
  /// the web it can never be anything but zero -- it counts status ==
  /// 'rejected' against a column whose enum has no such member. This counts
  /// the approval trail instead, so a rejection actually shows.
  Widget _quickStats(CreditLimitStatistics stats, bool isDark) {
    return Row(
      children: [
        _statTile('Total', stats.total, AppColors.primary, isDark),
        const SizedBox(width: 8),
        _statTile('Granted', stats.approved, AppColors.success, isDark),
        const SizedBox(width: 8),
        _statTile('Waiting', stats.awaiting, AppColors.warning, isDark),
        const SizedBox(width: 8),
        _statTile('Rejected', stats.rejected, AppColors.error, isDark),
      ],
    );
  }

  Widget _statTile(String label, int count, Color accent, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _money.format(count),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentCard(CurrentCreditLimit current, bool isDark) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Standing record: ${current.documentNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ),
              Text(
                '${_money.format(current.creditAmount)} TSh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Effective ${_date(current.effectiveDate)}'
            '${current.expiryDate == null ? '' : ' · expires ${_date(current.expiryDate)}'}',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _staleNotice(int count, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.build_circle_outlined,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_money.format(count)} of these records are still stored as '
              '"pending" although they were settled long ago. The badges below '
              'show what actually happened, taken from the approval trail.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
      ),
    );
  }

  String _date(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

/// One record on the timeline, with the rail down the left.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.row,
    required this.index,
    required this.isLast,
    required this.money,
    required this.isDark,
  });

  final CreditLimitRow row;
  final int index;
  final bool isLast;
  final NumberFormat money;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final accent = outcomeColour(row.outcome);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.documentNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              OutcomeBadge(
                                  outcome: row.outcome,
                                  stale: row.statusIsStale),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${money.format(row.creditAmount)} TSh',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    if (row.statusIsStale) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Stored as "${row.storedStatus}" — never written back.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: muted,
                        ),
                      ),
                    ],
                    if (row.reason != null && row.reason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        row.reason!,
                        style: TextStyle(
                            fontSize: 12, color: muted, height: 1.3),
                      ),
                    ],
                    if (row.notes != null && row.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        row.notes!,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: muted,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _detail('Effective', _date(row.effectiveDate), muted),
                    if (row.expiryDate != null)
                      _detail('Expires', _date(row.expiryDate), muted),
                    _detail('Balance then',
                        '${money.format(row.currentBalance)} TSh', muted),
                    _detail(
                        'Raised by',
                        '${row.createdByName ?? 'Unknown'} · '
                            '${_dateTime(row.createdAt)}',
                        muted),
                    if (row.decidedByName != null)
                      _detail(
                          'Decided by',
                          '${row.decidedByName} · ${_dateTime(row.decidedAt)}',
                          muted)
                    else if (row.approvedByName != null)
                      _detail(
                          'Approved by',
                          '${row.approvedByName} · ${_dateTime(row.approvedAt)}',
                          muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: TextStyle(fontSize: 11, color: muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _date(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _dateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}
