import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/api_response.dart';
import '../models/approval.dart';
import '../models/permission_model.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/date_range_filter_bar.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/state_views.dart';
import 'create_credit_limit_request_screen.dart';
import 'customer_credit_history_screen.dart';

/// The customer credit limit module, not just its request form.
///
/// The drawer entry used to open the create form directly, which meant the
/// only thing the app could do with this module was add to it. The web offers
/// a list, four figures over it, a per-customer history and a list of unspent
/// allowances; this screen is the mobile half of that, and creating is now an
/// action from here as it is on the web.
///
/// WHAT THIS MODULE GRANTS
/// -----------------------
/// A ONE-TIME allowance, written to people.one_time_credit_limit and flagged
/// on customers.one_time_credit, consumed by the customer's next credit sale.
/// It is not the standing credit_limit, which this module has never touched
/// and which is 0 for most customers here. Every figure on this screen is
/// about the one-time allowance.
///
/// WHY THE STATUSES LOOK ODD
/// -------------------------
/// Until 21 August 2026 the step that writes a record's status back after
/// approval could never run, so 1,891 of 1,892 records store "pending"
/// whatever became of them, and 1,441 of those predate the approval workflow
/// entirely. The server derives what actually happened from the approval
/// trail; this screen shows that, and says plainly how many records carry a
/// stored status that disagrees rather than quietly hiding the discrepancy.
class CreditLimitsScreen extends StatefulWidget {
  const CreditLimitsScreen({super.key});

  @override
  State<CreditLimitsScreen> createState() => _CreditLimitsScreenState();
}

class _CreditLimitsScreenState extends State<CreditLimitsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _money = NumberFormat('#,##0', 'en_US');
  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  late final TabController _tabs;

  static const _pageSize = 40;

  // ---- the list tab ----
  final List<CreditLimitRow> _rows = [];
  CreditLimitStatistics _stats = const CreditLimitStatistics();
  CreditLimitPage? _page;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// null means "every status"; otherwise one of the six outcomes.
  CreditLimitOutcome? _statusFilter;

  /// null means "the default", which the server reads as TODAY. It used to
  /// mean all time, which is why this screen opened on 1,892 records.
  DateTimeRange? _range;
  String _search = '';
  Timer? _searchDebounce;

  /// Bumped per load. A slow first page landing after a fast filtered one
  /// would otherwise leave the list disagreeing with the chips.
  int _generation = 0;

  // ---- the unused-allowance tab ----
  UnusedAllowanceList? _unused;
  bool _loadingUnused = true;
  String? _unusedError;

  bool get _canCreate => context
      .read<PermissionProvider>()
      .hasPermission(PermissionIds.customerCreditLimitsAdd);

  /// The server decides this, and re-states it on every response. The
  /// permission is read only so the calendar action is right on first frame,
  /// before anything has come back.
  bool get _canFilterDate =>
      _page?.canFilterDate ??
      context
          .read<PermissionProvider>()
          .hasPermission(PermissionIds.customerCreditLimitsFilterDate);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _scroll.addListener(_onScroll);
    _load();
    _loadUnused();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 400) return;
    _loadMore();
  }

  String? get _dateFrom => _range == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_range!.start);

  String? get _dateTo =>
      _range == null ? null : DateFormat('yyyy-MM-dd').format(_range!.end);

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    // The figures and the first page describe the same filtered set, so they
    // are fetched together -- a stat card that disagrees with the rows under
    // it is worse than no stat card.
    final results = await Future.wait([
      _api.getCreditLimitRequests(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _statusFilter?.wire,
        search: _search,
        limit: _pageSize,
      ),
      _api.getCreditLimitStatistics(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        // Deliberately unfiltered by status: the chips need every count, and
        // filtering the counts by the chip that is selected would leave the
        // other five reading zero.
        search: _search,
      ),
    ]);

    if (!mounted || generation != _generation) return;

    final page = results[0] as ApiResponse<CreditLimitPage>;
    final stats = results[1] as ApiResponse<CreditLimitStatistics>;

    setState(() {
      _loading = false;
      if (page.isSuccess && page.data != null) {
        _page = page.data;
        _rows
          ..clear()
          ..addAll(page.data!.rows);
        if (stats.isSuccess && stats.data != null) _stats = stats.data!;
      } else {
        _error = FriendlyError.of(page.message);
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_rows.length >= (_page?.total ?? 0)) return;

    final generation = _generation;
    setState(() => _loadingMore = true);

    final response = await _api.getCreditLimitRequests(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter?.wire,
      search: _search,
      limit: _pageSize,
      offset: _rows.length,
    );

    if (!mounted || generation != _generation) return;

    setState(() {
      _loadingMore = false;
      if (response.isSuccess && response.data != null) {
        _rows.addAll(response.data!.rows);
        _page = response.data;
      }
    });
  }

  Future<void> _loadUnused() async {
    setState(() {
      _loadingUnused = true;
      _unusedError = null;
    });

    final response = await _api.getUnusedCreditAllowances();
    if (!mounted) return;

    setState(() {
      _loadingUnused = false;
      if (response.isSuccess && response.data != null) {
        _unused = response.data;
      } else {
        _unusedError = FriendlyError.of(response.message);
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      _load();
    });
  }

  void _selectStatus(CreditLimitOutcome? outcome) {
    setState(() => _statusFilter = outcome);
    _load();
  }

  Future<void> _pickRange() async {
    if (!_canFilterDate) return;

    final picked = await showListDateRangePicker(context, initial: _range);
    if (picked == null || !mounted) return;

    setState(() => _range = picked);
    _load();
  }

  /// Back to the default. Not "clear the filter" any more -- there is no
  /// unfiltered state to go back to; today is the floor.
  void _resetRangeToToday() {
    setState(() => _range = null);
    _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateCreditLimitRequestScreen()),
    );
    if (created == true && mounted) {
      _load();
      _loadUnused();
    }
  }

  void _openHistory(int customerId, String? customerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerCreditHistoryScreen(
          customerId: customerId,
          customerName: customerName,
        ),
      ),
    );
  }

  /// Reach any customer's history, not only one that happens to have a record
  /// in the range on screen. Without the date-filter grant that range is
  /// today, so most customers would otherwise be unreachable from here.
  ///
  /// It is fed by the screen's own search box. The scoped customer list is
  /// capped at 200 rows server-side, which is every customer on a seller's
  /// route but a fraction of the 3,824 an administrator covers -- so the
  /// picker narrows by whatever has been typed above rather than offering a
  /// silently truncated list and filtering it locally.
  Future<void> _chooseCustomerForHistory() async {
    final response = await _api.getCreditLimitCustomers(search: _search);
    if (!mounted) return;

    if (!response.isSuccess || response.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FriendlyError.of(response.message)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final chosen = await SearchablePicker.show<CreditScopedCustomer>(
      context,
      title: 'Customer History',
      items: response.data!,
      labelOf: (c) => c.customerName,
      subtitleOf: (c) => c.phoneNumber,
      trailingOf: (c) => c.hasOneTimeCredit && c.oneTimeCreditLimit > 0
          ? '${_money.format(c.oneTimeCreditLimit)} held'
          : null,
      searchHint: 'Search by name or phone number...',
      emptyMessage: _search.isEmpty
          ? 'No customers in your stock locations'
          : 'No customer matches "$_search"',
    );

    if (chosen != null && mounted) {
      _openHistory(chosen.customerId, chosen.customerName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Credit Limit & Approvals'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Customer history',
            onPressed: _chooseCustomerForHistory,
          ),
          // The calendar and clear-range icons that used to sit here opened
          // the same picker this screen still uses, but they said nothing
          // about the range in force and appeared only for grant holders --
          // so nobody else could tell why they were seeing what they saw.
          // Both are now the DateRangeFilterBar over the Requests tab, which
          // is always visible and always states the range.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _load();
              _loadUnused();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Requests'),
            Tab(
              text: _unused == null
                  ? 'Unused'
                  : 'Unused (${_unused!.customers.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildRequests(isDark),
          _buildUnused(isDark),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New request'),
            )
          : null,
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  // ---- requests tab ------------------------------------------------------

  Widget _buildRequests(bool isDark) {
    if (_loading) {
      return Column(
        children: [
          _dateBar(),
          _searchField(isDark),
          Expanded(child: SkeletonRowList(isDark: isDark)),
        ],
      );
    }

    if (_error != null && _rows.isEmpty) {
      return Column(
        children: [
          _dateBar(),
          Expanded(
            child: ErrorStateView(
              message: _error!,
              onRetry: FriendlyError.isPermanent(_error) ? null : _load,
              isDark: isDark,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _dateBar(),
        _searchField(isDark),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
              // header + chips + notice + rows + footer
              itemCount: _rows.length + 4,
              separatorBuilder: (_, index) =>
                  SizedBox(height: index < 3 ? 0 : 8),
              itemBuilder: (context, index) {
                if (index == 0) return _headline(isDark);
                if (index == 1) return _statusChips(isDark);
                if (index == 2) return _notices(isDark);
                if (index == _rows.length + 3) return _footer(isDark);

                final row = _rows[index - 3];
                return _CreditLimitCard(
                  row: row,
                  index: index - 2,
                  money: _money,
                  isDark: isDark,
                  onTap: () => _openHistory(row.customerId, row.customerName),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Only over the Requests tab. The unused-allowance list is a snapshot of
  /// who is holding an allowance right now, not a list of dated records, so a
  /// date range over it would mean nothing.
  Widget _dateBar() {
    return DateRangeFilterBar(
      dateFrom: _page?.dateFrom ?? _dateFrom ?? DateRangeFilterBar.today(),
      dateTo: _page?.dateTo ?? _dateTo ?? DateRangeFilterBar.today(),
      canFilterDate: _canFilterDate,
      onChange: _pickRange,
      onResetToToday: _resetRangeToToday,
    );
  }

  Widget _searchField(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Document number, customer, reason or notes...',
          helperText: 'Also narrows the customer history picker above',
          helperStyle: const TextStyle(fontSize: 10.5),
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                    _load();
                  },
                ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  /// The headline the four web stat cards add up to: what the filtered set is
  /// worth, over how many records, for which days.
  Widget _headline(bool isDark) {
    final page = _page;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
            'TOTAL CREDIT REQUESTED',
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
              '${_money.format(_stats.totalAmount)} TSh',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_plural(_stats.total, 'record')} · ${_rangeLabel()}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _headlineFigure(
                    'Granted', '${_money.format(_stats.approvedAmount)} TSh'),
              ),
              Expanded(
                child: _headlineFigure(
                    'Waiting', _plural(_stats.awaiting, 'request')),
              ),
            ],
          ),
          if (page != null && page.locations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.store_outlined,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      page.locations.length > 3
                          ? '${page.locations.take(3).join(', ')} '
                              'and ${page.locations.length - 3} more'
                          : page.locations.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
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

  Widget _headlineFigure(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// The days this headline covers, in the same words the filter bar uses.
  ///
  /// It used to be able to say "all time", because an omitted range meant
  /// every record ever raised. It cannot any more: the server always applies
  /// a range, so this always names one, and the figure above it can no longer
  /// be mistaken for a company-wide total.
  String _rangeLabel() => DateRangeFilterBar.describe(
        _page?.dateFrom ?? _dateFrom ?? DateRangeFilterBar.today(),
        _page?.dateTo ?? _dateTo ?? DateRangeFilterBar.today(),
      ).toLowerCase();

  String _plural(int count, String singular) =>
      '${_money.format(count)} $singular${count == 1 ? '' : 's'}';

  /// The four web stat cards, as filters. Reading a count and then having to
  /// find the matching filter elsewhere is two steps where one will do.
  Widget _statusChips(bool isDark) {
    const outcomes = [
      CreditLimitOutcome.awaiting,
      CreditLimitOutcome.approved,
      CreditLimitOutcome.rejected,
      CreditLimitOutcome.returned,
      CreditLimitOutcome.unreviewed,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('All', _stats.total, _statusFilter == null, isDark,
                () => _selectStatus(null), AppColors.primary),
            for (final outcome in outcomes) ...[
              const SizedBox(width: 8),
              _chip(
                _chipLabel(outcome),
                _stats.countFor(outcome),
                _statusFilter == outcome,
                isDark,
                () => _selectStatus(_statusFilter == outcome ? null : outcome),
                outcomeColour(outcome),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _chipLabel(CreditLimitOutcome outcome) {
    switch (outcome) {
      case CreditLimitOutcome.awaiting:
        return 'Waiting';
      case CreditLimitOutcome.approved:
        return 'Granted';
      case CreditLimitOutcome.rejected:
        return 'Rejected';
      case CreditLimitOutcome.returned:
        return 'Returned';
      case CreditLimitOutcome.cancelled:
        return 'Cancelled';
      case CreditLimitOutcome.unreviewed:
        return 'Never reviewed';
    }
  }

  Widget _chip(String label, int count, bool selected, bool isDark,
      VoidCallback onTap, Color accent) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.16)
          : (isDark ? AppColors.darkCard : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.6)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? accent
                      : (isDark ? AppColors.darkText : AppColors.text),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _money.format(count),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? accent
                      : (isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The two things the client has to know before reading a single row.
  Widget _notices(bool isDark) {
    final notices = <Widget>[];

    // The "you can only see today" line that used to open this stack is now
    // in the filter bar directly above, where it is permanent rather than
    // scrolling away with the list. Repeating it here said the same thing
    // twice on the same screen.

    if (_stats.staleStatusRows > 0) {
      notices.add(_notice(
        isDark,
        Icons.build_circle_outlined,
        AppColors.warning,
        '${_money.format(_stats.staleStatusRows)} of these records are still '
        'stored as "pending" although they were approved or rejected long ago. '
        'A database fault stopped the status being written back until 21 '
        'August 2026. The badges below show what actually happened.',
      ));
    }

    if (_stats.unreviewed > 0) {
      notices.add(_notice(
        isDark,
        Icons.history_toggle_off,
        AppColors.textLight,
        '${_money.format(_stats.unreviewed)} records were raised before the '
        'approval workflow existed and were never reviewed by anyone.',
      ));
    }

    if (notices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(children: notices),
    );
  }

  Widget _notice(bool isDark, IconData icon, Color colour, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
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

  Widget _footer(bool isDark) {
    if (_rows.isEmpty) {
      // The range is named, not alluded to. This list defaults to today, so
      // most people opening this screen land here where they used to see
      // 1,892 rows, and the reason has to be on the screen rather than
      // inferred.
      final narrowed = _search.isNotEmpty || _statusFilter != null;

      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyStateView(
          icon: Icons.event_busy_outlined,
          title: 'Nothing for ${_rangeLabel()}',
          message: _canFilterDate
              ? (narrowed
                  ? 'Nothing matches this search in ${_rangeLabel()}. '
                      'Try a wider date range.'
                  : 'Nothing was raised for your stock locations in '
                      '${_rangeLabel()}.')
              : (narrowed
                  ? 'Nothing matches this search today. This view is limited '
                      'to today.'
                  : 'Nothing was raised for your stock locations today. This '
                      'view is limited to today — ask for the date filter '
                      'permission to look at other days.'),
          isDark: isDark,
          action: !_canFilterDate
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('Change date range'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_range != null)
                      TextButton(
                        onPressed: _resetRangeToToday,
                        child: const Text('Back to today'),
                      ),
                  ],
                ),
        ),
      );
    }

    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_rows.length >= (_page?.total ?? 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'All ${_plural(_page?.total ?? 0, 'record')} shown',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }

  // ---- unused allowance tab ---------------------------------------------

  Widget _buildUnused(bool isDark) {
    if (_loadingUnused) return SkeletonRowList(isDark: isDark);

    if (_unusedError != null) {
      return ErrorStateView(
        message: _unusedError!,
        onRetry:
            FriendlyError.isPermanent(_unusedError) ? null : _loadUnused,
        isDark: isDark,
      );
    }

    final unused = _unused;
    if (unused == null || unused.customers.isEmpty) {
      return EmptyStateView(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No unspent allowances',
        message: 'Nobody in your stock locations is holding a one-time '
            'allowance they have not used.',
        isDark: isDark,
        onRefresh: _loadUnused,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUnused,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        itemCount: unused.customers.length + 1,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 0 : 8),
        itemBuilder: (context, index) {
          if (index == 0) return _unusedHeadline(unused, isDark);
          final customer = unused.customers[index - 1];
          return _UnusedCard(
            customer: customer,
            index: index,
            money: _money,
            isDark: isDark,
            onTap: () =>
                _openHistory(customer.customerId, customer.customerName),
          );
        },
      ),
    );
  }

  Widget _unusedHeadline(UnusedAllowanceList unused, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
            'UNSPENT ALLOWANCE',
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
              '${_money.format(unused.totalAmount)} TSh',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_plural(unused.customers.length, 'customer')} still holding '
            'credit granted to them',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// The colour a given outcome reads in.
Color outcomeColour(CreditLimitOutcome outcome) {
  switch (outcome) {
    case CreditLimitOutcome.approved:
      return AppColors.success;
    case CreditLimitOutcome.awaiting:
      return AppColors.warning;
    case CreditLimitOutcome.rejected:
      return AppColors.error;
    case CreditLimitOutcome.returned:
      return AppColors.info;
    case CreditLimitOutcome.cancelled:
      return Colors.grey;
    case CreditLimitOutcome.unreviewed:
      return Colors.blueGrey;
  }
}

/// The badge that says what became of a record.
class OutcomeBadge extends StatelessWidget {
  const OutcomeBadge({super.key, required this.outcome, this.stale = false});

  final CreditLimitOutcome outcome;

  /// Draws the badge with a mark when the stored status disagrees with it.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final colour = outcomeColour(outcome);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            outcome.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: colour,
            ),
          ),
          if (stale) ...[
            const SizedBox(width: 3),
            Icon(Icons.error_outline, size: 10, color: colour),
          ],
        ],
      ),
    );
  }
}

/// One record in the list.
class _CreditLimitCard extends StatelessWidget {
  const _CreditLimitCard({
    required this.row,
    required this.index,
    required this.money,
    required this.isDark,
    required this.onTap,
  });

  final CreditLimitRow row;
  final int index;
  final NumberFormat money;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final accent = outcomeColour(row.outcome);

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.customerName ?? 'Unknown customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          row.documentNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      OutcomeBadge(
                          outcome: row.outcome, stale: row.statusIsStale),
                      const SizedBox(height: 5),
                      Text(
                        money.format(row.creditAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (row.reason != null && row.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  row.reason!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: muted, height: 1.3),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _meta(Icons.account_balance_wallet_outlined,
                      '${money.format(row.currentBalance)} owed', muted),
                  const SizedBox(width: 12),
                  Flexible(
                    child: _meta(Icons.event_outlined,
                        _date(row.effectiveDate), muted),
                  ),
                  const Spacer(),
                  Text(
                    _dateTime(row.createdAt),
                    style: TextStyle(fontSize: 10.5, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color muted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: muted),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ),
      ],
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
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd MMM, HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

/// One customer holding an allowance they have not spent.
class _UnusedCard extends StatelessWidget {
  const _UnusedCard({
    required this.customer,
    required this.index,
    required this.money,
    required this.isDark,
    required this.onTap,
  });

  final UnusedAllowance customer;
  final int index;
  final NumberFormat money;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        customer.phoneNumber ?? '-',
                        if (customer.lastDocumentNumber != null)
                          customer.lastDocumentNumber!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money.format(customer.oneTimeLimit),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                  Text('held', style: TextStyle(fontSize: 10, color: muted)),
                ],
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: isDark ? AppColors.darkTextLight : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
