import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../services/pdf_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';

/// Classic date/credit/debit/balance statement with opening/closing
/// balances -- defaults to the current month, matching the backend's own
/// default when no range is given. Shareable as a PDF (parity with web's
/// "Pakua PDF" window.print()).
///
/// "Credit" here is the daily amount accrued (debt going UP), "Debit" is a
/// payment (debt going DOWN) -- the opposite of typical bank-statement
/// coloring, so credit gets the amber "this adds to what you owe" tone and
/// debit gets green, not the other way around.
class PortalStatementScreen extends StatefulWidget {
  final Contract contract;

  /// True when shown as the portal shell's Taarifa tab, under the shared
  /// [PortalTopBar] -- suppresses this screen's own pinned SliverAppBar (the
  /// share action moves into the date-range bar instead) so the shared bar
  /// and this screen's bar don't stack. False (default) for the standalone,
  /// pushed route from the contract detail screen's menu.
  final bool embedded;

  const PortalStatementScreen(
      {super.key, required this.contract, this.embedded = false});

  @override
  State<PortalStatementScreen> createState() => _PortalStatementScreenState();
}

class _PortalStatementScreenState extends State<PortalStatementScreen> {
  static const _ink = Color(0xFF1B2C45);
  static const _inkDeep = Color(0xFF2C4165);
  static const _rust = Color(0xFFB5542A);
  static const _rustBg = Color(0xFFFBEEE7);
  static const _green = Color(0xFF1F8A5F);
  static const _greenBg = Color(0xFFE7F5EF);

  final _service = CustomerApiService();
  List<StatementEntry>? _statement;
  bool _isLoading = true;
  bool _isSharing = false;
  String? _error;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _tenantName;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _tenantName ??= await _service.getTenantName();
    final response = await _service.getContractStatement(
      widget.contract.id,
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _statement = response.data!.statement;
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _load();
    }
  }

  Future<void> _share() async {
    if (_statement == null || _statement!.isEmpty) return;
    setState(() => _isSharing = true);
    try {
      await PdfService.shareContractStatementPdf(
        contractName: widget.contract.name,
        contractDescription: widget.contract.contractDescription,
        statement: _statement!,
        startDate: Formatters.formatDateForApi(_startDate),
        endDate: Formatters.formatDateForApi(_endDate),
        companyName: _tenantName,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) {
        final contentSlivers = <Widget>[
          SliverToBoxAdapter(child: _buildRangeBar(showShare: widget.embedded)),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_statement == null || _statement!.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(PortalStrings.t('no_data_for_range'))),
            )
          else
            _buildLedgerSliver(_statement!),
        ];

        final scrollView = CustomScrollView(
          slivers: widget.embedded
              ? contentSlivers
              : [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 0,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    title: Text(PortalStrings.t('taarifa')),
                    actions: [
                      const PortalLanguageSwitch(),
                      IconButton(
                        icon: _isSharing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.ios_share),
                        tooltip: PortalStrings.t('share_pdf'),
                        onPressed: (_statement == null ||
                                _statement!.isEmpty ||
                                _isSharing)
                            ? null
                            : _share,
                      ),
                    ],
                  ),
                  ...contentSlivers,
                ],
        );

        if (widget.embedded) {
          return ColoredBox(
              color: AppColors.lightBackground, child: scrollView);
        }

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: scrollView,
        );
      },
    );
  }

  /// [showShare] adds a share icon after the range picker -- used only when
  /// [PortalStatementScreen.embedded] is true and this bar is the sole home
  /// for the share action (the standalone route keeps it in its AppBar
  /// instead).
  Widget _buildRangeBar({bool showShare = false}) {
    return Container(
      color: _ink,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickRange,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 15, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${Formatters.formatDate(Formatters.formatDateForApi(_startDate))}'
                        '  →  '
                        '${Formatters.formatDate(Formatters.formatDateForApi(_endDate))}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.expand_more,
                        size: 18, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
          if (showShare) ...[
            const SizedBox(width: 10),
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.ios_share, color: Colors.white),
              tooltip: PortalStrings.t('share_pdf'),
              onPressed:
                  (_statement == null || _statement!.isEmpty || _isSharing)
                      ? null
                      : _share,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSliver(List<StatementEntry> statement) {
    // Opening/closing bookend the ledger; everything between them is a
    // dated accrual/payment row rendered as a single continuous document
    // (hairline-divided rows) rather than separately-shadowed cards.
    final opening = statement.firstWhere((e) => e.type == 'opening',
        orElse: () => statement.first);
    final closing = statement.lastWhere((e) => e.type == 'closing',
        orElse: () => statement.last);
    final rows = statement
        .where((e) => e.type != 'opening' && e.type != 'closing')
        .toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildBookend(
            label: PortalStrings.t('opening_balance'),
            date: opening.date,
            balance: opening.balance,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Colors.grey.shade200),
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
                  _buildRow(rows[i]),
                ],
              ],
            ),
          ),
          _buildBookend(
            label: PortalStrings.t('closing_balance'),
            date: closing.date,
            balance: closing.balance,
            isClosing: true,
          ),
        ]),
      ),
    );
  }

  Widget _buildBookend({
    required String label,
    required String date,
    required double balance,
    bool isClosing = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, _inkDeep],
        ),
        borderRadius: BorderRadius.vertical(
          top: isClosing ? Radius.zero : const Radius.circular(10),
          bottom: isClosing ? const Radius.circular(10) : Radius.zero,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              Text(date,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Text(
            'TSH ${Formatters.formatCurrency(balance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(StatementEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              _shortDate(entry.date),
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textLight),
            ),
          ),
          Expanded(
            child: entry.credit > 0
                ? _amountPill(
                    'TSH ${Formatters.formatCurrency(entry.credit)}',
                    _rust,
                    _rustBg,
                  )
                : entry.debit > 0
                    ? _amountPill(
                        'TSH ${Formatters.formatCurrency(entry.debit)}',
                        _green,
                        _greenBg,
                      )
                    : const SizedBox.shrink(),
          ),
          SizedBox(
            width: 92,
            child: Text(
              Formatters.formatCurrency(entry.balance),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountPill(String text, Color fg, Color bg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  String _shortDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return isoDate;
    }
  }
}
