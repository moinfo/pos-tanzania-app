import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/location_provider.dart';
import '../providers/update_provider.dart';
import '../providers/offline_provider.dart';
import '../services/biometric_service.dart';
import '../services/api_service.dart';
import '../config/clients_config.dart';
import '../utils/constants.dart';
import '../widgets/glassmorphic_card.dart';
import 'client_selector_screen.dart';
import 'app_update_screen.dart';
import 'pending_uploads_screen.dart';

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
  String _currentClientName = '';

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
    _loadCurrentClient();
    // Cheap and idempotent -- the provider returns immediately if the main
    // navigation's check already loaded it. Without it, opening Settings
    // inside the first few seconds of a session shows "Unknown".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UpdateProvider>().loadInstalledVersion();
    });
  }

  Future<void> _loadCurrentClient() async {
    final client = await ApiService.getCurrentClient();
    setState(() {
      _currentClientName = client.displayName;
    });
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

  /// The one-line state of the upload queue.
  ///
  /// A refusal is named first and on its own, never added into a total with
  /// records that are merely waiting: those two need opposite responses, and
  /// "4 waiting" over three fine records and one dead one is how the dead one
  /// gets missed.
  static String _offlineSummary(int waiting, int rejected) {
    if (rejected > 0) {
      final refused = rejected == 1
          ? '1 record was refused and needs you'
          : '$rejected records were refused and need you';
      return waiting > 0 ? '$refused - $waiting also waiting' : refused;
    }
    if (waiting > 0) {
      return waiting == 1
          ? '1 record waiting - it uploads by itself'
          : '$waiting records waiting - they upload by themselves';
    }
    return 'Everything on this phone is on the server';
  }

  /// Build settings avatar with profile picture (Leruma feature) or default icon
  Widget _buildSettingsAvatar(dynamic user, bool isDark) {
    final hasCommissionDashboard = ApiService.currentClient?.features.hasCommissionDashboard ?? false;
    final profilePicture = user?.profilePicture;

    // Show profile picture only for Leruma (hasCommissionDashboard) and if picture exists
    if (hasCommissionDashboard && profilePicture != null && profilePicture.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkCard : AppColors.lightBackground,
        ),
        child: ClipOval(
          child: Image.network(
            profilePicture,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // Skeleton placeholder while loading
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.3),
                ),
                child: Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey.withOpacity(0.5),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                color: AppColors.primary,
                size: 28,
              );
            },
          ),
        ),
      );
    }

    // Default avatar with icon
    return Icon(
      Icons.person,
      color: isDark ? AppColors.primary : AppColors.primary,
      size: 28,
    );
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

          // Client Configuration Section
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'CLIENT CONFIGURATION',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Only show client switcher in DEBUG mode
          if (ClientsConfig.isClientSwitchingEnabled)
            GlassmorphicCard(
              isDark: isDark,
              child: Column(
                children: [
                  // Change Client Button
                  ListTile(
                    leading: Icon(
                      Icons.store,
                      color: isDark ? AppColors.primary : AppColors.primary,
                      size: 28,
                    ),
                    title: Text(
                      'Switch Client',
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Current: $_currentClientName',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      size: 16,
                    ),
                    onTap: () async {
                      print('🔄 Switch Client button pressed');

                      // Clear the current client completely
                      await ApiService.clearCurrentClient();

                      // Logout
                      await authProvider.logout();

                      if (mounted) {
                        // Navigate to client selector and remove all previous routes
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const ClientSelectorScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

          // Location Section (Leruma only - for users with multiple locations)
          if (ApiService.currentClient?.features.hasCommissionDashboard ?? false)
            Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                // Only show if user has multiple locations
                if (!locationProvider.hasMultipleLocations) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'LOCATION',
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
                          ListTile(
                            leading: Icon(
                              Icons.store,
                              color: isDark ? AppColors.primary : AppColors.primary,
                              size: 28,
                            ),
                            title: Text(
                              'Stock Location',
                              style: TextStyle(
                                color: isDark ? AppColors.darkText : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              locationProvider.selectedLocation?.locationName ?? 'Select location',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_drop_down,
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                            onTap: () {
                              _showLocationPicker(context, locationProvider, isDark);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

          // Offline Data Section
          //
          // The answer to "is anything stuck on this phone?", in the place a
          // person goes looking for it. Only shown for clients that actually
          // keep a local queue -- offering it where there is no offline mode
          // would promise a list that can never have anything in it.
          //
          // The row carries the rejected count as a badge rather than folding
          // it into one total: waiting records need nobody, refused ones need
          // somebody, and a single number would hide the difference.
          if (ApiService.currentClient?.features.hasOfflineMode ?? false) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'OFFLINE DATA',
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
              child: Consumer<OfflineProvider>(
                builder: (context, offline, _) {
                  final waiting =
                      offline.pendingSaleCount + offline.pendingActionCount;
                  final rejected = offline.rejectedCount;

                  return ListTile(
                    leading: Icon(
                      rejected > 0
                          ? Icons.report_problem
                          : Icons.cloud_upload_outlined,
                      color: rejected > 0 ? AppColors.error : AppColors.primary,
                      size: 28,
                    ),
                    title: Text(
                      'Not yet uploaded',
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _offlineSummary(waiting, rejected),
                      style: TextStyle(
                        color: rejected > 0
                            ? AppColors.error
                            : (isDark
                                ? AppColors.darkTextLight
                                : AppColors.textLight),
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rejected > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$rejected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight,
                          size: 16,
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PendingUploadsScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // App Update Section
          //
          // Sits in Settings as well as the drawer because this is the answer
          // to "I said Later, where did it go?". The row is honest in both
          // directions: when a newer build exists it says which one, and when
          // there is not it says so rather than offering a button that leads
          // nowhere.
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'APP UPDATE',
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
            child: Consumer<UpdateProvider>(
              builder: (context, updates, _) {
                final available = updates.updateAvailable;
                return ListTile(
                  leading: Icon(
                    available ? Icons.system_update : Icons.verified_outlined,
                    color: available ? AppColors.success : AppColors.primary,
                    size: 28,
                  ),
                  title: Text(
                    available ? 'Update Available' : 'App Version',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    available
                        ? 'Installed ${updates.installedLabel} • '
                            '${updates.latest?.versionName ?? ''} is in the store'
                        : 'Installed ${updates.installedLabel}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AppUpdateScreen()),
                    );
                  },
                );
              },
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
                    leading: _buildSettingsAvatar(authProvider.user, isDark),
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
                // Was hardcoded to 'Version 1.0.0' and had been since before
                // build 36, so the one place a user could look to report which
                // version they were on told everyone the same wrong thing.
                Consumer<UpdateProvider>(
                  builder: (context, updates, _) => Text(
                    'Version ${updates.installedLabel}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight,
                      fontSize: 12,
                    ),
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
                  'Moinfotech',
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

  /// Show location picker bottom sheet
  void _showLocationPicker(BuildContext context, LocationProvider locationProvider, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Location list
              ...locationProvider.allowedLocations.map((location) {
                final isSelected = location.locationId == locationProvider.selectedLocation?.locationId;
                return ListTile(
                  leading: Icon(
                    Icons.store,
                    color: isSelected ? AppColors.success : (isDark ? AppColors.darkTextLight : AppColors.textLight),
                  ),
                  title: Text(
                    location.locationName,
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.text,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : null,
                  onTap: () async {
                    await locationProvider.selectLocation(location);
                    if (mounted) {
                      Navigator.pop(context);
                      // Show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Location changed to ${location.locationName}'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
