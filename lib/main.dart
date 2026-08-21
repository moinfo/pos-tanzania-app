import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/receiving_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/permission_provider.dart';
import 'providers/location_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/landing_provider.dart';
import 'providers/update_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/client_selector_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'services/api_service.dart';
import 'services/push_service.dart';
import 'config/clients_config.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

/// Lets a tapped push notification navigate without a widget's BuildContext.
///
/// A tap can arrive when the app was not running at all, so there is no mounted
/// screen whose context could be used — which is how every other navigation in
/// this app works. PushService pushes through this key instead.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Required before any plugin call, and Firebase is a plugin call.
  WidgetsFlutterBinding.ensureInitialized();

  // Only the leruma flavor ships a google-services.json, so this returns false
  // for the other four clients and for iOS. That is a supported state: push is
  // simply unavailable and the app runs on polling, exactly as it did before.
  final firebaseReady = await PushService.initializeFirebase();

  // Read the saved theme before the first frame. Loading it inside the
  // provider's constructor meant the app painted light, then flipped -- a
  // white flash on every launch for anyone using dark mode.
  await ThemeProvider.preload();

  runApp(MyApp(firebaseReady: firebaseReady));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseReady = false});

  /// Whether Firebase came up for this flavor. Threaded down to PushService.
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        // Created here, ahead of AuthProvider's proxy, so that proxy can wire
        // it in below -- AuthProvider resets it on logout the same way it
        // already resets LocationProvider, which is what a single
        // process-lifetime SaleProvider needs on a device shared between sellers.
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        // Polls the notification feed and the approval badge. Handed to
        // AuthProvider below so it starts on login and stops on logout -- on a
        // shared device it would otherwise keep polling under the previous
        // seller's token and show them someone else's unread count.
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider5<PermissionProvider, LocationProvider, ConnectivityProvider, SaleProvider, NotificationProvider, AuthProvider>(
          create: (context) => AuthProvider()
            ..setPermissionProvider(
              Provider.of<PermissionProvider>(context, listen: false),
            )
            ..setLocationProvider(
              Provider.of<LocationProvider>(context, listen: false),
            )
            ..setConnectivityProvider(
              Provider.of<ConnectivityProvider>(context, listen: false),
            )
            ..setSaleProvider(
              Provider.of<SaleProvider>(context, listen: false),
            )
            ..setNotificationProvider(
              Provider.of<NotificationProvider>(context, listen: false),
            ),
          update: (context, permissionProvider, locationProvider, connectivityProvider, saleProvider, notificationProvider, authProvider) {
            authProvider!.setPermissionProvider(permissionProvider);
            authProvider.setLocationProvider(locationProvider);
            authProvider.setConnectivityProvider(connectivityProvider);
            authProvider.setSaleProvider(saleProvider);
            authProvider.setNotificationProvider(notificationProvider);
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
        ChangeNotifierProvider(create: (_) => ReceivingProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LandingProvider()),
        // Holds the answer to "is there a newer version?" for the session.
        // Above MainNavigation rather than inside it so the drawer badge, the
        // settings row and the update screen all read one answer instead of
        // each running their own check.
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          navigatorKey: navigatorKey,
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
        home: PushBootstrap(firebaseReady: firebaseReady, child: const SplashScreen()),
        ),
      ),
    );
  }
}

/// Starts FCM once, as soon as there is a provider tree to feed it into.
///
/// This cannot happen in main(): PushService needs the NotificationProvider so
/// a push can be deduped against the poll, and that provider does not exist
/// until MultiProvider has built. Wrapping the home screen is the earliest
/// point where both are true.
///
/// It renders its child unchanged — it exists purely for the initState hook.
class PushBootstrap extends StatefulWidget {
  const PushBootstrap({
    super.key,
    required this.firebaseReady,
    required this.child,
  });

  final bool firebaseReady;
  final Widget child;

  @override
  State<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends State<PushBootstrap> {
  @override
  void initState() {
    super.initState();

    if (!widget.firebaseReady) return;

    // After the first frame, so navigatorKey.currentState is populated for a
    // notification tap that launched the app from cold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PushService.instance.start(
        notifications: context.read<NotificationProvider>(),
        navigatorKey: navigatorKey,
        firebaseReady: widget.firebaseReady,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAuth() async {
    // Branding pause, connectivity check and the session verification all run
    // TOGETHER: the old code slept a fixed second and then read
    // isAuthenticated while AuthProvider was still verifying the token in the
    // background, so a slow network bounced valid sessions to the login
    // screen -- and every cold start paid the full second regardless.
    final connectivityProvider = context.read<ConnectivityProvider>();
    final authProvider = context.read<AuthProvider>();
    try {
      await Future.wait([
        authProvider.ready,
        connectivityProvider.initialize(),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);
    } catch (e) {
      // Never strand the splash: whatever failed, fall through and route on
      // the state we have (worst case, the login screen).
      debugPrint('Splash init error: $e');
    }

    if (mounted) {

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

      // Settled: authProvider.ready completed above.
      final isAuthenticated = authProvider.isAuthenticated;

      // Initialize location provider if user is already authenticated.
      // 'sales' up front: the home dashboard needs the sales-module list
      // immediately, and the old default ('items') forced a second
      // /stock_locations/allowed round trip before Home could paint.
      if (isAuthenticated) {
        final locationProvider = context.read<LocationProvider>();
        // userLocationId here: this is the FIRST initialize of the session,
        // and the home screen's later call dedupes against it -- without the
        // assigned location applied now, it never would be.
        await locationProvider.initialize(
          moduleId: 'sales',
          userLocationId: authProvider.user?.locationId,
        );
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
