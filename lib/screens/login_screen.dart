import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/connectivity_provider.dart';
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
import '../models/client_config.dart';
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
    // The redesigned screen has no Form widget -- empty fields are checked in
    // _submit() so the message can render in the inline banner. Kept null-safe
    // rather than removed, in case a Form is reintroduced around the fields.
    if (_formKey.currentState?.validate() == false) return;

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

  // ===================================================================
  // Redesigned login UI (design_handoff_login)
  //
  // Light hero with the orbit motif behind a floating logo card, then a white
  // form sheet pinned to the bottom. Auth handlers above are unchanged.
  // ===================================================================

  bool _rememberMe = true;
  String? _inlineError;
  String? _focusedField;
  bool _bioPrompting = false;

  /// Empty-field validation lives here rather than in the Form validator so the
  /// message can render in the inline banner the design specifies.
  Future<void> _submit() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _inlineError = 'Enter both username and password');
      return;
    }
    setState(() => _inlineError = null);
    await _handleLogin();
  }

  Future<void> _submitBiometric() async {
    if (_bioPrompting) return; // guard double taps while the sensor is prompting
    setState(() => _bioPrompting = true);
    try {
      await _loginWithBiometric();
    } finally {
      if (mounted) setState(() => _bioPrompting = false);
    }
  }

  void _openClientSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80041A3D),
      builder: (_) => _buildClientSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = ApiService.currentClient;

    return Scaffold(
      backgroundColor: _pageBg,
      // The sheet is a sibling in the Column rather than stacked on top: as an
      // overlay it covered the hero, because Expanded centred the logo in the
      // FULL screen height instead of the space left above the sheet.
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 330,
            child: CustomPaint(painter: _OrbitPainter()),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height * 0.22,
                      ),
                      child: _buildHero(client),
                    ),
                  ),
                ),
                _buildFormSheet(client),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer<ConnectivityProvider>(
            builder: (context, connectivity, child) {
              final online = connectivity.isOnline;
              final dot = online ? const Color(0xFF16A34A) : const Color(0xFFC4820E);
              return Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE4EAF2)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F103863), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: dot.withValues(alpha: 0.15), spreadRadius: 3),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      online ? 'ONLINE' : 'OFFLINE',
                      style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800,
                        letterSpacing: 0.4, color: Color(0xFF5A6577),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) => Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                highlightColor: const Color(0xFFEEF2F7),
                onTap: themeProvider.toggleTheme,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4EAF2)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0F103863), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.dark_mode_outlined, size: 18, color: Color(0xFF5A6577)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ClientConfig? client) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x24103863), blurRadius: 36, offset: Offset(0, 14)),
                BoxShadow(color: Color(0x0F103863), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: SvgPicture.asset('assets/images/leruma-logo.svg', width: 158),
          ),
          const SizedBox(height: 16),
          Text(
            client?.branding.appTitle ?? AppConstants.appName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23, fontWeight: FontWeight.w800,
              letterSpacing: -0.5, height: 1.15, color: _navy,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              client?.branding.tagline ?? "Always make customer's rights",
              style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700,
                letterSpacing: 0.2, color: Color(0xFF1668A6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSheet(ClientConfig? client) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x21103863), blurRadius: 44, offset: Offset(0, -16)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE7ECF3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Karibu tena',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w800,
                            letterSpacing: -0.5, color: _navy)),
                    SizedBox(height: 2),
                    Text('Sign in to start selling',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: Color(0xFF8A94A6))),
                  ],
                ),
              ),
              Material(
                color: const Color(0xFFEAF3FB),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  highlightColor: const Color(0xFFDCEBF8),
                  onTap: _openClientSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFCFE3F4), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 13, color: _brandBlue),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 104),
                          child: Text(
                            client?.displayName ?? 'Client',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800, color: _brandBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'USERNAME', controller: _usernameController, fieldKey: 'user',
            hint: 'e.g. anzwari.m', icon: Icons.person_outline,
          ),
          const SizedBox(height: 10),
          _buildField(
            label: 'PASSWORD', controller: _passwordController, fieldKey: 'pass',
            hint: '••••••••', icon: Icons.lock_outline, obscure: _obscurePassword,
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3C4C4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Color(0xFFD14343)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_inlineError!,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700,
                            color: Color(0xFFC33B3B))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _rememberMe ? _brandBlue : Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: _rememberMe ? _brandBlue : const Color(0xFFD5DCE6),
                            width: 1.5,
                          ),
                        ),
                        child: _rememberMe
                            ? const Icon(Icons.check, size: 15, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text('Remember me',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: Color(0xFF475569))),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {},
                child: const SizedBox(
                  height: 44,
                  child: Center(
                    child: Text('Forgot?',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _brandBlue)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: loading ? null : _submit,
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: loading
                            ? const [Color(0xFF4E93C8), Color(0xFF2A5C8F)]
                            : const [_brandBlue, _navy],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x47103863), blurRadius: 22, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (loading) ...[
                          const SizedBox(
                            width: 19, height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          loading ? 'Signing in…' : 'Login',
                          style: const TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        if (!loading) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Offered only when biometrics are enrolled AND the user has signed
              // in on this device before -- otherwise there are no stored
              // credentials for it to unlock.
              if (_isBiometricAvailable && _isBiometricEnabled) ...[
                const SizedBox(width: 10),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    highlightColor: const Color(0xFFEAF3FB),
                    onTap: loading ? null : _submitBiometric,
                    child: Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCFE3F4), width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x291D7DC4), blurRadius: 14, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Icon(Icons.fingerprint,
                          size: 26, color: _bioPrompting ? _navy : _brandBlue),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_bioPrompting) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _brandBlue),
                ),
                SizedBox(width: 8),
                Text('Touch the sensor to sign in',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: _brandBlue)),
              ],
            ),
          ],
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.only(top: 18, bottom: 34),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F4F8))),
            ),
            child: Column(
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFA3ADBC)),
                    children: [
                      TextSpan(text: 'Powered by '),
                      TextSpan(
                        text: 'Moinfotech',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5A6577)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(_appVersion,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFC3CBD8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String fieldKey,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    final focused = _focusedField == fieldKey;
    final hasError = _inlineError != null;
    final isPassword = fieldKey == 'pass';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                letterSpacing: 1, color: Color(0xFF8A94A6))),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: focused ? Colors.white : const Color(0xFFF6F8FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFF3C4C4)
                  : focused
                      ? _brandBlue
                      : const Color(0xFFE6EBF2),
              width: 1.5,
            ),
            boxShadow: focused
                ? [BoxShadow(color: _brandBlue.withValues(alpha: 0.13), spreadRadius: 4)]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8A94A6)),
              const SizedBox(width: 10),
              Expanded(
                child: Focus(
                  onFocusChange: (has) =>
                      setState(() => _focusedField = has ? fieldKey : null),
                  child: TextField(
                    controller: controller,
                    obscureText: obscure,
                    // Typing clears the inline error, per the spec
                    onChanged: (_) {
                      if (_inlineError != null) setState(() => _inlineError = null);
                    },
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600, color: Color(0xFFA3ADBC)),
                    ),
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: _obscurePassword ? const Color(0xFF7A8699) : _brandBlue,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              else if (controller.text.isNotEmpty)
                InkWell(
                  onTap: () => setState(controller.clear),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7ECF3),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.close, size: 12, color: Color(0xFF5A6577)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientSheet() {
    final clients = ClientsConfig.availableClients;
    final current = ApiService.currentClient?.id;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x330F172A), blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Text('Change client',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 2),
          const Text('Pick the business this device sells for',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8A94A6))),
          const SizedBox(height: 14),
          ...clients.map((c) {
            final selected = c.id == current;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected ? const Color(0xFFF1F5FB) : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  highlightColor: const Color(0xFFE9F0FA),
                  onTap: () {
                    Navigator.pop(context);
                    // Reuse the existing switcher so the API host change and
                    // session clearing keep going through one code path.
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClientSelectorScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? const Color(0xFFD5E3F7) : const Color(0xFFEEF1F5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _navy, borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.displayName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                              Text(
                                Uri.tryParse(c.prodApiUrl)?.host ?? c.prodApiUrl,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: Color(0xFF7A8699)),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle, size: 18, color: _brandBlue),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Design tokens for this screen (design_handoff_login)
const Color _brandBlue = Color(0xFF1D7DC4);
const Color _navy = Color(0xFF103863);
const Color _pageBg = Color(0xFFF4F7FA);

/// Orbit motif: three rotated ellipse strokes derived from the logo's own rings,
/// faded out before they reach the form sheet.
class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFEAF2FA), _pageBg], stops: [0.0, 0.78],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final cx = size.width / 2;
    const cy = 150.0;

    void ring(double rx, double ry, Color color, double width, double opacity, double deg) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(deg * 3.1415926535 / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }

    ring(188, 78, _brandBlue, 30, 0.18, -18);
    ring(188, 78, _navy, 9, 0.16, -11);
    ring(142, 52, _brandBlue, 1.5, 0.35, -25);

    final rect = Rect.fromLTRB(0, 150, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x00F4F7FA), _pageBg], stops: [0.0, 0.78],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
