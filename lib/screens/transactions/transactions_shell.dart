import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import 'bank_basis_screen.dart';
import 'cash_basis_screen.dart';
import 'lipa_namba_transactions_screen.dart';
import 'wakala_dashboard_screen.dart';
import 'wakala_screen.dart';
import 'wakala_theme.dart';

/// Holds the Transactions/e-Wakala module's own bottom navigation, same
/// pattern as ProductionShell/LodgeShell/ContractsShell -- capped at the
/// five destinations used every day (Dashboard, Cash basis, Bank basis,
/// SIMs, Lipa Namba transactions). Deposits & Withdrawals, Customer
/// Balances, Wakala Expenses/Report, Commission, Capital, Lipa Namba
/// Tills/Fee tiers stay reachable from the drawer only -- the same
/// "cap at 5 + drawer for the rest" convention those shells use.
///
/// "Ledger chip" nav style from the mopos-design 3 handover: flat white
/// bar 80 high, a blue pill (52x30) behind the active icon instead of
/// Lodge's floating dark pill or Contracts' top indicator bar.
///
/// An IndexedStack keeps each tab alive -- Cash/Bank basis and the SIMs tab
/// hold fetched category + transaction lists, and rebuilding on every
/// switch would throw them away.
class TransactionsShell extends StatefulWidget {
  final int initialIndex;

  const TransactionsShell({super.key, this.initialIndex = 0});

  @override
  State<TransactionsShell> createState() => _TransactionsShellState();
}

class _TransactionsShellState extends State<TransactionsShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    final destinations = <_Destination>[
      const _Destination('Dashboard', Icons.dashboard_outlined, WakalaDashboardScreen()),
      if (permissions.hasPermission(PermissionIds.transactionsCashBasis))
        const _Destination('Cash basis', Icons.money_outlined, CashBasisScreen()),
      if (permissions.hasPermission(PermissionIds.transactionsBankBasis))
        const _Destination('Bank basis', Icons.account_balance_outlined, BankBasisScreen()),
      if (permissions.hasPermission(PermissionIds.transactionsWakala))
        const _Destination('SIMs', Icons.sim_card_outlined, WakalaScreen()),
      if (permissions.hasPermission(PermissionIds.lipaNamba))
        const _Destination('Lipa Namba', Icons.receipt_long_outlined, LipaNambaTransactionsScreen()),
    ];

    // A revoked grant can shrink the list while a later tab is selected.
    final index = _index.clamp(0, destinations.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
          ),
          child: Row(
            children: destinations.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(d.icon,
                            size: 22,
                            color: selected ? Colors.white : (isDark ? AppColors.darkTextLight : Colors.grey[600])),
                      ),
                      const SizedBox(height: 4),
                      Text(d.label,
                          style: WakalaTheme.body(
                              size: 12,
                              weight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppColors.primary : (isDark ? AppColors.darkTextLight : Colors.grey[600]))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final Widget screen;

  const _Destination(this.label, this.icon, this.screen);
}
