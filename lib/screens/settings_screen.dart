import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';
import '../utils/constants.dart';
import '../widgets/glassmorphic_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricService _biometricService = BiometricService();

  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
  }

  Future<void> _initializeBiometric() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (isAvailable) {
      final types = await _biometricService.getAvailableBiometrics();
      final isEnabled = await _biometricService.isBiometricEnabled();

      setState(() {
        _isBiometricAvailable = true;
        _isBiometricEnabled = isEnabled;
        _biometricType = _biometricService.getBiometricTypeName(types);
      });
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (!enable) {
      // Disable biometric - show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable Biometric Login?'),
          content: Text(
            'Are you sure you want to disable $_biometricType login? '
            'You will need to login with your password to re-enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disable'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await _biometricService.disableBiometric();
          setState(() {
            _isBiometricEnabled = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$_biometricType login disabled'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to disable biometric: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } else {
      // Cannot enable from settings - need password
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'To enable biometric login, please logout and login with your password',
            ),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: isDark ? AppColors.darkText : Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security Section
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'SECURITY',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GlassmorphicCard(
            isDark: isDark,
            child: Column(
              children: [
                // Biometric Login Toggle
                ListTile(
                  leading: Icon(
                    _biometricType == 'Face ID' ? Icons.face : Icons.fingerprint,
                    color: isDark ? AppColors.primary : AppColors.primary,
                    size: 28,
                  ),
                  title: Text(
                    '$_biometricType Login',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _isBiometricAvailable
                        ? (_isBiometricEnabled ? 'Enabled' : 'Disabled')
                        : 'Not available on this device',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      fontSize: 13,
                    ),
                  ),
                  trailing: _isBiometricAvailable
                      ? Switch(
                          value: _isBiometricEnabled,
                          onChanged: _toggleBiometric,
                          activeColor: AppColors.success,
                        )
                      : null,
                ),
              ],
            ),
          ),

          // Appearance Section
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'APPEARANCE',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GlassmorphicCard(
            isDark: isDark,
            child: Column(
              children: [
                // Dark Mode Toggle
                ListTile(
                  leading: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? AppColors.primary : AppColors.primary,
                    size: 28,
                  ),
                  title: Text(
                    'Dark Mode',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Dark theme enabled' : 'Light theme enabled',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeColor: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Account Section
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ACCOUNT',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GlassmorphicCard(
            isDark: isDark,
            child: Column(
              children: [
                // User Info
                if (authProvider.user != null)
                  ListTile(
                    leading: Icon(
                      Icons.person,
                      color: isDark ? AppColors.primary : AppColors.primary,
                      size: 28,
                    ),
                    title: Text(
                      authProvider.user!.firstName ?? 'User',
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      authProvider.user!.username ?? '',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Divider(height: 1),
                // Logout Button
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: 28,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && mounted) {
                      await authProvider.logout();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // App Info
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'POS Tanzania Mobile',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Moinfotech Company Limited',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
