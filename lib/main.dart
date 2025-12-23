import 'package:flutter/material.dart';
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
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/client_selector_screen.dart';
import 'services/api_service.dart';
import 'config/clients_config.dart';
import 'utils/constants.dart';

void main() {
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            error: AppColors.error,
            background: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: AppColors.primary,
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
            primary: AppColors.primary,
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => isAuthenticated
                ? const MainNavigation()
                : const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Point of Sale System',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
