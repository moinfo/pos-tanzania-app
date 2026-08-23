import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/approval.dart';
import '../models/permission_model.dart';
import '../providers/notification_provider.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/date_range_filter_bar.dart';
import '../widgets/state_views.dart';
import 'create_credit_limit_request_screen.dart';
import 'create_discount_request_screen.dart';

/// Requests and approvals in one place.
///
/// Two tabs, because the same person is usually on both sides of this: a sales
/// manager raises discount requests for their own customers and reviews their
/// sellers'. Splitting them into separate menu entries would mean hunting
/// through the drawer twice a day.
///
/// Everything shown here is already scoped server-side to the customers under
/// this employee's stock locations. The app does no filtering of its own, and
/// acting on something out of scope returns 403 rather than quietly working.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, this.initialApprovalId});

  /// Open straight into one approval, used when a notification is tapped.
  final int? initialApprovalId;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _money = NumberFormat('#,##0', 'en_US');

  late final TabController _tabs;
  late final int _tabCount;

  List<Approval> _inbox = [];
  List<Approval> _mine = [];

  /// The last response from each tab, kept for the range it applied and for
  /// the count it is holding back. Both tabs share one range, so whichever
  /// answered last is as good as the other for the bar.
  ApprovalPage? _inboxPage;
  ApprovalPage? _minePage;

  bool _loadingInbox = true;
  bool _loadingMine = true;
  String? _inboxError;
  String? _mineError;

  /// Batch mode, and what is ticked. Only the inbox tab has it -- "My
  /// Requests" is a list of things I asked for, not things I decide.
  bool _selecting = false;
  final Set<int> _selected = <int>{};
  bool _bulkBusy = false;

  /// The server refuses more than this in one call. Enforced here too so the
  /// user finds out while ticking rather than after pressing Approve.
  static const int _bulkMax = 50;

  /// null means "the default", which the server reads as today. Both tabs are
  /// filtered together: this screen is one question ("what is happening with
  /// requests on these days"), asked from two sides.
  DateTimeRange? _range;

  bool get _canApprove =>
      context.read<PermissionProvider>().hasPermission(PermissionIds.approvalsView);

  /// Batch mode is a separate grant from approving one request, and the server
  /// checks it independently. Only two people hold it today, so most users
  /// must never see any of this -- not a disabled control, nothing at all.
  bool get _canBulkApprove =>
      context.read<PermissionProvider>().hasPermission(PermissionIds.bulkApprove);

  bool get _canBulkReject =>
      context.read<PermissionProvider>().hasPermission(PermissionIds.bulkReject);

  bool get _canBulk => _canBulkApprove || _canBulkReject;

  String? get _dateFrom => _range == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_range!.start);

  String? get _dateTo =>
      _range == null ? null : DateFormat('yyyy-MM-dd').format(_range!.end);

  /// The page the filter bar describes. Prefer whichever tab has answered.
  ApprovalPage? get _datePage => _inboxPage ?? _minePage;

  /// The server settles this and repeats it on every response. The permission
  /// read is only so the bar is right on the first frame, before anything has
  /// come back. Either grant unlocks the picker; which kinds of request it
  /// actually widens is per model, and the bar says so when they differ.
  bool get _canFilterDate {
    final page = _datePage;
    if (page != null) return page.canFilterDate;

    final permissions = context.read<PermissionProvider>();
    return permissions.hasPermission(PermissionIds.customerCreditLimitsFilterDate) ||
        permissions.hasPermission(PermissionIds.oneTimeDiscountsDate);
  }

  /// When one kind of request was widened and the other was left on today,
  /// say which and why. Silence here would look like rows going missing.
  String? get _dateNote {
    final page = _datePage;
    if (page == null || page.dateScopeUniform || !page.canFilterDate) {
      return null;
    }

    final pinned = page.pinnedToToday;
    if (pinned.isEmpty) return null;

    final names = pinned.map((s) => s.label.toLowerCase()).join(' and ');
    return 'Showing today only for $names — that needs a separate permission.';
  }

  @override
  void initState() {
    super.initState();
    // A seller with no approvals permission only ever has one tab worth
    // showing, so start them on their own requests.
    // One tab for someone who cannot approve. A locked "Zinazonisubiri" they
    // can swipe to every time adds nothing but a dead end.
    _tabCount = _canApprove ? 2 : 1;
    _tabs = TabController(length: _tabCount, vsync: this);
    // One exception to the no-listener rule below: batch mode belongs to the
    // inbox, and swiping to "My Requests" with the bar still up would offer
    // to approve rows that are not approvals. Only fires on a settled index
    // change, and only does anything when something is actually selected.
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _tabs.index != 0 && _selecting) {
        _exitSelection();
      }
    });
    // No listener on purpose: nothing in build() reads _tabs.index, and a
    // TabController notifies on every frame of a swipe, so a setState here
    // would rebuild both lists for the length of every gesture. The tab counts
    // come from _inbox/_mine, which already setState when they load.

    _loadInbox();
    _loadMine();

    final id = widget.initialApprovalId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(id));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadInbox() async {
    if (!_canApprove) {
      setState(() {
        _loadingInbox = false;
        _inbox = [];
      });
      return;
    }

    setState(() {
      _loadingInbox = true;
      _inboxError = null;
    });

    final response = await _api.getPendingApprovals(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;

    setState(() {
      _loadingInbox = false;
      if (response.isSuccess && response.data != null) {
        _inboxPage = response.data;
        _inbox = response.data!.approvals;
      } else {
        _inboxError = FriendlyError.of(response.message);
      }
    });
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingMine = true;
      _mineError = null;
    });

    final response = await _api.getMySubmittedRequests(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;

    setState(() {
      _loadingMine = false;
      if (response.isSuccess && response.data != null) {
        _minePage = response.data;
        _mine = response.data!.approvals;
      } else {
        _mineError = FriendlyError.of(response.message);
      }
    });
  }

  /// Both tabs reload together: they share the range, and a bar that says
  /// "3 Aug – 20 Aug" over a tab still holding today's rows would be lying
  /// about one of them.
  Future<void> _pickRange() async {
    if (!_canFilterDate) return;

    final picked = await showListDateRangePicker(context, initial: _range);
    if (picked == null || !mounted) return;

    setState(() => _range = picked);
    _loadInbox();
    _loadMine();
  }

  void _resetRangeToToday() {
    setState(() => _range = null);
    _loadInbox();
    _loadMine();
  }

  /// "1 request" / "3 requests" — the counts in the queue header read as a
  /// sentence, so they have to agree in number.
  String _plural(int count, String singular) =>
      '$count $singular${count == 1 ? '' : 's'}';

  double get _inboxValue =>
      _inbox.fold(0.0, (sum, a) => sum + (a.detail?.headlineAmount ?? 0));

  int get _mineOpen => _mine.where((a) => a.isOpen).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Discount & Approvals'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Long press on a card starts batch mode too, but a gesture nobody
          // is told about is not a feature. This is the discoverable way in,
          // and it is absent entirely for the people without the grant.
          if (_canBulk && _tabCount > 1 && !_selecting && _inbox.isNotEmpty)
            IconButton(
              tooltip: 'Select several',
              icon: const Icon(Icons.checklist_rtl),
              onPressed: () => setState(() {
                _selecting = true;
                _selected.clear();
              }),
            ),
        ],
        bottom: _tabCount == 1
            ? null
            : TabBar(
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
                  Tab(
                      child: _tabLabel(
                          'Waiting on Me', _inbox.length, AppColors.error)),
                  Tab(child: _tabLabel('My Requests', _mineOpen, AppColors.warning)),
                ],
              ),
      ),
      body: Column(
        children: [
          // Above the tabs, not inside them: one range governs both, and two
          // bars saying the same thing would invite the reader to believe
          // they could differ.
          DateRangeFilterBar(
            dateFrom: _datePage?.dateFrom ?? _dateFrom ?? DateRangeFilterBar.today(),
            dateTo: _datePage?.dateTo ?? _dateTo ?? DateRangeFilterBar.today(),
            canFilterDate: _canFilterDate,
            onChange: _pickRange,
            onResetToToday: _resetRangeToToday,
            note: _dateNote,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              // _tabCount, not a fresh _canApprove read. Logout clears
              // permissions and notifies before the auth change swaps in the
              // login screen, so a live read here would rebuild one child
              // against a two-tab controller and assert.
              children: [
                if (_tabCount > 1) _buildInbox(isDark),
                _buildMine(isDark),
              ],
            ),
          ),
          if (_selecting) _buildSelectionBar(isDark),
        ],
      ),
      // The batch bar sits where the FAB does. Showing both would put "New
      // request" on top of "Approve 12", which is not a mistake worth making
      // available.
      floatingActionButton: _selecting ? null : _buildFab(),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  /// What is ticked, and what can be done with it.
  ///
  /// Sits above the bottom navigation rather than floating over the list, so
  /// it never covers the row the user is deciding about.
  Widget _buildSelectionBar(bool isDark) {
    final count = _selected.length;
    final overCap = count > _bulkMax;
    final allVisibleSelected =
        _inbox.isNotEmpty && count >= _inbox.take(_bulkMax).length;

    return Material(
      elevation: 8,
      color: AppColors.surface(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: _bulkBusy ? null : _exitSelection,
                    icon: const Icon(Icons.close),
                    color: AppColors.muted(context),
                  ),
                  Expanded(
                    child: Text(
                      '$count selected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ),
                  if (_inbox.isNotEmpty)
                    TextButton(
                      onPressed: _bulkBusy
                          ? null
                          : (allVisibleSelected
                              ? () => setState(_selected.clear)
                              : _selectAllVisible),
                      child: Text(allVisibleSelected ? 'Clear' : 'Select all'),
                    ),
                ],
              ),
              if (overCap)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 15, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Only $_bulkMax can go at once. Untick ${count - _bulkMax}.',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  if (_canBulkReject)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_bulkBusy || overCap) ? null : () => _runBulk(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                      ),
                    ),
                  if (_canBulkReject && _canBulkApprove) const SizedBox(width: 10),
                  if (_canBulkApprove)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_bulkBusy || overCap) ? null : () => _runBulk(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: _bulkBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_bulkBusy ? 'Working...' : 'Approve'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabLabel(String text, int count, Color colour) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Raising a request is the other half of this screen's job, so it gets the
  /// FAB rather than a trip back through the drawer. Which one appears depends
  /// on the grants the user actually holds.
  Widget? _buildFab() {
    final permissions = context.watch<PermissionProvider>();
    final canDiscount = permissions.hasPermission(PermissionIds.oneTimeDiscountsAdd);
    final canCredit = permissions.hasPermission(PermissionIds.customerCreditLimitsAdd);

    if (!canDiscount && !canCredit) return null;

    if (canDiscount && !canCredit) {
      return FloatingActionButton.extended(
        onPressed: () => _openCreate(discount: true),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.local_offer_outlined),
        label: const Text('Request a Discount'),
      );
    }

    if (canCredit && !canDiscount) {
      return FloatingActionButton.extended(
        onPressed: () => _openCreate(discount: false),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.request_quote_outlined),
        label: const Text('Customer Credit Limit'),
      );
    }

    // Labelled, not a bare "+". Someone holding both grants was shown an
    // unlabelled plus that said nothing about what it created, so the credit
    // limit request looked as though it had never been built.
    return FloatingActionButton.extended(
      onPressed: _chooseRequestType,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('New request'),
    );
  }

  Future<void> _chooseRequestType() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'What do you want to request?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined, color: AppColors.warning),
              title: const Text('Discount on items'),
              subtitle: const Text('One customer, one day, any number of items'),
              onTap: () {
                Navigator.pop(context);
                _openCreate(discount: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined, color: AppColors.info),
              title: const Text('Customer credit limit'),
              subtitle: const Text('A one-time allowance for one customer'),
              onTap: () {
                Navigator.pop(context);
                _openCreate(discount: false);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreate({required bool discount}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => discount
            ? const CreateDiscountRequestScreen()
            : const CreateCreditLimitRequestScreen(),
      ),
    );

    if (created == true && mounted) {
      if (_tabCount > 1) _tabs.animateTo(1);
      _loadMine();
    }
  }

  /* ---------------- batch mode ---------------- */

  void _enterSelection(int approvalId) {
    if (!_canBulk) return;
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(approvalId);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelect(int approvalId) {
    setState(() {
      if (!_selected.remove(approvalId)) {
        _selected.add(approvalId);
      }
      // Unticking the last one leaves the bar sitting there with nothing to
      // act on, which reads as broken. Drop straight back to the normal list.
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selected
        ..clear()
        ..addAll(_inbox.take(_bulkMax).map((a) => a.approvalId));
    });
  }

  /// Ask for a rejection reason. Required, and required by the server too --
  /// a rejection with no reason leaves the requester with nothing to fix.
  Future<String?> _askRejectReason(int count) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Reject this request' : 'Reject $count requests'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1
                  ? 'The requester will see this reason.'
                  : 'Every one of the $count requesters will see this same reason.',
              style: TextStyle(fontSize: 13, color: AppColors.muted(dialogContext)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Why are these being rejected?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _runBulk(bool approve) async {
    final ids = _selected.toList();
    if (ids.isEmpty || _bulkBusy) return;

    String comment = '';
    if (!approve) {
      final reason = await _askRejectReason(ids.length);
      if (reason == null) return;
      comment = reason;
    }

    setState(() => _bulkBusy = true);

    final response = await _api.bulkActOnApprovals(
      approvalIds: ids,
      approve: approve,
      comment: comment,
      requestId: const Uuid().v4(),
    );

    if (!mounted) return;
    setState(() => _bulkBusy = false);

    if (!response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FriendlyError.of(response.message)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final data = response.data ?? const <String, dynamic>{};
    final succeeded = (data['succeeded'] as num?)?.toInt() ?? 0;
    final skipped = (data['skipped'] as num?)?.toInt() ?? 0;
    final results = (data['results'] as List?) ?? const [];

    _exitSelection();
    await _loadInbox();
    if (!mounted) return;

    // Refresh the badge: the count the drawer shows is now wrong by however
    // many went through.
    context.read<NotificationProvider>().refreshCounts();

    if (skipped == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: approve ? AppColors.success : AppColors.warning,
        ),
      );
      return;
    }

    // Some were skipped. A snackbar would scroll away before it is read, and
    // the reasons are the whole point -- most of them mean "somebody else got
    // there first", which the user needs to see to trust the list.
    await _showBulkOutcome(
      approve: approve,
      succeeded: succeeded,
      results: results.whereType<Map>().where((r) => r['ok'] != true).toList(),
    );
  }

  Future<void> _showBulkOutcome({
    required bool approve,
    required int succeeded,
    required List<Map> results,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          succeeded == 0
              ? 'Nothing went through'
              : '$succeeded ${approve ? 'approved' : 'rejected'}, ${results.length} skipped',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These were left alone:',
                style: TextStyle(fontSize: 13, color: AppColors.muted(dialogContext)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final row = results[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.remove_circle_outline,
                            size: 16, color: AppColors.muted(dialogContext)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '#${row['approval_id']} - ${row['reason'] ?? 'Skipped'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInbox(bool isDark) {
    if (_loadingInbox) return SkeletonRowList(isDark: isDark);

    if (_inboxError != null) {
      return ErrorStateView(message: _inboxError!, onRetry: FriendlyError.isPermanent(_inboxError) ? null : _loadInbox, isDark: isDark);
    }

    if (_inbox.isEmpty) {
      return _emptyForRange(
        isDark: isDark,
        page: _inboxPage,
        onRefresh: _loadInbox,
        emptyIcon: Icons.task_alt,
        emptyTitle: 'Nothing waiting',
        emptyMessage:
            'Every request in your stock locations has been dealt with.',
        filteredMessage: 'Nothing was submitted to you in this date range.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        itemCount: _inbox.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) return _buildQueueHeader(isDark);
          final approval = _inbox[index - 1];
          return _ApprovalCard(
            approval: approval,
            index: index,
            money: _money,
            isDark: isDark,
            selecting: _selecting,
            selected: _selected.contains(approval.approvalId),
            // A tap means "open this" normally and "tick this" in batch mode.
            // Long press is what starts batch mode, the same gesture a photo
            // gallery uses, so nothing has to be discovered from a toolbar.
            onTap: _selecting
                ? () => _toggleSelect(approval.approvalId)
                : () => _openDetail(approval.approvalId),
            onLongPress: _canBulk && !_selecting
                ? () => _enterSelection(approval.approvalId)
                : null,
          );
        },
      ),
    );
  }

  /// What is waiting on me, and what it is worth. The value matters: a queue
  /// of twenty small discounts is a different afternoon from one large one.
  Widget _buildQueueHeader(bool isDark) {
    final discounts = _inbox.where((a) => a.kind == ApprovalKind.discount).length;
    final credits = _inbox.length - discounts;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
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
              'WAITING ON YOU',
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
                '${_money.format(_inboxValue)} TSh',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              // Break the total down only when there is actually a mix;
              // "27 requests · 27 discounts" says the same thing twice.
              (discounts > 0 && credits > 0)
                  ? [
                      _plural(discounts, 'discount'),
                      _plural(credits, 'credit request'),
                    ].join(' · ')
                  : _plural(
                      _inbox.length, credits > 0 ? 'credit request' : 'discount'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            // The figure above is now a filtered figure. Saying which days it
            // covers, and how many it leaves out, is the difference between a
            // total and a total that quietly means something narrower.
            const SizedBox(height: 4),
            Text(
              _rangeCaption(_inboxPage),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _rangeCaption(ApprovalPage? page) {
    final label = DateRangeFilterBar.describe(
      page?.dateFrom ?? _dateFrom,
      page?.dateTo ?? _dateTo,
    );

    final hidden = page?.hiddenByDate ?? 0;
    if (hidden == 0) return label;

    return '$label · $hidden more on other days';
  }

  Widget _buildMine(bool isDark) {
    if (_loadingMine) return SkeletonRowList(isDark: isDark);

    if (_mineError != null) {
      return ErrorStateView(message: _mineError!, onRetry: FriendlyError.isPermanent(_mineError) ? null : _loadMine, isDark: isDark);
    }

    if (_mine.isEmpty) {
      return _emptyForRange(
        isDark: isDark,
        page: _minePage,
        onRefresh: _loadMine,
        emptyIcon: Icons.outbox_outlined,
        emptyTitle: 'You have not raised a request yet',
        emptyMessage: 'Discount and credit limit requests will appear here.',
        filteredMessage: 'You raised nothing in this date range.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        itemCount: _mine.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _ApprovalCard(
          approval: _mine[index],
          index: index + 1,
          money: _money,
          isDark: isDark,
          onTap: () => _openDetail(_mine[index].approvalId),
        ),
      ),
    );
  }

  /// An empty list has two quite different causes now, and saying the wrong
  /// one is worse than saying nothing.
  ///
  /// There is genuinely nothing — or there is plenty, on days this range does
  /// not cover. The server reports both numbers, so this can tell them apart
  /// instead of guessing, and offer the way out to whoever is allowed to take
  /// it. For everyone else it states the limit rather than showing a button
  /// that would be refused.
  Widget _emptyForRange({
    required bool isDark,
    required ApprovalPage? page,
    required Future<void> Function() onRefresh,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
    required String filteredMessage,
  }) {
    final hidden = page?.hiddenByDate ?? 0;

    if (hidden == 0) {
      return EmptyStateView(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        isDark: isDark,
        onRefresh: onRefresh,
      );
    }

    final rangeLabel =
        DateRangeFilterBar.describe(page?.dateFrom, page?.dateTo).toLowerCase();
    final outside = hidden == 1
        ? '1 request sits outside it'
        : '$hidden requests sit outside it';

    return EmptyStateView(
      icon: Icons.event_busy_outlined,
      title: 'Nothing in this date range',
      message: _canFilterDate
          ? '$filteredMessage The range is $rangeLabel, and $outside.'
          : '$filteredMessage This view is limited to today, and $outside. '
              'Ask for the date filter permission to look at other days.',
      isDark: isDark,
      onRefresh: onRefresh,
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
    );
  }

  Future<void> _openDetail(int approvalId) async {
    final acted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApprovalDetailSheet(approvalId: approvalId, money: _money),
    );

    if (acted == true && mounted) {
      // Drop the badge straight away rather than waiting on the next poll.
      context.read<NotificationProvider>().decrementPendingApprovals();
      _loadInbox();
      _loadMine();
    }
  }
}

/// One request in a list.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.approval,
    required this.index,
    required this.money,
    required this.isDark,
    required this.onTap,
    this.selecting = false,
    this.selected = false,
    this.onLongPress,
  });

  final Approval approval;
  final int index;
  final NumberFormat money;
  final bool isDark;
  final VoidCallback onTap;
  final bool selecting;
  final bool selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final detail = approval.detail;
    final isDiscount = approval.kind == ApprovalKind.discount;
    final accent = isDiscount ? AppColors.warning : AppColors.info;

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // A ticked card reads as ticked from the border alone, so the
            // selection survives being skimmed rather than counted.
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Serial number, the same circled style the suspended,
                  // items and customers lists use. In batch mode the same
                  // circle becomes the tick: one control in one place, rather
                  // than a checkbox appearing beside a number that no longer
                  // means anything.
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selecting && selected
                          ? AppColors.primary
                          : accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selecting && selected
                            ? AppColors.primary
                            : accent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: selecting
                        ? Icon(
                            selected ? Icons.check : Icons.circle_outlined,
                            size: 16,
                            color: selected ? Colors.white : accent,
                          )
                        : Text(
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
                          detail?.customerName ?? 'Unknown customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              isDiscount ? Icons.local_offer : Icons.credit_card,
                              size: 12,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isDiscount
                                    ? (detail?.itemName ?? 'Discount')
                                    : 'Credit limit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: approval.status),
                      const SizedBox(height: 5),
                      Text(
                        money.format(detail?.headlineAmount ?? 0),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  if (isDiscount && detail?.quantity != null) ...[
                    _meta(Icons.inventory_2_outlined,
                        money.format(detail!.quantity!), isDark),
                    const SizedBox(width: 12),
                  ],
                  // The requester, not the location: a manager's queue is
                  // usually one location repeated down the page, truncated and
                  // identical on every row.
                  if (approval.submittedByName != null) ...[
                    Flexible(
                      child: _meta(Icons.person_outline,
                          approval.submittedByName!, isDark),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  Text(
                    Formatters.formatDate(approval.submittedAt,
                        format: 'dd MMM, HH:mm'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, bool isDark) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
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
}

/// Detail plus the approve/reject actions.
class _ApprovalDetailSheet extends StatefulWidget {
  const _ApprovalDetailSheet({required this.approvalId, required this.money});

  final int approvalId;
  final NumberFormat money;

  @override
  State<_ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends State<_ApprovalDetailSheet> {
  final _api = ApiService();
  final _comment = TextEditingController();

  ApprovalWithHistory? _data;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// One id per decision, held across retries so a timeout cannot approve the
  /// same request twice — but re-minted if the decision itself changes, or an
  /// approve that timed out would be replayed in place of the reject that
  /// followed it.
  String? _requestId;
  String? _requestKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final response = await _api.getApprovalDetail(widget.approvalId);
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

  Future<void> _act(bool approve) async {
    final comment = _comment.text.trim();

    // The server enforces this too, but catching it here saves a round trip
    // and leaves the reason field on screen instead of a red snackbar.
    if (!approve && comment.isEmpty) {
      setState(() => _error = 'Give a reason for rejecting');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final key = '${approve ? 'approve' : 'reject'}|$comment';
    if (_requestKey != key) {
      _requestKey = key;
      _requestId = const Uuid().v4();
    }

    final response = await _api.actOnApproval(
      approvalId: widget.approvalId,
      approve: approve,
      comment: comment,
      requestId: _requestId,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      // These flows have two steps. Saying "imeidhinishwa" after the first one
      // told a manager the request was finished when it had only moved on to
      // the administrator.
      final isFinal = response.data?['is_final'] != false;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            !approve
                ? 'Request rejected'
                : isFinal
                    ? 'Request approved'
                    : 'Approved by you - now waiting on final approval',
          ),
          backgroundColor: approve ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _submitting = false;
        _error = FriendlyError.of(response.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: _buildBody(scrollController, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ScrollController controller, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;
    if (data == null) {
      return ErrorStateView(
        message: _error ?? 'Could not load',
        onRetry: FriendlyError.isPermanent(_error) ? null : _load,
        isDark: isDark,
      );
    }

    final detail = data.approval.detail;
    final isDiscount = data.approval.kind == ApprovalKind.discount;
    final accent = isDiscount ? AppColors.warning : AppColors.info;
    final canAct = data.canApprove || data.canReject;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      isDiscount ? Icons.local_offer : Icons.credit_card,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDiscount ? 'Discount Request' : 'Credit Request',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        if (detail?.documentNumber != null)
                          Text(
                            detail!.documentNumber!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: data.approval.status),
                ],
              ),
              const Divider(height: 24),

              // The figure being decided, given its own weight.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDiscount ? 'TOTAL DISCOUNT' : 'AMOUNT REQUESTED',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${widget.money.format(detail?.headlineAmount ?? 0)} TSh',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ),
                    // The breakdown under the total, so the approver can see
                    // where it comes from without doing the multiplication.
                    if (isDiscount && detail?.quantity != null)
                      Text(
                        '${widget.money.format(detail!.quantity!)}'
                        ' x ${widget.money.format(detail.perUnitAmount ?? 0)} TSh',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Field(label: 'Customer', value: detail?.customerName ?? '-', isDark: isDark),
              if (isDiscount) ...[
                _Field(label: 'Item', value: detail?.itemName ?? '-', isDark: isDark),
                // The numbers the decision actually turns on. Without them an
                // approver reads "300 x 200" with no way to tell whether 200
                // off is generous or trivial -- it is 3.5% of an AFYA BERRY
                // and 0.5% of a bag of AZAM NGANO.
                if (detail?.unitPrice != null && detail!.unitPrice! > 0) ...[
                  _Field(
                    label: 'Selling price',
                    value: '${widget.money.format(detail.unitPrice)} TSh',
                    isDark: isDark,
                  ),
                  _Field(
                    label: 'Customer pays',
                    value: '${widget.money.format(detail.priceAfterDiscount)} TSh'
                        '  ·  ${detail.discountPercent!.toStringAsFixed(1)}% off',
                    isDark: isDark,
                  ),
                ],
                // Only when somebody set one. It is unset on all but twelve of
                // the 1,283 items, and a "Limit 0" on every other request would
                // train the approver to ignore the line that matters.
                if (detail?.effectiveDiscountLimit != null)
                  _Field(
                    label: 'Discount limit',
                    value: '${widget.money.format(detail!.effectiveDiscountLimit)} TSh per unit'
                        '${detail.exceedsDiscountLimit ? '  ·  EXCEEDED' : ''}',
                    isDark: isDark,
                  ),
                _Field(label: 'Location', value: detail?.locationName ?? '-', isDark: isDark),
                _Field(
                  label: 'Requested by',
                  value: data.approval.submittedByName ?? '-',
                  isDark: isDark,
                ),
                _Field(
                  label: 'Valid on',
                  value: Formatters.formatDate(detail?.validDate),
                  isDark: isDark,
                ),
              ] else ...[
                if (detail?.previousAmount != null)
                  _Field(
                    label: 'Previous limit',
                    value: '${widget.money.format(detail!.previousAmount!)} TSh',
                    isDark: isDark,
                  ),
                if (detail?.currentBalance != null)
                  _Field(
                    label: 'Owed now',
                    value: '${widget.money.format(detail!.currentBalance!)} TSh',
                    isDark: isDark,
                  ),
              ],
              if (detail?.reason != null)
                _Field(label: 'Reason', value: detail!.reason!, isDark: isDark),
              _Field(
                label: 'Submitted',
                value: Formatters.formatDate(data.approval.submittedAt,
                    format: 'dd MMM yyyy HH:mm'),
                isDark: isDark,
              ),

              const SizedBox(height: 20),
              Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 10),
              ...data.history.asMap().entries.map(
                    (entry) => _HistoryTile(
                      entry: entry.value,
                      isDark: isDark,
                      isLast: entry.key == data.history.length - 1,
                    ),
                  ),

              if (canAct) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _comment,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Comment',
                    helperText: 'Required if you reject',
                  ),
                ),
              ] else if (data.approval.isOpen) ...[
                // Open, but not on this person's step. Without a line saying
                // so, the reader just sees a full record with no buttons.
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This request is waiting on someone else right now.',
                          style: TextStyle(color: AppColors.info, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _ErrorBanner(message: _error!),
                ),
            ],
          ),
        ),
        if (canAct)
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              14 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
              ),
            ),
            child: Row(
              children: [
                if (data.canReject)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : () => _act(false),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                if (data.canReject && data.canApprove) const SizedBox(width: 12),
                if (data.canApprove)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : () => _act(true),
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.isDark});

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One step in the trail, drawn as a timeline so the order reads at a glance.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.isDark,
    required this.isLast,
  });

  final ApprovalHistoryEntry entry;
  final bool isDark;
  final bool isLast;

  (IconData, Color) get _look {
    switch (entry.action) {
      case 'approved':
        return (Icons.check_circle, AppColors.success);
      case 'rejected':
        return (Icons.cancel, AppColors.error);
      case 'returned':
        return (Icons.undo, AppColors.warning);
      case 'discarded':
        return (Icons.delete_outline, AppColors.textLight);
      default:
        return (Icons.send, AppColors.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = _look;
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 17, color: colour),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.actorName ?? 'User',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                  Text(
                    [
                      if (entry.roleName != null) entry.roleName!,
                      Formatters.formatDate(entry.createdAt,
                          format: 'dd MMM yyyy HH:mm'),
                    ].join(' · '),
                    style: TextStyle(fontSize: 10.5, color: muted),
                  ),
                  if (entry.comment != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.comment!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  (String, Color) get _look {
    switch (status) {
      // The engine's terminal success value is `completed`; it never writes
      // `approved`, despite that being in the column's enum.
      case 'completed':
        return ('APPROVED', AppColors.success);
      case 'rejected':
        return ('REJECTED', AppColors.error);
      case 'returned':
        return ('RETURNED', AppColors.warning);
      case 'discarded':
        return ('DISCARDED', AppColors.textLight);
      case 'in_progress':
        return ('IN PROGRESS', AppColors.info);
      default:
        return ('PENDING', AppColors.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, colour) = _look;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: colour,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
