import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/receiving_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/permission_provider.dart';
import 'providers/location_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/landing_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/client_selector_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'services/api_service.dart';
import 'config/clients_config.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15 (targetSdk 35) enforces edge-to-edge by default, and how
  // reliably MediaQuery's bottom inset gets reported back to SafeArea in
  // that mode varies by device/OEM skin and nav-bar style (3-button vs
  // gesture). Setting this explicitly removes that per-device guesswork.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProxyProvider3<PermissionProvider, LocationProvider, ConnectivityProvider, AuthProvider>(
          create: (context) => AuthProvider()
            ..setPermissionProvider(
              Provider.of<PermissionProvider>(context, listen: false),
            )
            ..setLocationProvider(
              Provider.of<LocationProvider>(context, listen: false),
            )
            ..setConnectivityProvider(
              Provider.of<ConnectivityProvider>(context, listen: false),
            ),
          update: (context, permissionProvider, locationProvider, connectivityProvider, authProvider) {
            authProvider!.setPermissionProvider(permissionProvider);
            authProvider.setLocationProvider(locationProvider);
            authProvider.setConnectivityProvider(connectivityProvider);
            return authProvider;
          },
        ),
        ChangeNotifierProxyProvider<ConnectivityProvider, OfflineProvider>(
          create: (context) => OfflineProvider(
            connectivityProvider: Provider.of<ConnectivityProvider>(context, listen: false),
            apiService: ApiService(),
          ),
          update: (context, connectivityProvider, offlineProvider) => offlineProvider!,
        ),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        ChangeNotifierProvider(create: (_) => ReceivingProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LandingProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brandPrimary,
            primary: AppColors.brandPrimary,
            secondary: AppColors.secondary,
            error: AppColors.error,
            background: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.lightText),
            bodyMedium: TextStyle(color: AppColors.lightText),
            titleLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: AppColors.brandPrimary,
            secondary: AppColors.secondary,
            error: AppColors.error,
            background: AppColors.darkBackground,
            surface: AppColors.darkSurface,
          ),
          scaffoldBackgroundColor: AppColors.darkBackground,
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: AppColors.darkSurface,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            color: AppColors.darkCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.darkText),
            bodyMedium: TextStyle(color: AppColors.darkText),
            titleLarge: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold),
          ),
        ),
        // Some devices draw their own nav/gesture bar as an opaque layer on
        // top of app content under edge-to-edge, rather than shrinking the
        // app's usable area, so MediaQuery.padding.bottom can under-report
        // the real safe area. Enforcing a sane minimum here, once, means
        // every screen's SafeArea/MediaQuery-based bottom spacing is
        // protected app-wide instead of needing a fix per screen.
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          final mq = MediaQuery.of(context);
          final safeBottom = mq.padding.bottom > 48.0 ? mq.padding.bottom : 48.0;
          return MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: safeBottom),
              viewPadding: mq.viewPadding.copyWith(bottom: safeBottom),
            ),
            child: child,
          );
        },
        home: const SplashScreen(),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    // Flavor is a compile-time dart-define, so the client (and its logo) is
    // known synchronously here - no need to wait for the async client/auth
    // lookup in _checkAuth() just to show the right branding on first frame.
    final client = ClientsConfig.getDefaultClient();
    final logoUrl = client.logoUrl;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: (logoUrl == null || logoUrl.isEmpty)
                  ? Icon(
                      Icons.storefront,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    )
                  : Image.asset(
                      logoUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.storefront,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAuth() async {
    // Wait for initialization
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      // Initialize connectivity provider
      final connectivityProvider = context.read<ConnectivityProvider>();
      await connectivityProvider.initialize();

      // Check if client is selected
      final prefs = await SharedPreferences.getInstance();
      final selectedClientId = prefs.getString('selected_client_id');

      // If no client selected and client switching is enabled (DEBUG mode), show client selector
      if (selectedClientId == null && ClientsConfig.isClientSwitchingEnabled) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ClientSelectorScreen(),
          ),
        );
        return;
      }

      // In RELEASE mode or if client is already selected, initialize API service with client
      final client = await ApiService.getCurrentClient();

      // Initialize offline provider only if offline mode is enabled for this client
      if (client.features.hasOfflineMode) {
        final offlineProvider = context.read<OfflineProvider>();
        await offlineProvider.initialize(client.id);
        debugPrint('Offline mode enabled for ${client.displayName}');
      } else {
        debugPrint('Offline mode disabled for ${client.displayName}');
      }

      final authProvider = context.read<AuthProvider>();
      final isAuthenticated = authProvider.isAuthenticated;

      // Initialize location provider if user is already authenticated
      if (isAuthenticated) {
        final locationProvider = context.read<LocationProvider>();
        await locationProvider.initialize();
      }

      if (mounted) {
        // Check if client has landing page feature enabled
        if (client.features.hasLandingPage) {
          // Show landing page first, users can access admin from there
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const LandingWrapper(),
            ),
          );
        } else {
          // No landing page - go directly to login or main navigation
          if (isAuthenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      }
    }
  }
}

/// Wrapper that shows landing page with option to access admin login
class LandingWrapper extends StatelessWidget {
  const LandingWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const LandingScreen();
  }

  void _goToAdminLogin(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.isAuthenticated) {
      // Already logged in, go to main navigation
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      // Show login screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}
