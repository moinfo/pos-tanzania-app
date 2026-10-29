import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../models/transaction.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/glassmorphic_card.dart';
import 'bank_basis_screen.dart';
import 'cash_basis_screen.dart';
import 'customer_transactions_screen.dart';
import 'wakala_screen.dart';

/// "Where the money is" -- float+cash position today vs yesterday, plus
/// today's flows. Mirrors the web Dashboard tab (transactions/index,
/// views/transactions/transaction.php) 1:1, including the quick-add
/// buttons. Embedded at the top of TransactionsScreen rather than its own
/// route, since there's no dedicated Transactions shell/tab yet.
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
      return GlassmorphicCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(_errorMessage ?? 'Could not load the dashboard',
                  style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
              const SizedBox(height: 10),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final d = _dashboard!;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickActions(permissions),
        const SizedBox(height: 16),
        GlassmorphicCard(
          isDark: isDark,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Money on hand, ${Formatters.formatDate(d.date)}',
                              style: TextStyle(fontSize: 12.5, color: subColor)),
                          const SizedBox(height: 2),
                          Text(Formatters.formatCurrency(d.today.position),
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                    ),
                    _deltaChip(d.change.position, isDark),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 10,
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
                    Expanded(child: _legendItem(AppColors.primary, 'Float', d.today.float, 'Wakala lines and bank', textColor, subColor)),
                    Expanded(child: _legendItem(AppColors.warning, 'Cash', d.today.cash, 'Cash book', textColor, subColor)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                _flowTable(d, textColor, subColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(PermissionProvider permissions) {
    final actions = <Widget>[];
    if (permissions.hasPermission(PermissionIds.transactionsDepositAdd)) {
      actions.add(_actionChip('+ New deposit', AppColors.success, () => _push(const CustomerTransactionsScreen())));
    }
    if (permissions.hasPermission(PermissionIds.transactionsWithdrawAdd)) {
      actions.add(_actionChip('- New withdrawal', AppColors.error, () => _push(const CustomerTransactionsScreen())));
    }
    if (permissions.hasPermission(PermissionIds.transactionsCashBasisAdd)) {
      actions.add(_actionChip('Record cash', AppColors.primary, () => _push(const CashBasisScreen())));
    }
    if (permissions.hasPermission(PermissionIds.transactionsBankBasisAdd)) {
      actions.add(_actionChip('Record bank', AppColors.primary, () => _push(const BankBasisScreen())));
    }
    if (permissions.hasPermission(PermissionIds.transactionsWakalaAdd)) {
      actions.add(_actionChip('Record wakala float', AppColors.primary, () => _push(const WakalaScreen())));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }

  Widget _actionChip(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _deltaChip(double delta, bool isDark) {
    if (delta == 0) {
      return Text('Same as yesterday', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : AppColors.textLight));
    }
    final up = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (up ? AppColors.success : AppColors.error).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${up ? '+' : '-'}${Formatters.formatCurrency(delta.abs())} since yesterday',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: up ? AppColors.success : AppColors.error),
      ),
    );
  }

  Widget _legendItem(Color dot, String label, double amount, String caption, Color textColor, Color subColor) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Formatters.formatCurrency(amount), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(caption, style: TextStyle(fontSize: 11, color: subColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flowTable(WakalaDashboard d, Color textColor, Color subColor) {
    Widget headerCell(String text, {TextAlign align = TextAlign.left}) => Expanded(
          flex: align == TextAlign.left ? 2 : 1,
          child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
        );

    Widget row(String label, double today, double yesterday, double change, {bool goodUp = true, bool isTotal = false}) {
      final changeColor = change == 0
          ? subColor
          : ((change > 0) == goodUp ? AppColors.success : AppColors.error);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, color: textColor)),
            ),
            Expanded(
              flex: 1,
              child: Text(Formatters.formatCurrency(today),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, color: textColor)),
            ),
            Expanded(
              flex: 1,
              child: Text(Formatters.formatCurrency(yesterday),
                  textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: subColor)),
            ),
            Expanded(
              flex: 1,
              child: Text(
                change == 0 ? '-' : '${change > 0 ? '+' : '-'}${Formatters.formatCurrency(change.abs())}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: changeColor),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            headerCell('Movement'),
            headerCell('Today', align: TextAlign.right),
            headerCell('Yesterday', align: TextAlign.right),
            headerCell('Change', align: TextAlign.right),
          ],
        ),
        Divider(height: 14, color: subColor.withOpacity(0.3)),
        row('Deposited', d.today.deposited, d.yesterday.deposited, d.change.deposited),
        row('Withdrawn', d.today.withdrawn, d.yesterday.withdrawn, d.change.withdrawn, goodUp: false),
        row('Lipa Namba fees', d.today.lipaNambaFees, d.yesterday.lipaNambaFees, d.change.lipaNambaFees),
        row('Wakala expenses', d.today.wakalaExpenses, d.yesterday.wakalaExpenses, d.change.wakalaExpenses, goodUp: false),
        Divider(height: 14, color: subColor.withOpacity(0.3)),
        row('Net balance', d.today.netBalance, d.yesterday.netBalance, d.change.netBalance, isTotal: true),
      ],
    );
  }
}
