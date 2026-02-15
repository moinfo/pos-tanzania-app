import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/offline_indicator.dart';
import '../config/clients_config.dart';
import 'main_navigation.dart';
import 'client_selector_screen.dart';
import 'landing/landing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final BiometricService _biometricService = BiometricService();

  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String _biometricType = 'Biometric';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Initialize screen - check biometric availability and status
  Future<void> _initializeScreen() async {
    // Load current client to ensure API calls use correct URL
    await ApiService.getCurrentClient();
    await _checkBiometricAvailability();
    await _checkIfBiometricEnabled();
    await _loadAppVersion();
  }

  /// Load app version from package info
  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'Version ${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  /// Check if device supports biometric authentication
  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (isAvailable) {
      final types = await _biometricService.getAvailableBiometrics();
      setState(() {
        _isBiometricAvailable = true;
        _biometricType = _biometricService.getBiometricTypeName(types);
      });
    }
  }

  /// Check if user has biometric enabled
  Future<void> _checkIfBiometricEnabled() async {
    final isEnabled = await _biometricService.isBiometricEnabled();
    setState(() {
      _isBiometricEnabled = isEnabled;
    });
  }

  /// Handle password login
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // Offer biometric enrollment if available and not already enabled
      if (_isBiometricAvailable && !_isBiometricEnabled) {
        await _offerBiometricEnrollment();
      }

      // Initialize location provider after successful login
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.initialize();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Handle biometric login
  Future<void> _loginWithBiometric() async {
    try {
      // 1. Authenticate with biometric
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to login to POS Tanzania',
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 2. Get saved credentials
      final credentials = await _biometricService.getSavedCredentials();
      final username = credentials['username'];
      final password = credentials['password'];

      if (username == null || password == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No saved credentials found. Please login with password.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 3. Login with saved credentials
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(username, password);

      if (success && mounted) {
        // Initialize location provider after successful login
        final locationProvider = context.read<LocationProvider>();
        await locationProvider.initialize();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric login error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Offer biometric enrollment after successful password login
  Future<void> _offerBiometricEnrollment() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: Text(
          'Would you like to use $_biometricType for quick and secure login? '
          'Your credentials will be stored securely on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _biometricService.enableBiometric(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

        setState(() {
          _isBiometricEnabled = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_biometricType login enabled successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to enable biometric: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final client = ApiService.currentClient;
    final branding = client?.branding;
    final brandPrimary = branding != null ? Color(branding.primaryColor) : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : brandPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                // App Logo
                Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    client?.logoUrl ?? 'logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                Text(
                  branding?.appTitle ?? AppConstants.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  branding?.tagline ?? 'Making technology work for you',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? AppColors.darkTextLight : Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),

                // Login Form Card with Glassmorphism
                GlassmorphicCard(
                  isDark: isDark,
                  onColoredBackground: !isDark, // Use glass style on colored background in light mode
                  borderRadius: 20,
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                          const SizedBox(height: 24),

                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(
                              color: isDark ? AppColors.darkText : Colors.white,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                color: isDark ? AppColors.darkTextLight : Colors.white70,
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: isDark ? AppColors.darkTextLight : Colors.white70,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: isDark ? AppColors.darkText : Colors.white,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: isDark ? AppColors.darkTextLight : Colors.white70,
                              ),
                              prefixIcon: Icon(
                                Icons.lock,
                                color: isDark ? AppColors.darkTextLight : Colors.white70,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: isDark ? AppColors.darkTextLight : Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? brandPrimary
                                      : Colors.white,
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : brandPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: authProvider.isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: isDark
                                              ? Colors.white
                                              : brandPrimary,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              );
                            },
                          ),

                          // Biometric Login Button (if enabled)
                          if (_isBiometricAvailable && _isBiometricEnabled) ...[
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white38)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white38)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _loginWithBiometric,
                              icon: Icon(
                                _biometricType == 'Face ID'
                                    ? Icons.face
                                    : Icons.fingerprint,
                                size: 24,
                              ),
                              label: Text('Login with $_biometricType'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? AppColors.darkText : Colors.white,
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkText.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Browse Shop Button (only for clients with landing page enabled)
                if (ClientsConfig.getDefaultClient().features.hasLandingPage)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LandingScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.storefront,
                      color: isDark ? AppColors.darkText : Colors.white,
                    ),
                    label: Text(
                      'Browse Shop',
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppColors.darkText : Colors.white,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Change Client Button (only in debug mode)
                if (ClientsConfig.isClientSwitchingEnabled)
                  TextButton.icon(
                    onPressed: () async {
                      await ApiService.clearCurrentClient();
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const ClientSelectorScreen(),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.swap_horiz,
                      color: isDark ? AppColors.darkTextLight : Colors.white70,
                      size: 18,
                    ),
                    label: Text(
                      'Change Client (${ApiService.currentClient?.displayName ?? "Not Set"})',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Powered By Footer
                Column(
                  children: [
                    Text(
                      'Powered by',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Moinfotech',
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _appVersion,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextLight : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ),
            // Offline Indicator
            Positioned(
              top: 12,
              left: 12,
              child: OfflineIndicator(compact: true),
            ),
            // Theme Toggle Button
            Positioned(
              top: 8,
              right: 8,
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) => IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: themeProvider.isDarkMode ? AppColors.darkText : Colors.white,
                  ),
                  onPressed: () {
                    themeProvider.toggleTheme();
                  },
                  tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
