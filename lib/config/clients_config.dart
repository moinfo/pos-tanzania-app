import '../models/client_config.dart';

class ClientsConfig {
  // ============================================
  // BUILD CONFIGURATION
  // ============================================
  // Set this to the client ID you want to build for in PRODUCTION
  // Examples: 'sada', 'come_and_save', 'come_and_save', etc.
  // In DEBUG mode, this is ignored and user can select any client
  static const String PRODUCTION_CLIENT_ID = 'sada'; // Change this before building APK

  // ============================================
  // NETWORK CONFIGURATION
  // ============================================
  // ⚠️ CHANGE THIS IP ADDRESS when your network changes
  static const String LOCAL_IP_ADDRESS = '192.168.0.100'; // Your computer's local IP
//   static const String LOCAL_IP_ADDRESS = '172.16.245.29'; // Your computer's local IP
  static const String MAMP_PORT = '8888';

  // Base URLs (automatically constructed from IP address)
  static const String localBaseUrl = 'http://$LOCAL_IP_ADDRESS:$MAMP_PORT/PointOfSalesTanzania2/public/api';
  static const String prodBaseUrl = 'https://moinfotech.co.tz/api';

  // List of all available clients
  // NOTE: Only SADA and Come & Save are enabled. To add more clients, uncomment them below.
  static final List<ClientConfig> availableClients = [
    // ============================================
    // ACTIVE CLIENTS
    // ============================================
    ClientConfig(
      id: 'sada',
      name: 'dev-sada',
      displayName: 'SADA',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://moinfotech.co.tz/api',
      features: const ClientFeatures(
        // SADA has all features enabled (default)
        hasContracts: true,
      ),
    ),
    ClientConfig(
      id: 'come_and_save',
      name: 'dev-come_and_save',
      displayName: 'Come & Save',
      devApiUrl: 'http://$LOCAL_IP_ADDRESS:$MAMP_PORT/PointOfSalesTanzania-come_and_save/public/api',
      prodApiUrl: 'https://comeandsave.co.tz/api',
      features: const ClientFeatures(
        // Come & Save does NOT have contracts feature
        hasContracts: false,
      ),
    ),

    // ============================================
    // INACTIVE CLIENTS (Uncomment to enable)
    // ============================================
    // ClientConfig(
    //   id: 'bonge',
    //   name: 'dev-bonge',
    //   displayName: 'Bonge',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://bonge.moinfotech.co.tz/api',
    //   features: const ClientFeatures(
    //     // Bonge has all features enabled (default)
    //   ),
    // ),
    // ClientConfig(
    //   id: 'iddy',
    //   name: 'dev-iddy',
    //   displayName: 'Iddy',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://iddy.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'kassim',
    //   name: 'dev-kassim',
    //   displayName: 'Kassim',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://kassim.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'leruma',
    //   name: 'dev-leruma',
    //   displayName: 'Leruma',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://leruma.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'mazao',
    //   name: 'dev-mazao',
    //   displayName: 'Mazao',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://mazao.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'meriwa',
    //   name: 'dev-meriwa',
    //   displayName: 'Meriwa',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://meriwa.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'pingo',
    //   name: 'dev-pingo',
    //   displayName: 'Pingo',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://pingo.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'plmstore',
    //   name: 'dev-plmstore',
    //   displayName: 'PLM Store',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://plmstore.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'postz',
    //   name: 'dev-postz',
    //   displayName: 'POSTZ',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://postz.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'qatar',
    //   name: 'dev-qatar',
    //   displayName: 'Qatar',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://qatar.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'ruge',
    //   name: 'dev-ruge',
    //   displayName: 'Ruge',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://ruge.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'sanira',
    //   name: 'dev-sanira',
    //   displayName: 'Sanira',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://sanira.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'sgs',
    //   name: 'dev-sgs',
    //   displayName: 'SGS',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://sgs.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'shorasho',
    //   name: 'dev-shorasho',
    //   displayName: 'Shorasho',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://shorasho.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'shukuma',
    //   name: 'dev-shukuma',
    //   displayName: 'Shukuma',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://shukuma.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'trishbake',
    //   name: 'dev-trishbake',
    //   displayName: 'TrishBake',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://trishbake.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'whitestar',
    //   name: 'dev-whitestar',
    //   displayName: 'White Star',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://whitestar.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'zai',
    //   name: 'dev-zai',
    //   displayName: 'Zai',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://zai.moinfotech.co.tz/api',
    // ),
    // ClientConfig(
    //   id: 'zaifood',
    //   name: 'dev-zaifood',
    //   displayName: 'Zai Food',
    //   devApiUrl: '$localBaseUrl',
    //   prodApiUrl: 'https://zaifood.moinfotech.co.tz/api',
    // ),
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

  // Get default client
  // In RELEASE mode: Returns the client specified in PRODUCTION_CLIENT_ID
  // In DEBUG mode: Returns first client (but user can switch)
  static ClientConfig getDefaultClient() {
    return getClientById(PRODUCTION_CLIENT_ID) ?? availableClients.first;
  }

  // Check if client switching is allowed (only in debug mode)
  static bool get isClientSwitchingEnabled {
    return const bool.fromEnvironment('dart.vm.product') == false;
  }
}
