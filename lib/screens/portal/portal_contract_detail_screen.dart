import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../models/portal_contract_detail.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

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

  @override
  Widget build(BuildContext context) {
    final title = widget.contract.contractDescription.isNotEmpty
        ? widget.contract.contractDescription
        : 'Contract #${widget.contract.id}';
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _detail == null
                    ? _buildError()
                    : _buildBody(_detail!),
      ),
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

  Widget _buildBody(PortalContractDetail detail) {
    final c = detail.contract;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (c.isTerminated) _buildTerminatedBanner(c),
        _buildStatGrid(detail),
        const SizedBox(height: 16),
        _buildDetailsCard(c),
        const SizedBox(height: 16),
        _buildProgress(c, detail),
        const SizedBox(height: 20),
        if (detail.undatedTotal > 0) _buildUndatedNote(detail.undatedTotal),
        _buildLedgerHeader(detail),
        const SizedBox(height: 8),
        if (detail.paymentsList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: Text('Hakuna malipo yaliyorekodiwa bado.',
                    style: TextStyle(color: AppColors.textLight))),
          )
        else
          _buildLedger(detail),
      ],
    );
  }

  Widget _buildTerminatedBanner(Contract c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mkataba huu umesitishwa'
              '${(c.terminationReason?.isNotEmpty ?? false) ? ': ${c.terminationReason}' : '.'}',
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
      _StatCardData('Gharama ya mkataba', c.contractCost,
          const Color(0xFF233A5C), 'Kiasi kilichotolewa'),
      _StatCardData(
          'Deni hadi sasa',
          detail.owedToDate,
          const Color(0xFF55677A),
          '${Formatters.formatCurrency(c.returnAmount)}/siku × ${c.days} siku'),
      _StatCardData('Jumla iliyolipwa', c.payments, AppColors.success,
          '${detail.paymentsList.length} malipo'),
      _StatCardData(
          'Deni lililochelewa',
          c.currentUnpaid,
          AppColors.error,
          c.currentUnpaid > 0
              ? 'Amechelewa siku ${c.daysUnpaid.toInt()}'
              : 'Hakuna linalochelewa'),
      _StatCardData('Salio la mkataba', c.balance > 0 ? c.balance : 0,
          const Color(0xFF2C7A68), c.balance <= 0 ? 'Imekamilika' : 'Inabaki'),
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

  Widget _buildDetailsCard(Contract c) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Kuanza', c.date),
      MapEntry('Kumalizika', c.endDate),
      MapEntry('Muda', '${c.contractTime} miezi'),
      MapEntry('Kiwango cha kila siku',
          'TSH ${Formatters.formatCurrency(c.returnAmount)}'),
      if (c.guarantor1.isNotEmpty)
        MapEntry('Mdhamini 1', '${c.guarantor1} · ${c.phoneGuarantor1}'),
      if (c.guarantor2.isNotEmpty)
        MapEntry('Mdhamini 2', '${c.guarantor2} · ${c.phoneGuarantor2}'),
      if ((c.assetPlateNumber ?? '').isNotEmpty)
        MapEntry('Namba ya Plate', c.assetPlateNumber!),
      if ((c.assetChassisNumber ?? '').isNotEmpty)
        MapEntry('Chassis', c.assetChassisNumber!),
      if ((c.assetInsuranceProvider ?? '').isNotEmpty)
        MapEntry('Bima', c.assetInsuranceProvider!),
      if ((c.assetInsuranceExpiry ?? '').isNotEmpty)
        MapEntry('Bima inaisha', c.assetInsuranceExpiry!),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MAELEZO YA MKATABA',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                  letterSpacing: .3)),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.key,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textLight)),
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

  Widget _buildProgress(Contract c, PortalContractDetail detail) {
    final pct = detail.progressPct.clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Maendeleo ya malipo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.date,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textLight)),
              Text('Leo ${Formatters.getTodayFormatted()}',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textLight)),
              Text(c.endDate,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUndatedNote(double undatedTotal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Jumla ya malipo inajumuisha TSH ${Formatters.formatCurrency(undatedTotal)} '
        'kutoka kwenye rekodi za zamani zisizo na tarehe kamili.',
        style: const TextStyle(fontSize: 11.5, color: AppColors.textLight),
      ),
    );
  }

  Widget _buildLedgerHeader(PortalContractDetail detail) {
    return Row(
      children: [
        const Text('Malipo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 6),
        Text('(${detail.paymentsList.length})',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
      ],
    );
  }

  Widget _buildLedger(PortalContractDetail detail) {
    final newestFirst = detail.paymentsList.reversed.toList();
    final hasMore = newestFirst.length > _visibleCount;
    final visible = (_showAllPayments || !hasMore)
        ? newestFirst
        : newestFirst.take(_visibleCount).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _paymentRow(visible[i]),
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
                    'Onyesha malipo yote (${newestFirst.length - _visibleCount} zaidi ya awali)',
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

  Widget _paymentRow(PortalPayment payment) {
    final bal = payment.runningBalance.round();
    final behind = bal > 0;
    final even = bal == 0;
    final pillColor = even
        ? AppColors.textLight
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
                        ? 'Malipo'
                        : payment.description,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
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
              color: pillColor.withOpacity(0.1),
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
