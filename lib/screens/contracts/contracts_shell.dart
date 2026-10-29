import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../contracts_screen.dart';
import 'contract_payments_screen.dart';
import 'contract_services_screen.dart';
import 'contract_payment_requests_screen.dart';
import 'contract_inspections_screen.dart';
import 'contract_messages_screen.dart';

/// Holds the Contracts module's own bottom navigation, same pattern as
/// ProductionShell/LodgeShell -- every page the web's own tab bar lists
/// (Contracts/Payments/Services/Payment requests/Inspections/Messages,
/// see CONTRACTS_MODULE.md) gets a tab here instead of being reachable
/// only through the drawer, now that a contracts-only tenant lands
/// directly in this shell as their Home tab.
///
/// An IndexedStack keeps each tab alive -- the Payments tab holds a date
/// range, and rebuilding it on every switch would throw that away.
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
      const _Destination('Contracts', Icons.assignment_outlined, ContractsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsPayments))
        const _Destination('Payments', Icons.payments_outlined, ContractPaymentsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsServices))
        const _Destination('Services', Icons.build_outlined, ContractServicesScreen()),
      if (permissions.hasPermission(PermissionIds.contractsPaymentsApprove))
        const _Destination('Requests', Icons.fact_check_outlined, ContractPaymentRequestsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsInspections))
        const _Destination('Inspections', Icons.search_outlined, ContractInspectionsScreen()),
      if (permissions.hasPermission(PermissionIds.contractsMessages))
        const _Destination('Messages', Icons.sms_outlined, ContractMessagesScreen()),
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
        selectedFontSize: 10.5,
        unselectedFontSize: 10.5,
        items: destinations
            .map((d) => BottomNavigationBarItem(
                  icon: Icon(d.icon, size: 21),
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
