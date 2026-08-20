import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/approval.dart';
import '../models/permission_model.dart';
import '../providers/notification_provider.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// Requests and approvals in one place.
///
/// Two tabs, because the same person is usually on both sides of this: a sales
/// manager raises discount requests for their own customers and reviews their
/// sellers' requests. Splitting them into separate menu entries would mean
/// hunting through the drawer twice a day.
///
/// Everything shown here is already scoped server-side to the customers under
/// this employee's stock locations — the app does no filtering of its own, and
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
  final _money = NumberFormat('#,##0');

  late final TabController _tabs;

  List<Approval> _inbox = [];
  List<Approval> _mine = [];

  bool _loadingInbox = true;
  bool _loadingMine = true;
  String? _inboxError;
  String? _mineError;

  bool get _canApprove {
    final permissions = context.read<PermissionProvider>();
    return permissions.hasPermission(PermissionIds.approvalsView);
  }

  @override
  void initState() {
    super.initState();
    // A seller with no approvals permission only ever has one tab worth
    // showing, so start them on their own requests.
    _tabs = TabController(length: 2, vsync: this, initialIndex: _canApprove ? 0 : 1);

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
        _inboxError = response.message;
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
        _mineError = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Maombi na Idhini'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Zinazonisubiri'),
                  if (_inbox.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountChip(count: _inbox.length),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Maombi Yangu'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildInbox(isDark),
          _buildMine(isDark),
        ],
      ),
    );
  }

  Widget _buildInbox(bool isDark) {
    if (!_canApprove) {
      return _EmptyState(
        icon: Icons.lock_outline,
        title: 'Huna ruhusa ya kuidhinisha',
        message: 'Maombi yako mwenyewe yapo kwenye tabu ya pili.',
        isDark: isDark,
      );
    }

    if (_loadingInbox) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inboxError != null) {
      return _ErrorState(message: _inboxError!, onRetry: _loadInbox, isDark: isDark);
    }

    if (_inbox.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInbox,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            _EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Hakuna linalosubiri',
              message: 'Maombi yote yaliyo ndani ya maeneo yako yameshughulikiwa.',
              isDark: isDark,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _inbox.length,
        itemBuilder: (context, index) => _ApprovalCard(
          approval: _inbox[index],
          index: index + 1,
          money: _money,
          isDark: isDark,
          showRequester: true,
          onTap: () => _openDetail(_inbox[index].approvalId),
        ),
      ),
    );
  }

  Widget _buildMine(bool isDark) {
    if (_loadingMine) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mineError != null) {
      return _ErrorState(message: _mineError!, onRetry: _loadMine, isDark: isDark);
    }

    if (_mine.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMine,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            _EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Bado hujatuma ombi',
              message: 'Maombi ya punguzo au kikomo cha mkopo yataonekana hapa.',
              isDark: isDark,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _mine.length,
        itemBuilder: (context, index) => _ApprovalCard(
          approval: _mine[index],
          index: index + 1,
          money: _money,
          isDark: isDark,
          showRequester: false,
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
    required this.showRequester,
    required this.onTap,
  });

  final Approval approval;
  final int index;
  final NumberFormat money;
  final bool isDark;
  final bool showRequester;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = approval.detail;
    final isDiscount = approval.kind == ApprovalKind.discount;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Serial number, matching the other list screens in this app.
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isDiscount ? AppColors.warning : AppColors.info)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDiscount ? AppColors.warning : AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDiscount ? Icons.local_offer : Icons.credit_card,
                          size: 15,
                          color: isDiscount ? AppColors.warning : AppColors.info,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isDiscount ? 'Punguzo' : 'Kikomo cha Mkopo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDiscount ? AppColors.warning : AppColors.info,
                          ),
                        ),
                        const Spacer(),
                        _StatusBadge(status: approval.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail?.customerName ?? 'Mteja hajulikani',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDiscount && detail?.itemName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${detail!.itemName}  ·  ${money.format(detail.quantity ?? 0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextLight
                                : AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${money.format(detail?.headlineAmount ?? 0)} TSh',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        if (detail?.documentNumber != null)
                          Text(
                            detail!.documentNumber!,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final response = await _api.getApprovalDetail(widget.approvalId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (response.isSuccess && response.data != null) {
        _data = response.data;
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _act(bool approve) async {
    final comment = _comment.text.trim();

    // The server enforces this too, but catching it here saves a round trip
    // and gives the reason field focus instead of a red snackbar.
    if (!approve && comment.isEmpty) {
      setState(() => _error = 'Andika sababu ya kukataa');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final response = await _api.actOnApproval(
      approvalId: widget.approvalId,
      approve: approve,
      comment: comment,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Ombi limeidhinishwa' : 'Ombi limekataliwa'),
          backgroundColor: approve ? AppColors.success : AppColors.error,
        ),
      );
    } else {
      setState(() {
        _submitting = false;
        _error = response.message;
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
      return _ErrorState(
        message: _error ?? 'Imeshindikana kupakia',
        onRetry: _load,
        isDark: isDark,
      );
    }

    final detail = data.approval.detail;
    final isDiscount = data.approval.kind == ApprovalKind.discount;
    final canAct = data.canApprove || data.canReject;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Row(
                children: [
                  Icon(
                    isDiscount ? Icons.local_offer : Icons.credit_card,
                    color: isDiscount ? AppColors.warning : AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDiscount ? 'Ombi la Punguzo' : 'Ombi la Kikomo cha Mkopo',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ),
                  _StatusBadge(status: data.approval.status),
                ],
              ),
              if (detail?.documentNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    detail!.documentNumber!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              _Field(label: 'Mteja', value: detail?.customerName ?? '-', isDark: isDark),
              if (isDiscount) ...[
                _Field(label: 'Bidhaa', value: detail?.itemName ?? '-', isDark: isDark),
                _Field(
                  label: 'Idadi',
                  value: widget.money.format(detail?.quantity ?? 0),
                  isDark: isDark,
                ),
                _Field(
                  label: 'Punguzo kwa kila kimoja',
                  value: '${widget.money.format(detail?.discountAmount ?? 0)} TSh',
                  isDark: isDark,
                  emphasise: true,
                ),
                _Field(label: 'Eneo', value: detail?.locationName ?? '-', isDark: isDark),
                _Field(label: 'Tarehe', value: detail?.validDate ?? '-', isDark: isDark),
              ] else ...[
                _Field(
                  label: 'Kikomo kinachoombwa',
                  value: '${widget.money.format(detail?.creditAmount ?? 0)} TSh',
                  isDark: isDark,
                  emphasise: true,
                ),
                if (detail?.previousAmount != null)
                  _Field(
                    label: 'Kikomo cha awali',
                    value: '${widget.money.format(detail!.previousAmount!)} TSh',
                    isDark: isDark,
                  ),
                if (detail?.currentBalance != null)
                  _Field(
                    label: 'Deni la sasa',
                    value: '${widget.money.format(detail!.currentBalance!)} TSh',
                    isDark: isDark,
                  ),
              ],
              if (detail?.reason != null)
                _Field(label: 'Sababu', value: detail!.reason!, isDark: isDark),

              const SizedBox(height: 18),
              Text(
                'Mwenendo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              ...data.history.map((entry) => _HistoryTile(entry: entry, isDark: isDark)),

              if (canAct) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _comment,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Maoni (lazima ukikataa)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (canAct)
          Container(
            padding: const EdgeInsets.all(16),
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
                      label: const Text('Kataa'),
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
                      label: const Text('Idhinisha'),
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
  const _Field({
    required this.label,
    required this.value,
    required this.isDark,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
                fontSize: emphasise ? 15 : 13,
                fontWeight: emphasise ? FontWeight.bold : FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.isDark});

  final ApprovalHistoryEntry entry;
  final bool isDark;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.actorName ?? 'Mtumiaji'}'
                  '${entry.roleName != null ? ' · ${entry.roleName}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                if (entry.comment != null)
                  Text(
                    entry.comment!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
                if (entry.createdAt != null)
                  Text(
                    entry.createdAt!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
              ],
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
        return ('IMEIDHINISHWA', AppColors.success);
      case 'rejected':
        return ('IMEKATALIWA', AppColors.error);
      case 'returned':
        return ('IMERUDISHWA', AppColors.warning);
      case 'discarded':
        return ('IMEFUTWA', AppColors.textLight);
      case 'in_progress':
        return ('INAENDELEA', AppColors.info);
      default:
        return ('INASUBIRI', AppColors.warning);
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
          fontWeight: FontWeight.bold,
          color: colour,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: isDark ? AppColors.darkTextLight : Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Jaribu tena'),
            ),
          ],
        ),
      ),
    );
  }
}
