import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../contracts_screen.dart';
import 'contract_dashboard_screen.dart';
import 'contract_services_screen.dart';
import 'contract_payment_requests_screen.dart';
import 'contract_inspections_screen.dart';
import 'contract_theme.dart';

/// Holds the Contracts module's own bottom navigation, same pattern as
/// ProductionShell/LodgeShell -- capped at the five destinations used
/// every day (Dashboard, Contracts, Requests, Inspections, Services, on
/// request). Payments and Messages stay reachable from the drawer only,
/// same "cap at 5 + drawer for the rest" convention LodgeShell uses --
/// see the 5 extra drawer entries added alongside "Contracts" in
/// main_navigation.dart.
///
/// An IndexedStack keeps each tab alive -- the Dashboard/Services tabs
/// hold fetched data, and rebuilding on every switch would throw it away.
class ContractsShell extends StatefulWidget {
  final int initialIndex;

  const ContractsShell({super.key, this.initialIndex = 0});

  @override
  State<ContractsShell> createState() => _ContractsShellState();
}

class _ContractsShellState extends State<ContractsShell> {
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
      const _Destination('Dashboard', Icons.dashboard_outlined, ContractDashboardScreen()),
      const _Destination('Contracts', Icons.assignment_outlined, ContractsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsPaymentsApprove))
        const _Destination('Requests', Icons.fact_check_outlined, ContractPaymentRequestsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsInspections))
        const _Destination('Inspections', Icons.search_outlined, ContractInspectionsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsServices))
        const _Destination('Services', Icons.build_outlined, ContractServicesScreen()),
    ];

    // A revoked grant can shrink the list while a later tab is selected.
    final index = _index.clamp(0, destinations.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: destinations.map((d) => d.screen).toList(),
      ),
      // Flat white bar (not Lodge's floating dark pill): 76 tall, a 1px top
      // border, and a 28x4 amber indicator bar above the active tab --
      // matches the "Road" mode handover exactly rather than the stock
      // Material BottomNavigationBar.
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 76,
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
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.warning : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Icon(d.icon,
                          size: 22,
                          color: selected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                      const SizedBox(height: 3),
                      Text(d.label,
                          style: ContractTheme.body(
                              size: 12,
                              weight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkTextLight : AppColors.lightTextLight))),
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
