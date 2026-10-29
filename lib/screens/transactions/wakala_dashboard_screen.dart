import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import 'wakala_dashboard_section.dart';

/// Full-screen wrapper around WakalaDashboardSection for TransactionsShell's
/// Dashboard tab -- the section itself is plain content (no Scaffold/AppBar)
/// since it's also embedded at the top of TransactionsScreen's own menu.
class WakalaDashboardScreen extends StatelessWidget {
  const WakalaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)],
          ),
        ),
        child: const SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: WakalaDashboardSection(),
          ),
        ),
      ),
    );
  }
}
