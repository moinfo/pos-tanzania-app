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

  bool _loadingInbox = true;
  bool _loadingMine = true;
  String? _inboxError;
  String? _mineError;

  bool get _canApprove =>
      context.read<PermissionProvider>().hasPermission(PermissionIds.approvalsView);

  @override
  void initState() {
    super.initState();
    // A seller with no approvals permission only ever has one tab worth
    // showing, so start them on their own requests.
    // One tab for someone who cannot approve. A locked "Zinazonisubiri" they
    // can swipe to every time adds nothing but a dead end.
    _tabCount = _canApprove ? 2 : 1;
    _tabs = TabController(length: _tabCount, vsync: this);
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

    final response = await _api.getPendingApprovals();
    if (!mounted) return;

    setState(() {
      _loadingInbox = false;
      if (response.isSuccess && response.data != null) {
        _inbox = response.data!;
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

    final response = await _api.getMySubmittedRequests();
    if (!mounted) return;

    setState(() {
      _loadingMine = false;
      if (response.isSuccess && response.data != null) {
        _mine = response.data!;
      } else {
        _mineError = FriendlyError.of(response.message);
      }
    });
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
        title: const Text('Requests & Approvals'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
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
      body: TabBarView(
        controller: _tabs,
        // _tabCount, not a fresh _canApprove read. Logout clears permissions
        // and notifies before the auth change swaps in the login screen, so a
        // live read here would rebuild one child against a two-tab controller
        // and assert.
        children: [
          if (_tabCount > 1) _buildInbox(isDark),
          _buildMine(isDark),
        ],
      ),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
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
        label: const Text('Request Credit'),
      );
    }

    return FloatingActionButton(
      onPressed: _chooseRequestType,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
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
                'What are you requesting?',
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
              title: const Text('A price discount'),
              subtitle: const Text('One item, one customer, one day'),
              onTap: () {
                Navigator.pop(context);
                _openCreate(discount: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined, color: AppColors.info),
              title: const Text('Extra credit'),
              subtitle: const Text('A one-time allowance for a customer'),
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

  Widget _buildInbox(bool isDark) {
    if (_loadingInbox) return SkeletonRowList(isDark: isDark);

    if (_inboxError != null) {
      return ErrorStateView(message: _inboxError!, onRetry: FriendlyError.isPermanent(_inboxError) ? null : _loadInbox, isDark: isDark);
    }

    if (_inbox.isEmpty) {
      return EmptyStateView(
        icon: Icons.task_alt,
        title: 'Nothing waiting',
        message: 'Every request in your stock locations has been dealt with.',
        isDark: isDark,
        onRefresh: _loadInbox,
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
            onTap: () => _openDetail(approval.approvalId),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMine(bool isDark) {
    if (_loadingMine) return SkeletonRowList(isDark: isDark);

    if (_mineError != null) {
      return ErrorStateView(message: _mineError!, onRetry: FriendlyError.isPermanent(_mineError) ? null : _loadMine, isDark: isDark);
    }

    if (_mine.isEmpty) {
      return EmptyStateView(
        icon: Icons.outbox_outlined,
        title: 'You have not raised a request yet',
        message: 'Discount and credit limit requests will appear here.',
        isDark: isDark,
        onRefresh: _loadMine,
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
  });

  final Approval approval;
  final int index;
  final NumberFormat money;
  final bool isDark;
  final VoidCallback onTap;

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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Serial number, the same circled style the suspended,
                  // items and customers lists use.
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
