import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/report.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/glassmorphic_card.dart';
import 'report_view_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
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
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
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
    required bool isDark,
  }) {
    return GlassmorphicCard(
      isDark: isDark,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportViewScreen(reportType: reportType),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getReportIcon(reportType),
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reportType.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
