import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import '../../models/report.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/breathing_stat_card.dart';
import 'report_view_screen.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/app_bottom_navigation.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      // Opened from the side menu: the bottom bar shows this entry's icon in the
      // centre notch. Embedded as a tab (inside the shell's Scaffold), the shell draws the bar.
      bottomNavigationBar:
          Scaffold.maybeOf(context) == null ? const AppBottomNavigation(currentIndex: -1) : null,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Reports Section
              _buildSection(
                context: context,
                title: 'Summary Reports',
                color: AppColors.brandPrimary,
                icon: Icons.summarize,
                isDark: isDark,
                reports: [
                  _ReportItem(
                    type: ReportType.summarySales,
                    permission: PermissionIds.reportsSales,
                  ),
                  _ReportItem(
                    type: ReportType.summaryItems,
                    permission: PermissionIds.reportsItems,
                  ),
                  _ReportItem(
                    type: ReportType.summaryCategories,
                    permission: PermissionIds.reportsCategories,
                  ),
                  _ReportItem(
                    type: ReportType.summaryCustomers,
                    permission: PermissionIds.reportsCustomers,
                  ),
                  _ReportItem(
                    type: ReportType.summaryEmployees,
                    permission: PermissionIds.reportsEmployees,
                  ),
                  _ReportItem(
                    type: ReportType.summaryPayments,
                    permission: PermissionIds.reportsPayments,
                  ),
                  _ReportItem(
                    type: ReportType.summaryExpenses,
                    permission: PermissionIds.reports,
                  ),
                  _ReportItem(
                    type: ReportType.summaryDiscounts,
                    permission: PermissionIds.reportsDiscounts,
                  ),
                  _ReportItem(
                    type: ReportType.summaryTaxes,
                    permission: PermissionIds.reportsTaxes,
                  ),
                  _ReportItem(
                    type: ReportType.summarySuppliers,
                    permission: PermissionIds.reportsSuppliers,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Detailed Reports Section
              _buildSection(
                context: context,
                title: 'Detailed Reports',
                color: AppColors.success,
                icon: Icons.list_alt,
                isDark: isDark,
                reports: [
                  _ReportItem(
                    type: ReportType.detailedSales,
                    permission: PermissionIds.reportsSales,
                  ),
                  _ReportItem(
                    type: ReportType.detailedReceivings,
                    permission: PermissionIds.reportsReceivings,
                  ),
                  _ReportItem(
                    type: ReportType.detailedCustomers,
                    permission: PermissionIds.reportsCustomers,
                  ),
                  _ReportItem(
                    type: ReportType.detailedEmployees,
                    permission: PermissionIds.reportsEmployees,
                  ),
                  _ReportItem(
                    type: ReportType.detailedDiscounts,
                    permission: PermissionIds.reportsDiscounts,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Inventory Reports Section
              _buildSection(
                context: context,
                title: 'Inventory Reports',
                color: const Color(0xFFF59E0B),
                icon: Icons.inventory,
                isDark: isDark,
                reports: [
                  _ReportItem(
                    type: ReportType.inventorySummary,
                    permission: PermissionIds.reportsInventory,
                  ),
                  _ReportItem(
                    type: ReportType.inventoryLow,
                    permission: PermissionIds.reportsInventory,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Graphical Reports Section
              _buildSection(
                context: context,
                title: 'Graphical Reports',
                color: const Color(0xFF8B5CF6),
                icon: Icons.bar_chart,
                isDark: isDark,
                reports: [
                  _ReportItem(
                    type: ReportType.graphicalSales,
                    permission: PermissionIds.reportsSales,
                  ),
                  _ReportItem(
                    type: ReportType.graphicalItems,
                    permission: PermissionIds.reportsItems,
                  ),
                  _ReportItem(
                    type: ReportType.graphicalCategories,
                    permission: PermissionIds.reportsCategories,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required Color color,
    required IconData icon,
    required bool isDark,
    required List<_ReportItem> reports,
  }) {
    final permissionProvider = context.read<PermissionProvider>();

    // Filter reports based on permissions
    final availableReports = reports.where((report) {
      return permissionProvider.hasPermission(report.permission) ||
          permissionProvider.hasModulePermission(report.permission);
    }).toList();

    if (availableReports.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Report Cards Grid
        GridView.builder(
          shrinkWrap: true,
          clipBehavior: Clip.none, // let the glow and lift spill past the grid
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: availableReports.length,
          itemBuilder: (context, index) {
            final report = availableReports[index];
            return _buildReportCard(
              context: context,
              reportType: report.type,
              color: color,
              isDark: isDark,
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required ReportType reportType,
    required Color color,
    required bool isDark,
  }) {
    return BreathingSurface(
      color: color,
      isDark: isDark,
      phaseKey: reportType.displayName,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportViewScreen(reportType: reportType),
          ),
        );
      },
      builder: (context, t) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BreathingIconTile(
              icon: _getReportIcon(reportType),
              color: color,
              t: t,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(height: 10),
            Text(
              reportType.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getReportIcon(ReportType type) {
    switch (type.iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'category':
        return Icons.category;
      case 'people':
        return Icons.people;
      case 'badge':
        return Icons.badge;
      case 'payments':
        return Icons.payments;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'local_offer':
        return Icons.local_offer;
      case 'account_balance':
        return Icons.account_balance;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'move_to_inbox':
        return Icons.move_to_inbox;
      case 'inventory':
        return Icons.inventory;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.assessment;
    }
  }
}

class _ReportItem {
  final ReportType type;
  final String permission;

  _ReportItem({
    required this.type,
    required this.permission,
  });
}
