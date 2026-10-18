import '../models/client_config.dart';

class ClientsConfig {
  // ============================================
  // FLAVOR CONFIGURATION (Set at build time)
  // ============================================
  //   flutter build apk --flavor leruma --dart-define=FLAVOR=leruma --release
  //   flutter build ios --flavor leruma --dart-define=FLAVOR=leruma --release

  static const String _buildFlavor = String.fromEnvironment('FLAVOR', defaultValue: '');

  // Map flavor names to client IDs
  static const Map<String, String> _flavorToClientId = {
    'leruma': 'leruma',
  };

  // ============================================
  // LEGACY: MANUAL BUILD CONFIGURATION
  // ============================================
  // Only used if FLAVOR is not set (legacy builds)
  // Set this to the client ID you want to build for in PRODUCTION
  static const String PRODUCTION_CLIENT_ID = 'leruma';

  // ============================================
  // NETWORK CONFIGURATION
  // ============================================
  // Local Laravel server: php artisan serve --port=8085
  static const String LOCAL_HOST = 'localhost';
  static const String LOCAL_PORT = '8085';

  // Base URLs
  static const String localBaseUrl = 'http://$LOCAL_HOST:$LOCAL_PORT/api';
  static const String prodBaseUrl = 'https://leruma.co.tz/api';

  // ============================================
  // CLIENT DEFINITIONS
  // ============================================
  static final List<ClientConfig> availableClients = [
    // Leruma
    ClientConfig(
      id: 'leruma',
      name: 'dev-leruma',
      displayName: 'Leruma Distribution Center',
      devApiUrl: localBaseUrl,
      prodApiUrl: 'https://leruma.co.tz/api',
      logoUrl: 'assets/images/leruma-logo.png',
      branding: const ClientBranding(
        appTitle: 'Leruma Distribution Center',
        tagline: 'We always care customers rights',
      ),
      features: const ClientFeatures(
        hasProfitSubmit: false,
        hasCommissionDashboard: true,
        hasReceivingsSummary: true,
        hasSuppliersByLocation: true,
        hasSupervisorByLocation: true,
        hasReceivingCreditCardOnly: true,
        hasNfcCard: true,
        // Leruma's sellers work out of a distribution centre and off vans
        // where coverage comes and goes. With this off, a checkout with no
        // network simply failed and the sale was gone; with it on, the sale is
        // written to SQLite and uploaded by itself under the same request_id,
        // so it reaches the server exactly once.
        hasOfflineMode: true,
        // Off for Leruma: the drawer is the one place a seller looks when
        // they cannot find something, and entries nobody on this deployment
        // opens make the ones they do want harder to see.
        hasTRA: false,
        hasFinancialBanking: true,  // web /banking twin; Leruma uses it
        hasBanking: true,
        hasOutOfStockSelling: true, // Leruma sells on credit, stock checked server-side
        hasSaleSheetButton: true, // Suspended sheet button in sales top bar
        hasInlineCartPreview: true, // Compact cart preview above item grid
        hasSuspendRequiresPayment: true, // Must take a payment before parking a sale
      ),
    ),
  ];

  // Get client by ID
  static ClientConfig? getClientById(String id) {
    try {
      return availableClients.firstWhere((client) => client.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get client by name
  static ClientConfig? getClientByName(String name) {
    try {
      return availableClients.firstWhere((client) => client.name == name);
    } catch (e) {
      return null;
    }
  }

  // Get the current build flavor (empty string if not set)
  static String get buildFlavor => _buildFlavor;

  // Check if this is a flavored build
  static bool get isFlavoredBuild => _buildFlavor.isNotEmpty;

  // Get the client ID for the current flavor
  static String? get flavorClientId => _flavorToClientId[_buildFlavor];

  // Get default client
  // Priority:
  // 1. If FLAVOR is set (flavored build) → use that client
  // 2. Otherwise → use PRODUCTION_CLIENT_ID (legacy behavior)
  static ClientConfig getDefaultClient() {
    // If this is a flavored build, use the flavor's client
    if (isFlavoredBuild && flavorClientId != null) {
      final client = getClientById(flavorClientId!);
      if (client != null) return client;
    }

    // Fallback to manual configuration
    return getClientById(PRODUCTION_CLIENT_ID) ?? availableClients.first;
  }

  // Check if client switching is allowed
  // - In DEBUG mode: Always allowed (for testing)
  // - In RELEASE mode with flavor: NOT allowed (locked to flavor's client)
  // - In RELEASE mode without flavor: NOT allowed (locked to PRODUCTION_CLIENT_ID)
  static bool get isClientSwitchingEnabled {
    // Only allow switching in debug mode
    return const bool.fromEnvironment('dart.vm.product') == false;
  }

  // Get flavor display name for UI
  static String get flavorDisplayName {
    switch (_buildFlavor) {
      case 'leruma':
        return 'Leruma';
      default:
        return getDefaultClient().displayName;
    }
  }
}