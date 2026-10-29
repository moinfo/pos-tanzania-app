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

/// Holds the Transactions/e-Wakala module's own bottom navigation, same
/// pattern as ProductionShell/LodgeShell/ContractsShell -- capped at the
/// five destinations used every day (Dashboard, Cash basis, Bank basis,
/// SIMs, Lipa Namba transactions). Deposits & Withdrawals, Customer
/// Balances, Wakala Expenses/Report, Commission, Capital, Lipa Namba
/// Tills/Fee tiers stay reachable from the drawer only -- the same
/// "cap at 5 + drawer for the rest" convention those shells use.
///
/// Deliberately plain Material styling, not a Lodge/Contracts-style visual
/// identity -- there is no design spec for Transactions mode, and the rest
/// of the module (11+ screens) already uses this plain look.
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? AppColors.darkTextLight : Colors.grey[600],
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        items: destinations
            .map((d) => BottomNavigationBarItem(
                  icon: Icon(d.icon, size: 22),
                  label: d.label,
                ))
            .toList(),
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
