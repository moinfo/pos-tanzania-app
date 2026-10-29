import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../models/transaction.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'bank_basis_screen.dart';
import 'cash_basis_screen.dart';
import 'customer_transactions_screen.dart';
import 'wakala_screen.dart';
import 'wakala_theme.dart';

/// "Where the money is" -- float+cash position today vs yesterday, plus
/// today's flows. Mirrors the web Dashboard tab (transactions/index,
/// views/transactions/transaction.php) 1:1, including the quick-add
/// buttons. Embedded at the top of TransactionsScreen's own menu and as
/// TransactionsShell's Dashboard tab content.
class WakalaDashboardSection extends StatefulWidget {
  const WakalaDashboardSection({super.key});

  @override
  State<WakalaDashboardSection> createState() => _WakalaDashboardSectionState();
}

class _WakalaDashboardSectionState extends State<WakalaDashboardSection> {
  final ApiService _apiService = ApiService();
  WakalaDashboard? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getWakalaDashboard();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _dashboard = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null || _dashboard == null) {
      return WakalaPanel(
        child: Column(
          children: [
            Text(_errorMessage ?? 'Could not load the dashboard',
                style: WakalaTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final d = _dashboard!;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMoveButtons(permissions),
        const SizedBox(height: 10),
        _buildActionTiles(permissions),
        const SizedBox(height: 14),
        WakalaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Money on hand · ${Formatters.formatDate(d.date)}',
                  style: WakalaTheme.body(size: 12, weight: FontWeight.w500, color: subColor)),
              const SizedBox(height: 2),
              Text(Formatters.formatCurrency(d.today.position),
                  style: WakalaTheme.display(size: 38, weight: FontWeight.w700, letterSpacing: -0.5, color: textColor)),
              const SizedBox(height: 10),
              _deltaChip(d.change.position, isDark),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      if (d.floatPercent > 0)
                        Expanded(flex: (d.floatPercent * 10).round().clamp(1, 1000), child: Container(color: AppColors.primary)),
                      if (d.cashPercent > 0)
                        Expanded(flex: (d.cashPercent * 10).round().clamp(1, 1000), child: Container(color: AppColors.warning)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _legendItem(AppColors.primary, d.today.float, 'Wakala lines and bank', textColor, subColor)),
                  Expanded(child: _legendItem(AppColors.warning, d.today.cash, 'Cash book', textColor, subColor)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        WakalaPanel(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: _flowTable(d, textColor, subColor),
        ),
      ],
    );
  }

  Widget _buildMoveButtons(PermissionProvider permissions) {
    final canDeposit = permissions.hasPermission(PermissionIds.transactionsDepositAdd);
    final canWithdraw = permissions.hasPermission(PermissionIds.transactionsWithdrawAdd);
    if (!canDeposit && !canWithdraw) return const SizedBox.shrink();

    return Row(
      children: [
        if (canDeposit)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _push(const CustomerTransactionsScreen()),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('New deposit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF047857),
                side: const BorderSide(color: Color(0xFF047857)),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: WakalaTheme.body(size: 15, weight: FontWeight.w700),
              ),
            ),
          ),
        if (canDeposit && canWithdraw) const SizedBox(width: 10),
        if (canWithdraw)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _push(const CustomerTransactionsScreen()),
              icon: const Icon(Icons.remove, size: 20),
              label: const Text('New withdrawal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                side: const BorderSide(color: Color(0xFFB91C1C)),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: WakalaTheme.body(size: 15, weight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionTiles(PermissionProvider permissions) {
    final tiles = <Widget>[];
    if (permissions.hasPermission(PermissionIds.transactionsCashBasisAdd)) {
      tiles.add(_actionTile(Icons.payments_outlined, 'Record cash', () => _push(const CashBasisScreen())));
    }
    if (permissions.hasPermission(PermissionIds.transactionsBankBasisAdd)) {
      tiles.add(_actionTile(Icons.account_balance_outlined, 'Record bank', () => _push(const BankBasisScreen())));
    }
    if (permissions.hasPermission(PermissionIds.transactionsWakalaAdd)) {
      tiles.add(_actionTile(Icons.sim_card_outlined, 'Record wakala float', () => _push(const WakalaScreen())));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Row(children: tiles.map((t) => Expanded(child: t)).toList());
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkText : AppColors.text,
          side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          minimumSize: const Size.fromHeight(84),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WakalaIconTile(icon: icon, size: 36),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: WakalaTheme.body(size: 13, weight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.text)),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }

  Widget _deltaChip(double delta, bool isDark) {
    if (delta == 0) {
      return Text('Same as yesterday',
          style: WakalaTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : AppColors.textLight));
    }
    final up = delta > 0;
    final color = up ? const Color(0xFF047857) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: up ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '${up ? '+' : '-'}${Formatters.formatCurrency(delta.abs())} since yesterday',
            style: WakalaTheme.body(size: 12.5, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color dot, double amount, String caption, Color textColor, Color subColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Formatters.formatCurrency(amount),
                  style: WakalaTheme.display(size: 18, weight: FontWeight.w700, color: textColor)),
              Text(caption, style: WakalaTheme.body(size: 12, color: subColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flowTable(WakalaDashboard d, Color textColor, Color subColor) {
    Widget headerCell(String text, {TextAlign align = TextAlign.left}) => Expanded(
          flex: align == TextAlign.left ? 2 : 1,
          child: Text(text,
              textAlign: align,
              style: WakalaTheme.display(size: 12, weight: FontWeight.w700, letterSpacing: 0.9, color: subColor)),
        );

    Widget row(String label, double today, double yesterday, double change, {bool goodUp = true, bool isTotal = false}) {
      final changeColor = change == 0 ? subColor : ((change > 0) == goodUp ? const Color(0xFF047857) : const Color(0xFFB91C1C));
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: isTotal
            ? BoxDecoration(border: Border(top: BorderSide(color: subColor.withOpacity(0.25))))
            : null,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(label,
                  style: WakalaTheme.body(
                      size: 14, weight: isTotal ? FontWeight.w700 : FontWeight.w500, color: textColor)),
            ),
            Expanded(
              flex: 1,
              child: Text(Formatters.formatCurrency(today),
                  textAlign: TextAlign.right,
                  style: WakalaTheme.display(
                      size: 13.5, weight: isTotal ? FontWeight.w700 : FontWeight.w600, color: textColor)),
            ),
            Expanded(
              flex: 1,
              child: Text(Formatters.formatCurrency(yesterday),
                  textAlign: TextAlign.right, style: WakalaTheme.display(size: 13.5, weight: FontWeight.w400, color: subColor)),
            ),
            Expanded(
              flex: 1,
              child: Text(
                change == 0 ? '–' : '${change > 0 ? '+' : '-'}${Formatters.formatCurrency(change.abs())}',
                textAlign: TextAlign.right,
                style: WakalaTheme.display(size: 13.5, weight: FontWeight.w600, color: changeColor),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: subColor.withOpacity(0.25)))),
          child: Row(
            children: [
              headerCell('Movement'),
              headerCell('Today', align: TextAlign.right),
              headerCell('Yesterday', align: TextAlign.right),
              headerCell('Change', align: TextAlign.right),
            ],
          ),
        ),
        row('Deposited', d.today.deposited, d.yesterday.deposited, d.change.deposited),
        row('Withdrawn', d.today.withdrawn, d.yesterday.withdrawn, d.change.withdrawn, goodUp: false),
        row('Lipa Namba fees', d.today.lipaNambaFees, d.yesterday.lipaNambaFees, d.change.lipaNambaFees),
        row('Wakala expenses', d.today.wakalaExpenses, d.yesterday.wakalaExpenses, d.change.wakalaExpenses, goodUp: false),
        row('Net balance', d.today.netBalance, d.yesterday.netBalance, d.change.netBalance, isTotal: true),
      ],
    );
  }
}
