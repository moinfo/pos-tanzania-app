import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/online_order.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/state_views.dart';
import '../widgets/tr_text.dart';
import 'online_order_details_screen.dart';

/// Orders customers placed on the public shop -- the app's version of the web
/// module at /online_orders: a date range (today by default), a pill per status
/// with its count, search, and delete for users who hold that permission.
class OnlineOrdersScreen extends StatefulWidget {
  const OnlineOrdersScreen({super.key, this.pendingOnly = false});

  /// Opened from the bell: the pending orders of ANY date (that is what the
  /// bell counts), newest first. The pills and dates still work from there.
  final bool pendingOnly;

  /// Colours of the status pills and labels, as on the web.
  static Color statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF5BC0DE);
      case 'processing':
        return const Color(0xFF8E5EA2);
      case 'ready':
        return const Color(0xFF17A2A2);
      case 'delivered':
        return const Color(0xFF5CB85C);
      case 'cancelled':
        return const Color(0xFFD9534F);
      default:
        return const Color(0xFFF0AD4E);
    }
  }

  static String statusLabel(String status) =>
      status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);

  static String money(double v) => 'TZS ${NumberFormat('#,##0').format(v)}';

  @override
  State<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends State<OnlineOrdersScreen> {
  final _api = ApiService();
  static final _ymd = DateFormat('yyyy-MM-dd');

  OnlineOrdersPage? _page;
  String _status = ''; // '' = all
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _loading = true;
  String? _error;

  String _query = '';
  bool _searching = false;
  final _searchController = TextEditingController();

  /// Order ids ticked for deletion; selection mode is on while non-empty.
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    if (widget.pendingOnly) {
      _status = 'pending';
      _from = DateTime(2020);
      _to = DateTime.now();
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    final res = await _api.getOnlineOrders(
      status: _status,
      startDate: _ymd.format(_from),
      endDate: _ymd.format(_to),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.data != null) {
        _page = res.data;
        _error = null;
        _selected.removeWhere((id) => !res.data!.orders.any((o) => o.orderId == id));
      } else {
        _error = res.message;
      }
    });
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
    _load();
  }

  void _today() {
    setState(() {
      _from = DateTime.now();
      _to = DateTime.now();
    });
    _load();
  }

  List<OnlineOrder> get _visible {
    final orders = _page?.orders ?? const <OnlineOrder>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders.where((o) {
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.toLowerCase().contains(q) ||
          o.itemNames.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _open(OnlineOrder order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineOrderDetailsScreen(
          orderId: order.orderId,
          canEdit: _page?.canEdit ?? false,
        ),
      ),
    );
    if (changed == true) _load(showSpinner: false);
  }

  Future<void> _confirmDelete() async {
    final orders =
        (_page?.orders ?? []).where((o) => _selected.contains(o.orderId)).toList();
    if (orders.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteOrdersDialog(orders: orders),
    );
    if (ok != true || !mounted) return;

    final res = await _api.deleteOnlineOrders(orders.map((o) => o.orderId).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.isSuccess ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
    if (res.isSuccess) _selected.clear();
    _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final selecting = _selected.isNotEmpty;

    final content = Column(
      children: [

        _dateBar(isDark),
        _statusPills(),
        Expanded(child: _body(isDark)),
      ],
    );


    return Scaffold(
      appBar: AppBar(
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              )
            : null,
        title: _titleWidget(selecting),
        actions: _actions(selecting),
      ),
      body: content,
      // The same bottom bar as the other side-menu screens; the drawer entry
      // announces its icon, which the bar shows in the centre notch.
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  /// Title, or the selection count, or the search box -- shared by the
  /// stand-alone app bar and the embedded header.
  Widget _titleWidget(bool selecting) {
    if (selecting) return Text('${_selected.length} selected');
    if (_searching) {
      return TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search orders',
          border: InputBorder.none,
        ),
        onChanged: (v) => setState(() => _query = v),
      );
    }
    return Text(widget.pendingOnly ? 'Pending Orders' : 'Online Orders');
  }

  List<Widget> _actions(bool selecting) => [
        if (selecting)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          )
        else
          IconButton(
            tooltip: 'Search',
            icon: Icon(_searching ? Icons.search_off : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query = '';
                _searchController.clear();
              }
            }),
          ),
      ];

  Widget _dateBar(bool isDark) {
    final fmt = DateFormat('d MMM yy');
    // Never cut off: the text shrinks to fit rather than ending in "...".
    Widget dateButton(String label, DateTime d, bool from) => Expanded(
          child: OutlinedButton(
            onPressed: () => _pickDate(from: from),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 15),
                  const SizedBox(width: 6),
                  Text('$label ${fmt.format(d)}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          dateButton('From', _from, true),
          const SizedBox(width: 8),
          dateButton('To', _to, false),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: _today,
            child: const Text('Today'),
          ),
        ],
      ),
    );
  }

  Widget _statusPills() {
    final counts = _page?.counts ?? const <String, int>{};
    Widget pill(String status, String label, int count, Color color) {
      final selected = _status == status;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _status = status);
            _load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 1.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : color)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? color : Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // A wrapping block, not a sideways-scrolling row: every status is
    // visible at once, flowing onto a second line when it does not fit.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      child: Wrap(
        runSpacing: 8,
        children: [
          pill('', 'All', _page?.total ?? 0, AppColors.brandPrimary),
          for (final s in OnlineOrder.statuses)
            pill(s, OnlineOrdersScreen.statusLabel(s), counts[s] ?? 0,
                OnlineOrdersScreen.statusColor(s)),
        ],
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _page == null) {
      return ErrorStateView(
        message: _error!,
        isDark: isDark,
        // A permission refusal answers the same way every time.
        onRetry: _error!.contains('permission') ? null : () => _load(),
      );
    }
    final orders = _visible;
    if (orders.isEmpty) {
      return EmptyStateView(
        icon: Icons.inbox_outlined,
        title: 'No orders found',
        message: 'Try another date range or status.',
        isDark: isDark,
        onRefresh: () => _load(showSpinner: false),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: orders.length,
        itemBuilder: (_, i) => _orderCard(orders[i], isDark),
      ),
    );
  }

  Widget _orderCard(OnlineOrder o, bool isDark) {
    final color = OnlineOrdersScreen.statusColor(o.status);
    final canDelete = _page?.canDelete ?? false;
    final ticked = _selected.contains(o.orderId);
    final muted = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);

    void toggle() => setState(() {
          ticked ? _selected.remove(o.orderId) : _selected.add(o.orderId);
        });

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: ticked ? AppColors.error : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        onTap: _selected.isNotEmpty ? toggle : () => _open(o),
        onLongPress: canDelete ? toggle : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    ticked ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: ticked ? AppColors.error : muted,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(o.orderNumber,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(OnlineOrdersScreen.statusLabel(o.status),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                        // The web list's "View" button, as an eye icon.
                        if (_selected.isEmpty) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'View',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _open(o),
                              child: Container(
                                width: 34,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.visibility_outlined,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${o.customerName} · ${o.customerPhone}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(o.itemNames,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(o.createdAt.length >= 16
                            ? o.createdAt.substring(0, 16)
                            : o.createdAt,
                            style: TextStyle(color: muted, fontSize: 12)),
                        if (o.saleId != null) ...[
                          const SizedBox(width: 10),
                          Text('POS ${o.saleId}',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                        const Spacer(),
                        Text(OnlineOrdersScreen.money(o.total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
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

/// "Delete N orders?" -- says what happens to each one, like the web modal.
class _DeleteOrdersDialog extends StatelessWidget {
  const _DeleteOrdersDialog({required this.orders});

  final List<OnlineOrder> orders;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final muted = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    const danger = Color(0xFFD9534F);
    final delivered = orders.where((o) => o.isLocked).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE5533D), Color(0xFFB3261E)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Delete ${orders.length} ${orders.length == 1 ? 'order' : 'orders'}?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text('This action cannot be undone',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                children: [
                  for (final o in orders)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                            left: BorderSide(color: danger, width: 4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${o.orderNumber} · ${o.customerName}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: ink)),
                          const SizedBox(height: 2),
                          Text('${o.itemNames} × ${o.quantities}',
                              style: TextStyle(fontSize: 12.5, color: muted)),
                          const SizedBox(height: 4),
                          Text(
                            o.isLocked
                                ? 'Delivered – sale POS ${o.saleId} will be cancelled and the quantity returned to stock'
                                : 'Not delivered – no stock is affected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: o.isLocked
                                  ? const Color(0xFFB8710A)
                                  : const Color(0xFF3C8A3C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (delivered > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE0A3)),
                      ),
                      child: const Text(
                        'Delivered orders are cancelled as sales and their item '
                        'quantities are returned to stock.',
                        style: TextStyle(
                            fontSize: 12.5, color: Color(0xFF8A5A00)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        backgroundColor: danger,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Yes, delete'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
