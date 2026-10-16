import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/connectivity_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../providers/offline_provider.dart';
import '../config/clients_config.dart';
import '../models/client_config.dart';
import 'main_navigation.dart';
import 'client_selector_screen.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import '../l10n/lang.dart';
import '../widgets/tr_text.dart';
import 'landing/landing_screen.dart';
import '../widgets/language_switcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  /// Endless 0..1 loop behind the hero rings, the logo halo and bob, and the
  /// shine across the Login button.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  /// One-shot entrance: logo pops in, then the card rises.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

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
    _loop.dispose();
    _intro.dispose();
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
    // Captured before the await: it is needed after sign-in, and reading it
    // off `context` there would be a read across an async gap.
    final offlineProvider = context.read<OfflineProvider>();
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
      // 'sales' so the home dashboard reuses this fetch instead of
      // making a second /stock_locations/allowed call before painting; the
      // assigned location must be applied HERE for the same reason.
      await locationProvider.initialize(
        moduleId: 'sales',
        userLocationId: context.read<AuthProvider>().user?.locationId,
      );

      // The offline cache is only fillable once there is a token: the sync at
      // app start runs before sign-in and every request it makes is refused.
      // Filling it now is what gives a seller items and customers to work with
      // when they later lose the network. Not awaited -- it is a background
      // top-up, and the seller should not be held on the login screen for it.
      if (offlineProvider.isInitialized) {
        unawaited(offlineProvider.syncMasterData());
      }

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
    // Read before the first await: everything below this point sits after an
    // async gap, where reading providers off `context` is not safe.
    final offlineProvider = context.read<OfflineProvider>();

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
              content: Text(
                  'No saved credentials found. Please login with password.'),
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
        // 'sales' so the home dashboard reuses this fetch instead of
        // making a second /stock_locations/allowed call before painting; the
        // assigned location must be applied HERE for the same reason.
        await locationProvider.initialize(
          moduleId: 'sales',
          userLocationId: context.read<AuthProvider>().user?.locationId,
        );

        // The offline cache is only fillable once there is a token: the sync at
        // app start runs before sign-in and every request it makes is refused.
        // Filling it now is what gives a seller items and customers to work with
        // when they later lose the network. Not awaited -- it is a background
        // top-up, and the seller should not be held on the login screen for it.
        if (offlineProvider.isInitialized) {
          unawaited(offlineProvider.syncMasterData());
        }

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
    if (_bioPrompting)
      return; // guard double taps while the sensor is prompting
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

  // ---------------------------------------------------------------------------
  // Theme-aware surfaces.
  //
  // The dark-mode button already called ThemeProvider.toggleTheme, but every
  // colour on this screen was a hardcoded light literal, so the toggle changed
  // the app's theme and nothing here moved. These resolve each design colour
  // against the active theme, so the switch has a visible effect.
  // ---------------------------------------------------------------------------

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _dark ? AppColors.darkBackground : _pageBg;
  Color get _surface => _dark ? AppColors.darkCard : Colors.white;
  Color get _ink => _dark ? AppColors.darkText : _navy;
  Color get _inkMuted =>
      _dark ? AppColors.darkTextLight : const Color(0xFF5A6577);
  Color get _inkFaint =>
      _dark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFFA3ADBC);

  Color get _hairline =>
      _dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE4EAF2);

  /// Text-field fill (design #F6F8FC, white when focused).
  Color _fieldFill(bool focused) => _dark
      ? Colors.white.withValues(alpha: focused ? 0.10 : 0.05)
      : (focused ? Colors.white : const Color(0xFFF6F8FC));

  /// Pale brand tints wash out to a glow on black.
  Color _tint(Color fg, Color lightBg) =>
      _dark ? fg.withValues(alpha: 0.20) : lightBg;

  /// The gradient-hero sign-in is Saichi's alone; Kariakoo keeps its artwork
  /// layout and every other client the classic one.
  bool get _modern => ApiService.currentClient?.id == 'saichi';

  @override
  Widget build(BuildContext context) {
    final client = ApiService.currentClient;

    if (_kariakooLogin) return _buildBrandedLayout(client);
    if (_modern) return _buildModernLayout(client);
    return _buildClassicLayout(client);
  }

  /// Brand-gradient hero (drifting rings, floating logo) with the form as a
  /// card that overlaps its lower edge and rises into place.
  Widget _buildModernLayout(ClientConfig? client) {
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // The hero gives way to the keyboard instead of pushing the form off-screen.
    final heroHeight =
        topPad + (keyboardOpen ? 196.0 : math.min(size.height * 0.40, 330.0));
    const overlap = 38.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bg,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(
            children: [
              // Hero backdrop + logo block.
              SizedBox(
                width: double.infinity,
                height: heroHeight,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(40)),
                  child: CustomPaint(
                    painter: _HeroPainter(
                      animation: _loop,
                      brand: _brandBlue,
                      deep: _brandDeep,
                      dark: _dark,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                          top: topPad + 58, bottom: overlap + 6),
                      child: _buildHero(client, compact: keyboardOpen),
                    ),
                  ),
                ),
              ),
              // Form card, rising into place after the logo lands.
              Padding(
                padding: EdgeInsets.only(top: heroHeight - overlap),
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(
                        ((_intro.value - 0.25) / 0.75).clamp(0.0, 1.0));
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                          offset: Offset(0, 46 * (1 - t)), child: child),
                    );
                  },
                  child: Column(
                    children: [
                      _buildFormSheet(client, floating: true),
                      SizedBox(
                          height: (keyboardOpen ? 10.0 : 14.0) + systemBottom),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: topPad + 6,
                left: 0,
                right: 0,
                child: _buildTopBar(glass: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The sign-in every client except Kariakoo and Saichi keeps.
  Widget _buildClassicLayout(ClientConfig? client) {
    return Scaffold(
      backgroundColor: _bg,
      // The sheet is a sibling in the Column rather than stacked on top: as an
      // overlay it covered the hero, because Expanded centred the logo in the
      // FULL screen height instead of the space left above the sheet.
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: CustomPaint(painter: _OrbitPainter(dark: _dark)),
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
                      child: _buildClassicHero(client),
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

  Widget _buildClassicHero(ClientConfig? client) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (client?.id == 'kariakoo_shops')
            // Kariakoo Shops' own app icon (kariakoo_shops_logo/
            // kariakoo-icon-1024x1024.png), which carries its own background.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x24103863),
                      blurRadius: 36,
                      offset: Offset(0, 14)),
                  BoxShadow(
                      color: Color(0x0F103863),
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/kariakoo-logo.png',
                  width: 132,
                  height: 132,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                // Stays white in both themes: the Leruma mark is navy artwork and
                // vanishes without its own ground.
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x24103863),
                      blurRadius: 36,
                      offset: Offset(0, 14)),
                  BoxShadow(
                      color: Color(0x0F103863),
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              // Leruma has its own vector mark; every other client shows the logo
              // from its ClientConfig.
              child: client?.id == 'leruma' || client?.logoUrl == null
                  ? SvgPicture.asset('assets/images/leruma-logo.svg',
                      width: 138)
                  : Image.asset(
                      client!.logoUrl!,
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => SvgPicture.asset(
                          'assets/images/leruma-logo.svg',
                          width: 138),
                    ),
            ),
          const SizedBox(height: 12),
          Text(
            client?.branding.appTitle ?? AppConstants.appName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: _dark ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              client?.branding.tagline ?? "Always make customer's rights",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color:
                    _dark ? const Color(0xFF8FBEE6) : const Color(0xFF1668A6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({bool glass = false}) {
    // On the gradient hero the chips are frosted white; on a plain page they
    // keep the card colours.
    final chipFill = glass ? Colors.white.withValues(alpha: 0.18) : _surface;
    final chipLine = glass ? Colors.white.withValues(alpha: 0.38) : _hairline;
    final chipInk = glass ? Colors.white : _inkMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer<ConnectivityProvider>(
            builder: (context, connectivity, child) {
              final online = connectivity.isOnline;
              final dot =
                  online ? const Color(0xFF16A34A) : const Color(0xFFC4820E);
              return Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                decoration: BoxDecoration(
                  color: chipFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chipLine),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0F103863),
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: dot.withValues(alpha: 0.15),
                              spreadRadius: 3),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      online ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: chipInk,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LanguageChip(
                surface: chipFill,
                border: chipLine,
                ink: chipInk,
                accent: glass ? Colors.white : const Color(0xFF1668A6),
                activeInk: glass ? _brandBlue : Colors.white,
              ),
              const SizedBox(width: 8),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) => Material(
                  color: chipFill,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    highlightColor: chipLine,
                    onTap: themeProvider.toggleTheme,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: chipLine),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0F103863),
                              blurRadius: 8,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: Icon(
                        _dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18,
                        color: chipInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kariakoo Shops sign-in: the brand artwork fills the full width of the
  /// screen as a hero (status-bar chips float on it) and the form is a rounded
  /// card that overlaps the hero's lower edge.
  Widget _buildBrandedLayout(ClientConfig? client) {
    final width = MediaQuery.sizeOf(context).width;
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // The icon is square with generous margins; show its top part (bag, name,
    // tagline) at full width and let the green behind it carry the rest.
    final heroHeight = width * 0.90;
    const overlap = 30.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bg,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: heroHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF21A038), Color(0xFF0F7A1E)],
                  ),
                ),
                child: ClipRect(
                  // Zoomed a touch and nudged up so the artwork's own thin inner
                  // border and empty top margin fall off-screen.
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: width * 1.07,
                    maxWidth: width * 1.07,
                    minHeight: width * 1.07,
                    maxHeight: width * 1.07,
                    child: Transform.translate(
                      offset: Offset(0, -width * 0.075),
                      child: Image.asset(
                        'assets/images/kariakoo-logo.png',
                        width: width * 1.07,
                        height: width * 1.07,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: heroHeight - overlap),
                child: Column(
                  children: [
                    _buildFormSheet(client, floating: true),
                    SizedBox(
                        height: (keyboardOpen ? 10.0 : 14.0) + systemBottom),
                  ],
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The logo tile for this client, drawn at [size] square.
  Widget _logoArtwork(ClientConfig? client, double size) {
    if (client?.id == 'saichi') {
      return SvgPicture.asset('assets/images/scl_logo.svg',
          width: size, height: size, fit: BoxFit.cover);
    }
    // Other marks are artwork without a ground of their own: keep them on white.
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(size * 0.14),
      child: client?.id == 'leruma' || client?.logoUrl == null
          ? SvgPicture.asset('assets/images/leruma-logo.svg')
          : Image.asset(
              client!.logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  SvgPicture.asset('assets/images/leruma-logo.svg'),
            ),
    );
  }

  /// Logo with two rippling halos and a gentle float, popping in on entry.
  Widget _buildLogoBadge(ClientConfig? client, double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_loop, _intro]),
      builder: (context, _) {
        final t = _loop.value;
        final pop =
            Curves.elasticOut.transform(((_intro.value) / 0.7).clamp(0.0, 1.0));
        final fade =
            Curves.easeOut.transform((_intro.value / 0.35).clamp(0.0, 1.0));
        final bob = math.sin(t * 2 * math.pi) * 3.5;

        Widget ripple(double phase) {
          final r = (t + phase) % 1.0;
          final d = size * (1.05 + 0.85 * r);
          return Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.34 + 14 * r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42 * (1 - r)),
                width: 2,
              ),
            ),
          );
        }

        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, bob),
            child: Transform.scale(
              scale: 0.5 + 0.5 * pop,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ripple(0),
                    ripple(0.5),
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.27),
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 30,
                          ),
                          const BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(size * 0.27 - 3.5),
                        child: _logoArtwork(client, size - 7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Hero content on the gradient: the logo, the app name, the tagline.
  Widget _buildHero(ClientConfig? client, {bool compact = false}) {
    final title = client?.branding.appTitle ?? AppConstants.appName;
    final tagline = client?.branding.tagline ?? "Always make customer's rights";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoBadge(client, compact ? 62 : 104),
        SizedBox(height: compact ? 12 : 22),
        AnimatedBuilder(
          animation: _intro,
          builder: (context, child) {
            final t = Curves.easeOut
                .transform(((_intro.value - 0.25) / 0.55).clamp(0.0, 1.0));
            return Opacity(
              opacity: t,
              child: Transform.translate(
                  offset: Offset(0, 12 * (1 - t)), child: child),
            );
          },
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 21 : 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.1,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, 3)),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 9),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.38)),
                  ),
                  child: Text(
                    tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormSheet(ClientConfig? client, {bool floating = false}) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Container(
      width: double.infinity,
      margin:
          floating ? EdgeInsets.symmetric(horizontal: _modern ? 18 : 14) : null,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: floating
            ? BorderRadius.circular(_modern ? 34 : 30)
            : const BorderRadius.vertical(top: Radius.circular(32)),
        border: floating ? Border.all(color: _hairline) : null,
        boxShadow: floating
            ? (_modern
                ? [
                    BoxShadow(
                      color: _brandDeep.withValues(alpha: _dark ? 0.35 : 0.28),
                      blurRadius: 44,
                      spreadRadius: -4,
                      offset: const Offset(0, 22),
                    ),
                    const BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0x2E0A3D12),
                        blurRadius: 34,
                        offset: Offset(0, 14)),
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ])
            : const [
                BoxShadow(
                    color: Color(0x21103863),
                    blurRadius: 44,
                    offset: Offset(0, -16)),
              ],
      ),
      padding: EdgeInsets.fromLTRB(
          floating ? 20 : 18, floating ? 22 : 18, floating ? 20 : 18, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!floating)
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _hairline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          if (_modern)
            _buildModernHeader(client)
          else ...[
            // Title and client chip share the top line, with the sub-line full
            // width beneath. Putting the chip beside "Karibu tena" only -- not
            // beside the whole heading block -- leaves it enough room to show
            // "Leruma Distribution Center" without the 104px cap that used to
            // clip it to "Leruma Distri...".
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text('Karibu tena',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: _ink)),
                ),
                // Debug builds only. Each client ships its own flavor, so in a
                // release the switcher can only point somewhere the build cannot
                // talk to -- and a seller tapping it would land on another
                // company's login.
                if (kDebugMode) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: _tint(_brandBlue, const Color(0xFFEAF3FB)),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      highlightColor:
                          _tint(_brandBlue, const Color(0xFFDCEBF8)),
                      onTap: _openClientSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: _tint(_brandBlue, const Color(0xFFCFE3F4)),
                              width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded,
                                size: 13, color: _brandBlue),
                            const SizedBox(width: 5),
                            Text(
                              client?.displayName ?? 'Client',
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _brandBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Sign in to start selling',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _inkMuted)),
            ),
          ],
          const SizedBox(height: 16),
          _buildField(
            label: 'USERNAME',
            controller: _usernameController,
            fieldKey: 'user',
            hint: 'msembe',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 10),
          _buildField(
            label: 'PASSWORD',
            controller: _passwordController,
            fieldKey: 'pass',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: _tint(const Color(0xFFD14343),
                    _tint(const Color(0xFFD14343), const Color(0xFFFDECEC))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _tint(
                        const Color(0xFFD14343),
                        _tint(
                            const Color(0xFFD14343), const Color(0xFFF3C4C4)))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: Color(0xFFD14343)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_inlineError!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
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
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _rememberMe ? _brandBlue : _surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: _rememberMe ? _brandBlue : _hairline,
                            width: 1.5,
                          ),
                        ),
                        child: _rememberMe
                            ? const Icon(Icons.check,
                                size: 15, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Remember me',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _inkMuted)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {},
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text('Forgot?',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _brandBlue)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildLoginButton(loading),
              ),
              // Offered only when biometrics are enrolled AND the user has signed
              // in on this device before -- otherwise there are no stored
              // credentials for it to unlock.
              if (_isBiometricAvailable && _isBiometricEnabled) ...[
                const SizedBox(width: 10),
                Material(
                  color: _surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    highlightColor: _tint(_brandBlue, const Color(0xFFEAF3FB)),
                    onTap: loading ? null : _submitBiometric,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _tint(_brandBlue, const Color(0xFFCFE3F4)),
                            width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x291D7DC4),
                              blurRadius: 14,
                              offset: Offset(0, 4)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _brandBlue),
                ),
                const SizedBox(width: 8),
                Text('Touch the sensor to sign in',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _brandBlue)),
              ],
            ),
          ],
          if (client?.features.hasLandingPage == true)
            Padding(
              padding: EdgeInsets.zero,
              child: TextButton.icon(
                onPressed: _backToHome,
                icon:
                    Icon(Icons.arrow_back_rounded, size: 18, color: _brandBlue),
                label: Text(
                  'Back to home',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _brandBlue,
                  ),
                ),
              ),
            ),
          // The sheet is drawn to the very bottom of the screen, so the system
          // navigation buttons / gesture bar are cleared by padding inside it
          // (keeps the sheet's own colour behind them). Builder: read the inset
          // below the Scaffold, which drops it while the keyboard is open.
          // The footer is the first thing to go when the keyboard needs the room.
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            Builder(
              builder: (insetContext) => Container(
                margin: const EdgeInsets.only(top: 12),
                padding: EdgeInsets.only(
                  top: 14,
                  // Floating card: the page, not the card, clears the system bar.
                  bottom: floating
                      ? 18
                      : 22 + MediaQuery.paddingOf(insetContext).bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _hairline)),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _inkFaint),
                    children: [
                      TextSpan(text: 'Powered by '.tr),
                      TextSpan(
                        text: 'Moinfotech',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: _inkMuted),
                      ),
                      if (_appVersion.isNotEmpty)
                        TextSpan(text: '  ·  ${_appVersion.tr}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Card heading: a gradient badge, the greeting and the sub-line (and, in
  /// debug builds, the client switcher).
  Widget _buildModernHeader(ClientConfig? client) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brandBlue, _brandDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: 0.42),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(Icons.lock_open_rounded,
              color: Colors.white, size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Karibu tena',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1.1,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Sign in to start selling',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _inkMuted,
                ),
              ),
            ],
          ),
        ),
        // Debug builds only: each client ships its own flavor, so in a release
        // the switcher could only point somewhere the build cannot talk to.
        if (kDebugMode)
          Material(
            color: _tint(_brandBlue, const Color(0xFFEAF3FB)),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _openClientSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: _tint(_brandBlue, const Color(0xFFCFE3F4)),
                      width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 13, color: _brandBlue),
                    const SizedBox(width: 5),
                    Text(
                      client?.displayName ?? 'Client',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _brandBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The Login button. On the modern look a soft band of light sweeps across
  /// it every few seconds.
  Widget _buildLoginButton(bool loading) {
    if (!_modern) return _buildPlainLoginButton(loading);

    return AnimatedBuilder(
      animation: _loop,
      builder: (context, child) {
        // The sweep runs during the first third of each loop, then rests.
        final p = (_loop.value / 0.34).clamp(0.0, 1.0);
        final x = -0.35 + 1.7 * Curves.easeInOut.transform(p);
        final sweeping = !loading && _loop.value < 0.34;
        return GestureDetector(
          onTap: loading ? null : _submit,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: loading
                    ? [
                        _brandBlue.withValues(alpha: 0.7),
                        _brandDeep.withValues(alpha: 0.8)
                      ]
                    : [_brandBlue, _brandDeep],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _brandDeep.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 11),
                ),
              ],
            ),
            foregroundDecoration: sweeping
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: [
                        (x - 0.18).clamp(0.0, 1.0),
                        x.clamp(0.0, 1.0),
                        (x + 0.18).clamp(0.0, 1.0),
                      ],
                    ),
                  )
                : null,
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.6, color: Colors.white),
            ),
            const SizedBox(width: 11),
          ],
          Text(
            loading ? 'Signing in…' : 'Login',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: Colors.white,
            ),
          ),
          if (!loading) ...[
            const SizedBox(width: 9),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 17, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlainLoginButton(bool loading) {
    return GestureDetector(
      onTap: loading ? null : _submit,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: loading
                ? const [Color(0xFF4E93C8), Color(0xFF2A5C8F)]
                : [_brandBlue, _brandDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x47103863),
                blurRadius: 22,
                offset: Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              loading ? 'Signing in…' : 'Login',
              style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            if (!loading) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  /// Leave the sign-in form for the public landing page. Clears the stack so
  /// Back from the landing page exits the app instead of returning here.
  void _backToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
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
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _inkMuted)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: _modern ? 60 : 56,
          padding: EdgeInsets.symmetric(horizontal: _modern ? 10 : 14),
          decoration: BoxDecoration(
            color: _fieldFill(focused),
            borderRadius: BorderRadius.circular(_modern ? 20 : 16),
            border: Border.all(
              color: hasError
                  ? _tint(const Color(0xFFD14343),
                      _tint(const Color(0xFFD14343), const Color(0xFFF3C4C4)))
                  : focused
                      ? _brandBlue
                      : _hairline,
              width: 1.5,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                        color: _brandBlue.withValues(alpha: 0.13),
                        spreadRadius: 4)
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (_modern)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: focused
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_brandBlue, _brandDeep],
                          )
                        : null,
                    color: focused
                        ? null
                        : _brandBlue.withValues(alpha: _dark ? 0.2 : 0.10),
                  ),
                  child: Icon(icon,
                      size: 20, color: focused ? Colors.white : _brandBlue),
                )
              else
                Icon(icon, size: 18, color: _inkMuted),
              SizedBox(width: _modern ? 12 : 10),
              Expanded(
                child: Focus(
                  onFocusChange: (has) =>
                      setState(() => _focusedField = has ? fieldKey : null),
                  child: TextField(
                    controller: controller,
                    obscureText: obscure,
                    // Typing clears the inline error, per the spec
                    onChanged: (_) {
                      if (_inlineError != null)
                        setState(() => _inlineError = null);
                    },
                    onSubmitted: (_) => _submit(),
                    cursorColor: _brandBlue,
                    decoration: InputDecoration(
                      isDense: true,
                      // The wrapper above draws the field; the app theme's own
                      // focus outline and fill must not draw a second one.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: hint,
                      hintStyle: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: _inkFaint),
                    ),
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _ink),
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color:
                        _obscurePassword ? const Color(0xFF7A8699) : _brandBlue,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              else if (controller.text.isNotEmpty)
                InkWell(
                  onTap: () => setState(controller.clear),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _hairline,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.close, size: 12, color: _inkMuted),
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
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x330F172A), blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _hairline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Text('Change client',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 2),
          Text('Pick the business this device sells for',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _inkMuted)),
          const SizedBox(height: 14),
          ...clients.map((c) {
            final selected = c.id == current;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? _tint(
                        _brandBlue, _tint(_brandBlue, const Color(0xFFF1F5FB)))
                    : _fieldFill(false),
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
                      MaterialPageRoute(
                          builder: (_) => const ClientSelectorScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFD5E3F7)
                            : const Color(0xFFEEF1F5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _navy,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.displayName.isNotEmpty
                                ? c.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                Uri.tryParse(c.prodApiUrl)?.host ??
                                    c.prodApiUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7A8699)),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle, size: 18, color: _brandBlue),
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
// Kariakoo Shops signs in with its own green; every other client takes its brand
// colour from its ClientConfig; every other client keeps the standard blue.
bool get _kariakooLogin => ApiService.currentClient?.id == 'kariakoo_shops';
Color get _brandBlue {
  if (_kariakooLogin) return const Color(0xFF1B8C30);
  // Saichi signs in in its own brand colour; other clients keep the standard blue.
  if (ApiService.currentClient?.id == 'saichi') {
    final branding = ApiService.currentClient?.branding;
    if (branding != null) return Color(branding.primaryColor);
  }
  return const Color(0xFF1D7DC4);
}

Color get _brandDeep {
  if (_kariakooLogin) return const Color(0xFF0A6B1A);
  if (ApiService.currentClient?.id == 'saichi') {
    final hsl = HSLColor.fromColor(_brandBlue);
    return hsl.withLightness((hsl.lightness * 0.56).clamp(0.0, 1.0)).toColor();
  }
  return _navy;
}

const Color _navy = Color(0xFF103863);
const Color _pageBg = Color(0xFFF4F7FA);

/// Orbit motif: three rotated ellipse strokes derived from the logo's own rings,
/// faded out before they reach the form sheet.
class _OrbitPainter extends CustomPainter {
  /// The orbit rings are drawn in a pale blue that disappears on a dark page,
  /// so dark mode gets a lifted white instead.
  final bool dark;

  const _OrbitPainter({this.dark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFF16202B), AppColors.darkBackground]
            : const [Color(0xFFEAF2FA), _pageBg],
        stops: const [0.0, 0.78],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final cx = size.width / 2;
    const cy = 150.0;

    void ring(double rx, double ry, Color color, double width, double opacity,
        double deg) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(deg * 3.1415926535 / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          // The pale rings disappear against a dark page, so they lift to white
          // there instead of keeping a blue that reads as black-on-black.
          ..color = (dark ? Colors.white : color)
              .withValues(alpha: dark ? opacity * 0.55 : opacity),
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
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0x000D0D0D), AppColors.darkBackground]
              : const [Color(0x00F4F7FA), _pageBg],
          stops: const [0.0, 0.78],
        ).createShader(rect),
    );
  }

  @override
  // Must compare `dark`: returning a flat false left the light wash painted
  // behind the dark sheet after toggling, since the canvas was never redrawn.
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// Hero backdrop: brand gradient with slowly turning rings, soft discs and a
/// few drifting sparks, all driven by [animation].
class _HeroPainter extends CustomPainter {
  _HeroPainter({
    required this.animation,
    required this.brand,
    required this.deep,
    required this.dark,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color brand;
  final Color deep;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final top = dark ? Color.lerp(brand, Colors.black, 0.45)! : brand;
    final bottom = dark ? Color.lerp(deep, Colors.black, 0.5)! : deep;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(rect),
    );

    final t = animation.value;
    final c = Offset(size.width / 2, size.height * 0.42);

    // Soft glow behind the logo.
    canvas.drawCircle(
      c,
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.55)),
    );

    // Big translucent discs in the corners.
    canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.08),
        size.width * 0.34,
        Paint()..color = Colors.white.withValues(alpha: 0.07));
    canvas.drawCircle(
        Offset(size.width * 0.04, size.height * 0.78),
        size.width * 0.26,
        Paint()..color = Colors.white.withValues(alpha: 0.06));

    // Turning rings.
    void ring(double rx, double ry, double width, double alpha, double deg) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(deg * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.restore();
    }

    final spin = t * 360;
    ring(size.width * 0.50, size.height * 0.19, 22, 0.10, -18 + spin * 0.10);
    ring(size.width * 0.50, size.height * 0.19, 5, 0.22, -12 + spin * 0.10);
    ring(size.width * 0.38, size.height * 0.13, 1.4, 0.40, 24 - spin * 0.16);

    // Sparks drifting upward and twinkling.
    final sparks = <List<double>>[
      [0.12, 0.30, 0.0, 3.0],
      [0.86, 0.22, 0.33, 2.4],
      [0.22, 0.62, 0.66, 2.0],
      [0.78, 0.58, 0.15, 3.2],
      [0.50, 0.12, 0.5, 2.2],
      [0.92, 0.46, 0.8, 1.8],
    ];
    for (final sp in sparks) {
      final phase = (t + sp[2]) % 1.0;
      final twinkle = math.sin(phase * math.pi);
      canvas.drawCircle(
        Offset(size.width * sp[0], size.height * sp[1] - 16 * phase),
        sp[3] * (0.6 + 0.6 * twinkle),
        Paint()..color = Colors.white.withValues(alpha: 0.55 * twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.brand != brand || old.deep != deep || old.dark != dark;
}
