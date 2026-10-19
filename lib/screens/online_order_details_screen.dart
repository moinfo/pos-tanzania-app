import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/online_order.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/state_views.dart';
import '../widgets/tr_text.dart';
import 'online_orders_screen.dart';

/// One online order: the customer, its status (changeable for users who may
/// edit) and the items. Same rules as the web page /online_orders/view/{id}:
///  - the status can be set to any value;
///  - "Delivered" asks for confirmation, then records a cash POS sale, deducts
///    stock, saves the customer and locks the order;
///  - a locked order cannot be changed any more.
class OnlineOrderDetailsScreen extends StatefulWidget {
  const OnlineOrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.canEdit,
  });

  final int orderId;
  final bool canEdit;

  @override
  State<OnlineOrderDetailsScreen> createState() =>
      _OnlineOrderDetailsScreenState();
}

class _OnlineOrderDetailsScreenState extends State<OnlineOrderDetailsScreen> {
  final _api = ApiService();

  OnlineOrder? _order;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  String _selectedStatus = 'pending';

  /// Set once the order is changed here, so the list refreshes on the way back.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getOnlineOrder(widget.orderId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.data != null) {
        _order = res.data;
        _selectedStatus = res.data!.status;
        _error = null;
      } else {
        _error = res.message;
      }
    });
  }

  Future<void> _update() async {
    final order = _order;
    if (order == null || _selectedStatus == order.status) return;

    if (_selectedStatus == 'delivered') {
      final ok = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => _DeliverDialog(order: order),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);
    final res = await _api.updateOnlineOrderStatus(order.orderId, _selectedStatus);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.isSuccess ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
    if (res.isSuccess && res.data != null) {
      _changed = true;
      setState(() {
        _order = res.data;
        _selectedStatus = res.data!.status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_order == null ? 'Order' : 'Order ${_order!.orderNumber}'),
        ),
        body: _body(isDark),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_order == null) {
      return ErrorStateView(
          message: _error ?? 'Order not found', isDark: isDark, onRetry: _load);
    }
    final o = _order!;
    final muted = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final color = OnlineOrdersScreen.statusColor(o.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          // Customer and order facts, like the web table.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('Customer', Text(o.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700)), muted),
                  _row(
                    'Phone',
                    Row(
                      children: [
                        Expanded(child: Text(o.customerPhone)),
                        if (o.customerPhone.isNotEmpty)
                          InkWell(
                            onTap: () => launchUrl(
                                Uri(scheme: 'tel', path: o.customerPhone)),
                            child: Icon(Icons.call,
                                size: 20, color: AppColors.brandPrimary),
                          ),
                      ],
                    ),
                    muted,
                  ),
                  _row('Email', Text(o.customerEmail ?? ''), muted),
                  _row('Address', Text(o.customerAddress ?? ''), muted),
                  _row('Notes', Text(o.notes ?? ''), muted),
                  _row('Placed', Text(o.createdAt), muted),
                  _row(
                    'Status',
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(OnlineOrdersScreen.statusLabel(o.status),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    muted,
                  ),
                  _row(
                    'Sale',
                    Text(o.saleId != null
                        ? 'POS ${o.saleId} (${o.deliveredAt ?? ''})'
                        : '-'),
                    muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _statusSection(o, muted),
          const SizedBox(height: 10),
          // Items.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (final i in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.itemName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '${i.isWholesale ? 'Wholesale' : 'Retail'} · '
                                  '${i.quantityText} × ${OnlineOrdersScreen.money(i.unitPrice)}',
                                  style: TextStyle(color: muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Text(OnlineOrdersScreen.money(i.subtotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  const Divider(height: 22),
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16))),
                      Text(OnlineOrdersScreen.money(o.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget value, Color muted) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(label,
                  style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: value),
          ],
        ),
      );

  /// The status control: locked after delivery, read-only without the Edit
  /// permission, otherwise a dropdown plus "Update status".
  Widget _statusSection(OnlineOrder o, Color muted) {
    if (o.isLocked) {
      return _banner(
        icon: Icons.lock_outline,
        color: AppColors.success,
        text: 'Delivered and recorded as sale POS ${o.saleId}. '
            'This order is locked.',
      );
    }
    if (!widget.canEdit) {
      return _banner(
        icon: Icons.info_outline,
        color: AppColors.warning,
        text: 'You can view this order but you do not have permission to '
            'change its status.',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change status',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (final s in OnlineOrder.statuses)
                  DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: OnlineOrdersScreen.statusColor(s),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(OnlineOrdersScreen.statusLabel(s)),
                      ],
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  (_saving || _selectedStatus == o.status) ? null : _update,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update status'),
            ),
            const SizedBox(height: 8),
            Text(
              'Delivered records the order as a sale dated today, saves the '
              'customer in the customer list and deducts quantities (retail '
              'items from STOCK 2, wholesale items from STOCK 3).',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(
          {required IconData icon,
          required Color color,
          required String text}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

/// "Mark as delivered?" -- shows what delivering does before it is done, as
/// the web modal does: the sale, the stock it comes from, the customer, the lock.
class _DeliverDialog extends StatelessWidget {
  const _DeliverDialog({required this.order});

  final OnlineOrder order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final muted = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    const green = Color(0xFF2E9E4F);

    Widget effect(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: green),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: TextStyle(fontSize: 13, color: ink))),
            ],
          ),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
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
                  colors: [Color(0xFF43B867), Color(0xFF1F8A45)],
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
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text('Mark as delivered?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Order ${order.orderNumber} · ${order.customerName}',
                      textAlign: TextAlign.center,
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF243028)
                          : const Color(0xFFF7FBF8),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                          left: BorderSide(color: green, width: 4)),
                    ),
                    child: Column(
                      children: [
                        for (final i in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${i.itemName} × ${i.quantityText}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: ink)),
                                      Text(
                                        i.isWholesale
                                            ? 'Wholesale – STOCK 3 - WHOLESALES'
                                            : 'Retail – STOCK 2 - RETAIL',
                                        style: TextStyle(
                                            fontSize: 11.5, color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(OnlineOrdersScreen.money(i.subtotal),
                                    style: TextStyle(
                                        fontSize: 13, color: ink)),
                              ],
                            ),
                          ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: Text('Total',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: ink))),
                            Text(OnlineOrdersScreen.money(order.total),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, color: ink)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  effect(Icons.shopping_cart_outlined,
                      'A sale is recorded for today (cash)'),
                  effect(Icons.inventory_2_outlined,
                      'The item quantities are deducted from stock'),
                  effect(Icons.person_outline,
                      'The customer is saved in the customer list'),
                  effect(Icons.lock_outline,
                      'The order is locked afterwards'),
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE0A3)),
                    ),
                    child: const Text(
                      'This cannot be undone. To reverse it later you would '
                      'have to delete the order, which cancels the sale and '
                      'returns the stock.',
                      style:
                          TextStyle(fontSize: 12.5, color: Color(0xFF8A5A00)),
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
                        backgroundColor: green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23)),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Yes, deliver'),
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
