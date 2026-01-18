import '../models/client_config.dart';

class ClientsConfig {
  // ============================================
  // FLAVOR CONFIGURATION (Set at build time)
  // ============================================
  // The flavor is set automatically when building with:
  //   flutter build apk --flavor sada --dart-define=FLAVOR=sada
  //   flutter build apk --flavor comeAndSave --dart-define=FLAVOR=comeAndSave
  //   flutter build apk --flavor leruma --dart-define=FLAVOR=leruma
//    # SADA
//     flutter build apk --flavor sada --dart-define=FLAVOR=sada --release --android-skip-build-dependency-validation
//
//     # Come & Save
//     flutter build apk --flavor comeAndSave --dart-define=FLAVOR=comeAndSave --release --android-skip-build-dependency-validation
//
//     # Leruma
//     flutter build apk --flavor leruma --dart-define=FLAVOR=leruma --release --android-skip-build-dependency-validation

//  # Android APK
//   flutter build apk --flavor comeAndSave --dart-define=FLAVOR=comeAndSave --release
//
//   # Android App Bundle


//   # Android App Bundle
//   flutter build appbundle --flavor comeAndSave --dart-define=FLAVOR=comeAndSave --release
//
//   # iOS
//   flutter build ios --flavor comeAndSave --dart-define=FLAVOR=comeAndSave --release

  static const String _buildFlavor = String.fromEnvironment('FLAVOR', defaultValue: '');

  // Map flavor names to client IDs
  static const Map<String, String> _flavorToClientId = {
    'sada': 'sada',
    'comeAndSave': 'come_and_save',
    'leruma': 'leruma',
  };

  // ============================================
  // LEGACY: MANUAL BUILD CONFIGURATION
  // ============================================
  // Only used if FLAVOR is not set (legacy builds)
  // Set this to the client ID you want to build for in PRODUCTION
  static const String PRODUCTION_CLIENT_ID = 'come_and_save';

  // ============================================
  // NETWORK CONFIGURATION
  // ============================================
  // Local Laravel server: php artisan serve --port=8085
  static const String LOCAL_HOST = 'localhost';
  static const String LOCAL_PORT = '8085';

  // Base URLs
  static const String localBaseUrl = 'http://$LOCAL_HOST:$LOCAL_PORT/api';
  static const String prodBaseUrl = 'https://moinfotech.co.tz/api';

  // ============================================
  // CLIENT DEFINITIONS
  // ============================================
  static final List<ClientConfig> availableClients = [
    // SADA
    ClientConfig(
      id: 'sada',
      name: 'dev-sada',
      displayName: 'SADA',
      devApiUrl: localBaseUrl,
      prodApiUrl: 'https://moinfotech.co.tz/api',
      features: const ClientFeatures(
        hasContracts: true,
        hasOfflineMode: false,
      ),
    ),
    // Come & Save
    ClientConfig(
      id: 'come_and_save',
      name: 'dev-come_and_save',
      displayName: 'Come & Save',
      devApiUrl: localBaseUrl,
      prodApiUrl: 'https://comeandsave.co.tz/api',
      features: const ClientFeatures(
        hasContracts: false,
        hasNfcCard: true,
        hasOfflineMode: false,
        hasLandingPage: true, // Public shop landing page enabled
        hasLocationBasedPricing: true, // Different prices per stock location
        hasLandingStockDisplay: true, // Show stock and validate orders on landing page
      ),
    ),
    // Leruma
    ClientConfig(
      id: 'leruma',
      name: 'dev-leruma',
      displayName: 'Leruma',
      devApiUrl: localBaseUrl,
      prodApiUrl: 'https://leruma.co.tz/api',
      features: const ClientFeatures(
        hasContracts: false,
        hasProfitSubmit: false,
        hasCommissionDashboard: true,
        hasReceivingsSummary: true,
        hasSuppliersByLocation: true,
        hasSupervisorByLocation: true,
        hasReceivingCreditCardOnly: true,
        hasNfcCard: true,
        hasOfflineMode: false,
        hasTRA: true, // TRA tax reporting module enabled
        hasFinancialBanking: true, // Financial banking dashboard enabled
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
      case 'sada':
        return 'SADA';
      case 'comeAndSave':
        return 'Come & Save';
      case 'leruma':
        return 'Leruma';
      default:
        return getDefaultClient().displayName;
    }
  }
}