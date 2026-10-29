import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import 'wakala_dashboard_section.dart';
import 'wakala_theme.dart';

/// Full-screen wrapper around WakalaDashboardSection for TransactionsShell's
/// Dashboard tab -- the section itself is plain content (no Scaffold/AppBar)
/// since it's also embedded at the top of TransactionsScreen's own menu.
class WakalaDashboardScreen extends StatelessWidget {
  const WakalaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: WakalaTheme.appBar(
        isDark: isDark,
        eyebrow: 'Today · ${DateFormat('d MMM yyyy').format(DateTime.now())}',
        title: 'Dashboard',
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: WakalaDashboardSection(),
        ),
      ),
    );
  }
}
