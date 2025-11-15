import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../models/permission_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../utils/constants.dart';
import 'customer_transactions_screen.dart';
import 'cash_basis_screen.dart';
import 'bank_basis_screen.dart';
import 'wakala_screen.dart';
import 'wakala_report_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Manage Transactions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer deposits, withdrawals, cash & bank basis, wakala',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                      ),
                ),
                const SizedBox(height: 24),

                // Customer Transactions Section
                if (permissionProvider.hasPermission(PermissionIds.transactionsDepositsAndWithdraws)) ...[
                  _buildSectionHeader(context, 'Customer Transactions', isDark),
                  const SizedBox(height: 12),
                  _buildTransactionCard(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Deposits & Withdrawals',
                    subtitle: 'Manage customer deposits and withdrawals',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerTransactionsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Cash & Bank Management Section
                if (permissionProvider.hasPermission(PermissionIds.transactionsCashBasis) ||
                    permissionProvider.hasPermission(PermissionIds.transactionsBankBasis)) ...[
                  _buildSectionHeader(context, 'Cash & Bank Management', isDark),
                  const SizedBox(height: 12),

                  // Cash Basis Card
                  if (permissionProvider.hasPermission(PermissionIds.transactionsCashBasis)) ...[
                    _buildTransactionCard(
                      context,
                      icon: Icons.money,
                      title: 'Cash Basis',
                      subtitle: 'Manage cash transactions and categories',
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CashBasisScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Bank Basis Card
                  if (permissionProvider.hasPermission(PermissionIds.transactionsBankBasis)) ...[
                    _buildTransactionCard(
                      context,
                      icon: Icons.account_balance,
                      title: 'Bank Basis',
                      subtitle: 'Manage bank/mobile money transactions',
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BankBasisScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 12),
                ],

                // Wakala Section
                if (permissionProvider.hasPermission(PermissionIds.transactionsWakala) ||
                    permissionProvider.hasPermission(PermissionIds.transactionsWakalaReport)) ...[
                  _buildSectionHeader(context, 'Wakala Management', isDark),
                  const SizedBox(height: 12),

                  // Wakala Transactions Card
                  if (permissionProvider.hasPermission(PermissionIds.transactionsWakala)) ...[
                    _buildTransactionCard(
                      context,
                      icon: Icons.sim_card,
                      title: 'Wakala Transactions',
                      subtitle: 'Manage SIM cards and wakala float',
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WakalaScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Wakala Report Card
                  if (permissionProvider.hasPermission(PermissionIds.transactionsWakalaReport)) ...[
                    _buildTransactionCard(
                      context,
                      icon: Icons.assessment,
                      title: 'Wakala Report',
                      subtitle: 'View comprehensive financial report',
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WakalaReportScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 1),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
          ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GlassmorphicCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
