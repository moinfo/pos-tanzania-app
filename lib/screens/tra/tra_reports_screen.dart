import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../models/tra.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';

class TRAReportsScreen extends StatefulWidget {
  final List<EFDDevice> efds;
  final int? defaultEfdId;

  const TRAReportsScreen({
    super.key,
    required this.efds,
    this.defaultEfdId,
  });

  @override
  State<TRAReportsScreen> createState() => _TRAReportsScreenState();
}

class _TRAReportsScreenState extends State<TRAReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final permissionProvider = context.watch<PermissionProvider>();

    final hasViewSalesReports = permissionProvider.hasPermission(PermissionIds.traViewSalesReports);
    final hasViewPurchasesReports = permissionProvider.hasPermission(PermissionIds.traViewPurchasesReports);
    final hasViewExpensesReports = permissionProvider.hasPermission(PermissionIds.traViewExpensesReports);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 16),

          // Sales Reports
          if (hasViewSalesReports)
            _buildReportCard(
              title: 'Sales Report',
              subtitle: 'Z-Reports summary and details',
              icon: Icons.receipt_long,
              color: Colors.blue,
              isDark: isDark,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sales Report - Coming soon')),
                );
              },
            ),

          if (hasViewSalesReports) const SizedBox(height: 12),

          // Purchases Reports
          if (hasViewPurchasesReports)
            _buildReportCard(
              title: 'Purchases Report',
              subtitle: 'Purchase transactions summary',
              icon: Icons.shopping_cart,
              color: Colors.green,
              isDark: isDark,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchases Report - Coming soon')),
                );
              },
            ),

          if (hasViewPurchasesReports) const SizedBox(height: 12),

          // Expenses Reports
          if (hasViewExpensesReports)
            _buildReportCard(
              title: 'Expenses Report',
              subtitle: 'Expense transactions summary',
              icon: Icons.money_off,
              color: Colors.red,
              isDark: isDark,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expenses Report - Coming soon')),
                );
              },
            ),

          if (hasViewExpensesReports) const SizedBox(height: 12),

          // VAT Summary Report
          _buildReportCard(
            title: 'VAT Summary',
            subtitle: 'Tax summary for TRA filing',
            icon: Icons.summarize,
            color: Colors.purple,
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('VAT Summary - Coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GlassmorphicCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? Colors.white54 : Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
