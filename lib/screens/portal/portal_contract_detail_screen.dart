import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../models/portal_contract_detail.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
import 'portal_payments_screen.dart';
import 'portal_statement_screen.dart';

/// Full statement page for one contract -- mirrors web's portal/contract.php
/// (stat cards, terms/guarantor/asset details, progress bar, real payment
/// ledger) instead of the old bare Balance/Total Paid/Daily Rate card and a
/// day-by-day projected schedule table.
class PortalContractDetailScreen extends StatefulWidget {
  final Contract contract;

  const PortalContractDetailScreen({super.key, required this.contract});

  @override
  State<PortalContractDetailScreen> createState() =>
      _PortalContractDetailScreenState();
}

class _PortalContractDetailScreenState
    extends State<PortalContractDetailScreen> {
  final _service = CustomerApiService();
  PortalContractDetail? _detail;
  bool _isLoading = true;
  String? _error;
  bool _showAllPayments = false;

  static const _visibleCount = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await _service.getContractDetail(widget.contract.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _detail = response.data;
      } else {
        _error = response.message;
      }
    });
  }

  /// Lets the customer set/change the WhatsApp number on this contract
  /// (separate from their phone above, which is their login identity and
  /// not editable here). Falls back to that phone for WhatsApp sends when
  /// left blank -- see Contract::send_contract_message() on the backend.
  Future<void> _editWhatsappNumber() async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final controller = TextEditingController(
        text: _detail?.contract.whatsappPhone ?? widget.contract.whatsappPhone);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(PortalStrings.t('whatsapp_dialog_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PortalStrings.t('whatsapp_dialog_body'),
              style: TextStyle(
                  fontSize: 12.5,
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: PortalStrings.t('whatsapp_number_field'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(PortalStrings.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(PortalStrings.t('save')),
          ),
        ],
      ),
    );

    if (result == null) return;
    final response =
        await _service.updateWhatsappPhone(widget.contract.id, result);
    if (!mounted) return;
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PortalStrings.t('whatsapp_saved')),
            backgroundColor: AppColors.success),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) {
        final title = widget.contract.contractDescription.isNotEmpty
            ? widget.contract.contractDescription
            : '${PortalStrings.t('contract_label')} #${widget.contract.id}';
        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              const PortalLanguageSwitch(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'payments') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PortalPaymentsScreen(contract: widget.contract),
                      ),
                    );
                  } else if (value == 'statement') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PortalStatementScreen(contract: widget.contract),
                      ),
                    );
                  } else if (value == 'whatsapp') {
                    _editWhatsappNumber();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'payments',
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(PortalStrings.t('payments_menu')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'statement',
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(PortalStrings.t('statement_menu')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: ListTile(
                      leading: const Icon(Icons.chat_outlined),
                      title: Text(PortalStrings.t('whatsapp_menu')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _detail == null
                        ? _buildError()
                        : _buildBody(_detail!, isDark),
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(PortalContractDetail detail, bool isDark) {
    final c = detail.contract;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (c.isTerminated) _buildTerminatedBanner(c, isDark),
        _buildStatGrid(detail),
        const SizedBox(height: 16),
        _buildDetailsCard(c, isDark),
        const SizedBox(height: 16),
        _buildProgress(c, detail, isDark),
        const SizedBox(height: 20),
        if (detail.undatedTotal > 0)
          _buildUndatedNote(detail.undatedTotal, isDark),
        _buildLedgerHeader(detail, isDark),
        const SizedBox(height: 8),
        if (detail.paymentsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: Text(PortalStrings.t('no_payments_yet'),
                    style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight))),
          )
        else
          _buildLedger(detail, isDark),
      ],
    );
  }

  Widget _buildTerminatedBanner(Contract c, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(isDark ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              PortalStrings.t('terminated_banner', {
                '0': (c.terminationReason?.isNotEmpty ?? false)
                    ? ': ${c.terminationReason}'
                    : '.'
              }),
              style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(PortalContractDetail detail) {
    final c = detail.contract;
    final cards = [
      _StatCardData(PortalStrings.t('contract_cost'), c.contractCost,
          const Color(0xFF233A5C), PortalStrings.t('amount_disbursed')),
      _StatCardData(
          PortalStrings.t('debt_to_date'),
          detail.owedToDate,
          const Color(0xFF55677A),
          PortalStrings.t('debt_to_date_sub', {
            '0': Formatters.formatCurrency(c.returnAmount),
            '1': '${c.days}',
          })),
      _StatCardData(
          PortalStrings.t('total_paid'),
          c.payments,
          AppColors.success,
          PortalStrings.t(
              'n_payments', {'0': '${detail.paymentsList.length}'})),
      _StatCardData(
          PortalStrings.t('overdue_debt'),
          c.currentUnpaid,
          AppColors.error,
          c.currentUnpaid > 0
              ? PortalStrings.t(
                  'overdue_days', {'0': '${c.daysUnpaid.toInt()}'})
              : PortalStrings.t('nothing_overdue')),
      _StatCardData(
          PortalStrings.t('contract_balance'),
          c.balance > 0 ? c.balance : 0,
          const Color(0xFF2C7A68),
          c.balance <= 0
              ? PortalStrings.t('fully_paid_small')
              : PortalStrings.t('remaining')),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: cards.map((card) => _statCard(card)).toList(),
    );
  }

  Widget _statCard(_StatCardData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .2)),
          const SizedBox(height: 4),
          Text('TSH ${Formatters.formatCurrency(data.value)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(data.sub,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Contract c, bool isDark) {
    final rows = <MapEntry<String, String>>[
      MapEntry(PortalStrings.t('starts'), c.date),
      MapEntry(PortalStrings.t('ends'), c.endDate),
      MapEntry(PortalStrings.t('duration'),
          PortalStrings.t('n_months', {'0': '${c.contractTime}'})),
      MapEntry(PortalStrings.t('daily_rate_label'),
          'TSH ${Formatters.formatCurrency(c.returnAmount)}'),
      MapEntry(
          PortalStrings.t('whatsapp_number_field'),
          (c.whatsappPhone ?? '').isNotEmpty
              ? c.whatsappPhone!
              : PortalStrings.t('not_set')),
      if (c.guarantor1.isNotEmpty)
        MapEntry(PortalStrings.t('guarantor_1'),
            '${c.guarantor1} · ${c.phoneGuarantor1}'),
      if (c.guarantor2.isNotEmpty)
        MapEntry(PortalStrings.t('guarantor_2'),
            '${c.guarantor2} · ${c.phoneGuarantor2}'),
      if ((c.assetPlateNumber ?? '').isNotEmpty)
        MapEntry(PortalStrings.t('plate_number'), c.assetPlateNumber!),
      if ((c.assetChassisNumber ?? '').isNotEmpty)
        MapEntry(PortalStrings.t('chassis'), c.assetChassisNumber!),
      if ((c.assetInsuranceProvider ?? '').isNotEmpty)
        MapEntry(PortalStrings.t('insurance'), c.assetInsuranceProvider!),
      if ((c.assetInsuranceExpiry ?? '').isNotEmpty)
        MapEntry(PortalStrings.t('insurance_expiry'), c.assetInsuranceExpiry!),
    ];

    final textLight = isDark ? AppColors.darkTextLight : AppColors.textLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(PortalStrings.t('contract_details_header'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textLight,
                  letterSpacing: .3)),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.key,
                      style: TextStyle(fontSize: 12.5, color: textLight)),
                  Flexible(
                    child: Text(row.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(Contract c, PortalContractDetail detail, bool isDark) {
    final pct = detail.progressPct.clamp(0, 100);
    final textLight = isDark ? AppColors.darkTextLight : AppColors.textLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(PortalStrings.t('payment_progress'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text('$pct%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor:
                  isDark ? AppColors.darkDivider : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.date, style: TextStyle(fontSize: 10.5, color: textLight)),
              Text(
                  PortalStrings.t(
                      'today_label', {'0': Formatters.getTodayFormatted()}),
                  style: TextStyle(fontSize: 10.5, color: textLight)),
              Text(c.endDate,
                  style: TextStyle(fontSize: 10.5, color: textLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUndatedNote(double undatedTotal, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        PortalStrings.t(
            'undated_note', {'0': Formatters.formatCurrency(undatedTotal)}),
        style: TextStyle(
            fontSize: 11.5,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight),
      ),
    );
  }

  Widget _buildLedgerHeader(PortalContractDetail detail, bool isDark) {
    return Row(
      children: [
        Text(PortalStrings.t('payments_header'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 6),
        Text('(${detail.paymentsList.length})',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
      ],
    );
  }

  Widget _buildLedger(PortalContractDetail detail, bool isDark) {
    final newestFirst = detail.paymentsList.reversed.toList();
    final hasMore = newestFirst.length > _visibleCount;
    final visible = (_showAllPayments || !hasMore)
        ? newestFirst
        : newestFirst.take(_visibleCount).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _paymentRow(visible[i], isDark),
          ],
          if (hasMore && !_showAllPayments)
            InkWell(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              onTap: () => setState(() => _showAllPayments = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    PortalStrings.t('show_all_payments',
                        {'0': '${newestFirst.length - _visibleCount}'}),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentRow(PortalPayment payment, bool isDark) {
    final bal = payment.runningBalance.round();
    final behind = bal > 0;
    final even = bal == 0;
    final pillColor = even
        ? (isDark ? AppColors.darkTextLight : AppColors.textLight)
        : (behind ? AppColors.error : AppColors.success);
    final pillText = even
        ? '0'
        : (behind
            ? Formatters.formatCurrency(bal.toDouble())
            : '+${Formatters.formatCurrency(bal.abs().toDouble())}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.date,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(
                    payment.description.isEmpty
                        ? PortalStrings.t('malipo')
                        : payment.description,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('TSH ${Formatters.formatCurrency(payment.amount)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor.withOpacity(isDark ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(pillText,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pillColor)),
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  final String label;
  final double value;
  final Color color;
  final String sub;
  const _StatCardData(this.label, this.value, this.color, this.sub);
}
