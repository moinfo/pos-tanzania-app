import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/transfer_approval.dart';
import '../models/permission_model.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

/// Review queue for stock transfer requests, staged while a tenant has
/// "Require approval for stock transfers" turned on (My Subscription). The
/// list endpoint returns pending rows only, so there is no status filter
/// here -- once acted on, a row leaves.
///
/// The list response carries the same from/to transfer detail as a single
/// request, so cards show what's actually moving without a tap -- a
/// reviewer working through several pending transfers needs that at a
/// glance, and it's also what a future bulk-approve selection would need.
class TransferApprovalsScreen extends StatefulWidget {
  const TransferApprovalsScreen({super.key});

  @override
  State<TransferApprovalsScreen> createState() =>
      _TransferApprovalsScreenState();
}

class _TransferApprovalsScreenState extends State<TransferApprovalsScreen> {
  final ApiService _apiService = ApiService();
  List<TransferApproval> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  // A tap on the app bar's "Select" icon or a long-press on a card enters
  // selection mode. Tracked separately from _selectedIds (rather than
  // "non-empty set IS selection mode") so the mode survives deselecting
  // everything -- tapping the last checked row off shouldn't silently kick
  // you back to normal browsing.
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // A reload means the underlying rows may have changed (acted on
      // elsewhere, or by the bulk action that triggered this reload) --
      // stale selection would let a user "approve" ids no longer pending.
      _selectionMode = false;
      _selectedIds.clear();
    });

    final response = await _apiService.getTransferApprovals();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _requests = response.data!.requests;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return DateFormat('dd MMM, HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _openDetail(TransferApproval summary) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApprovalDetailSheet(requestId: summary.requestId),
    );

    // Acted on (approved/rejected) -- the row is no longer pending.
    if (changed == true) {
      _loadRequests();
    }
  }

  /// Entry point for the app bar's "Select" icon -- turns on selection mode
  /// with nothing picked yet. [seedId], when given (a long-press on a card),
  /// also selects that row in the same tap.
  void _enterSelectionMode([int? seedId]) {
    setState(() {
      _selectionMode = true;
      if (seedId != null) _selectedIds.add(seedId);
    });
  }

  void _toggleSelect(int requestId) {
    setState(() {
      if (!_selectedIds.remove(requestId)) {
        _selectedIds.add(requestId);
      }
    });
  }

  void _selectAll() {
    setState(() => _selectedIds.addAll(_requests.map((r) => r.requestId)));
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkApprove() async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Approve ${ids.length} transfer${ids.length == 1 ? '' : 's'}?'),
        content: const Text(
          'Stock moves immediately for each one, one at a time. Any that fail '
          '(e.g. stock changed since you reviewed it) are skipped and stay pending.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve all',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runBulk(ids, isApprove: true);
  }

  Future<void> _bulkReject() async {
    final ids = _selectedIds.toList();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text('Reject ${ids.length} transfer${ids.length == 1 ? '' : 's'}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Requesters keep their drafts; nothing is moved.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional, applied to all)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child:
                const Text('Reject all', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }
    final reason = controller.text.trim();
    controller.dispose();

    await _runBulk(ids, isApprove: false, reason: reason);
  }

  /// One request to a dedicated bulk endpoint (approve_bulk / reject_bulk),
  /// not N calls to the single-item endpoint from here -- that's also what
  /// makes transfers_bulk_approve a real, server-enforced permission rather
  /// than just a client-side button hide (see PermissionIds.transfersApproveBulk).
  /// The server still processes each id one at a time internally for the
  /// same reason a client-side loop would have: N simultaneous mutations of
  /// possibly-overlapping stock is exactly the race this workflow exists to
  /// avoid.
  Future<void> _runBulk(List<int> ids,
      {required bool isApprove, String? reason}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(isApprove ? 'Approving…' : 'Rejecting…'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Text('${ids.length} transfer${ids.length == 1 ? '' : 's'}'),
          ],
        ),
      ),
    );

    final response = isApprove
        ? await _apiService.approveTransferApprovalsBulk(ids)
        : await _apiService.rejectTransferApprovalsBulk(ids, reason: reason);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pop(); // close the progress dialog

    if (!response.isSuccess || response.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.error,
        ),
      );
      _loadRequests();
      return;
    }

    final result = response.data!;
    final failures = result.results
        .where((r) => !r.success)
        .map((r) => '#${r.id}: ${r.message ?? 'unknown error'}')
        .toList();

    final verb = isApprove ? 'approved' : 'rejected';
    final allOk = failures.isEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allOk
            ? '${result.succeeded} transfer${result.succeeded == 1 ? '' : 's'} $verb'
            : '${result.succeeded} $verb, ${failures.length} failed — see below for why'),
        backgroundColor: allOk ? AppColors.success : Colors.orange.shade800,
        duration: Duration(seconds: allOk ? 3 : 4),
      ),
    );

    if (failures.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Some requests failed'),
          content: SingleChildScrollView(
            child: Text(failures.join('\n\n')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }

    _loadRequests(); // also clears _selectedIds
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    // Gates selection mode entirely, not just the action buttons -- someone
    // without transfers_bulk_approve still reviews and decides one at a
    // time via a tap (PermissionIds.transfersApprove, checked in the detail
    // sheet), they just never see a way to select more than one.
    final canBulk = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.transfersApproveBulk);

    return PopScope(
      // Back exits selection mode first rather than leaving the screen --
      // the same "cancel the mode, not the screen" behaviour as Gmail/Photos.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(_selectionMode
              ? '${_selectedIds.length} selected'
              : 'Transfer Approvals'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close), onPressed: _exitSelectionMode)
              : null,
          actions: _selectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: 'Select all',
                    onPressed: _selectedIds.length == _requests.length
                        ? null
                        : _selectAll,
                  ),
                ]
              : [
                  if (canBulk && _requests.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.checklist),
                      tooltip: 'Select multiple',
                      onPressed: () => _enterSelectionMode(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadRequests,
                  ),
                ],
        ),
        bottomNavigationBar:
            _selectionMode && canBulk ? _buildBulkActionBar(isDark) : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadRequests,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _requests.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25),
                            Icon(Icons.inbox_outlined,
                                size: 56,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing waiting for approval',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextLight
                                    : Colors.grey[500],
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _requests.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_requests[i], isDark, canBulk),
                        ),
                      ),
      ),
    );
  }

  Widget _buildBulkActionBar(bool isDark) {
    final count = _selectedIds.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: count == 0 ? null : _bulkReject,
              icon: const Icon(Icons.close, size: 18),
              label: Text('Reject ($count)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: count == 0 ? null : _bulkApprove,
              icon: const Icon(Icons.check, size: 18),
              label: Text('Approve ($count)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(TransferApproval r, bool isDark, bool canSelect) {
    final color = r.isFromApp ? AppColors.info : AppColors.warning;
    final selected = _selectedIds.contains(r.requestId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected
          ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
          : (isDark ? AppColors.darkCard : Colors.white),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            _selectionMode ? _toggleSelect(r.requestId) : _openDetail(r),
        onLongPress: canSelect
            ? () => _selectionMode
                ? _toggleSelect(r.requestId)
                : _enterSelectionMode(r.requestId)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (_selectionMode)
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.primary
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  size: 24,
                )
              else
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.swap_horiz_rounded, color: color, size: 22),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${r.qtySummary} · ${r.requesterName ?? 'Unknown'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            isDark ? AppColors.darkTextLight : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(r.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color:
                          isDark ? AppColors.darkTextLight : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!_selectionMode)
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: isDark ? Colors.grey[700] : Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail + act. Still fetches by id on open rather than reusing the row
/// already in hand -- the list is a point-in-time snapshot, and this is
/// the screen where stale data costs real money (approving against a
/// quantity that changed a second after the list loaded).
class _ApprovalDetailSheet extends StatefulWidget {
  final int requestId;

  const _ApprovalDetailSheet({required this.requestId});

  @override
  State<_ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends State<_ApprovalDetailSheet> {
  final ApiService _apiService = ApiService();
  TransferApproval? _request;
  bool _isLoading = true;
  bool _isActing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await _apiService.getTransferApproval(widget.requestId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _request = response.data;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve transfer'),
        content: const Text('Apply this transfer? Stock moves immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActing = true);
    final response =
        await _apiService.approveTransferApproval(widget.requestId);
    if (!mounted) return;
    setState(() => _isActing = false);
    _finish(response.isSuccess, response.message);
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The requester keeps their draft; nothing is moved.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }

    setState(() => _isActing = true);
    final reason = controller.text.trim();
    controller.dispose();
    final response = await _apiService.rejectTransferApproval(
      widget.requestId,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _isActing = false);
    _finish(response.isSuccess, response.message);
  }

  void _finish(bool success, String message) {
    // Grab the messenger BEFORE popping: afterwards this State's context is
    // deactivated and ScaffoldMessenger.of(context) would throw. The snackbar
    // still lands on the list screen, which is what we want.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, success);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canAct = permissions.hasPermission(PermissionIds.transfersApprove);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            )
          else ...[
            Flexible(child: _buildBody(isDark)),
            _buildActions(isDark, canAct),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final r = _request!;
    final t = r.transfer;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.displayTitle,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.sourceLabel} · requested by ${r.requesterName ?? 'Unknown'}',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const Divider(height: 24),
          if (t != null)
            _buildTransferDetail(t, isDark)
          else
            Text('Transfer detail unavailable.',
                style: TextStyle(color: subColor)),
        ],
      ),
    );
  }

  Widget _buildTransferDetail(TransferDiff t, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _transferBox(
          icon: Icons.remove_circle_outline,
          color: AppColors.error,
          label: 'From',
          item: t.fromItem,
          qty: TransferDiff.label(t.fromQty),
          before: t.fromBefore,
          isDark: isDark,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(Icons.arrow_downward, size: 18, color: AppColors.primary),
            ],
          ),
        ),
        _transferBox(
          icon: Icons.add_circle_outline,
          color: AppColors.success,
          label: 'To',
          // A mobile-submitted transfer may not have resolved a specific
          // child item yet -- see the TransferDiff class doc.
          item: t.toItem ?? 'Not yet resolved',
          qty: TransferDiff.label(t.toQty),
          before: t.toBefore,
          isDark: isDark,
        ),
        if (t.note != null && t.note!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16,
                    color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.note!,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkTextLight
                            : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _transferBox({
    required IconData icon,
    required Color color,
    required String label,
    required String item,
    required String qty,
    dynamic before,
    required bool isDark,
  }) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: subColor)),
                Text(item,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(qty,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              if (before != null)
                Text('was ${TransferDiff.label(before)}',
                    style: TextStyle(fontSize: 11.5, color: subColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark, bool canAct) {
    if (!canAct) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'You do not have permission to approve or reject transfers.',
          style: TextStyle(
              color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isActing ? null : _reject,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isActing ? null : _approve,
              icon: _isActing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
