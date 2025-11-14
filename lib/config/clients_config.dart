import '../models/client_config.dart';

class ClientsConfig {
  // Base URLs
  static const String localBaseUrl = 'http://192.168.0.100:8888/PointOfSalesTanzania/public/api';
  static const String prodBaseUrl = 'https://moinfotech.co.tz/api';

  // List of all available clients
  static final List<ClientConfig> availableClients = [
    ClientConfig(
      id: 'sada',
      name: 'dev-sada',
      displayName: 'SADA',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'bonge',
      name: 'dev-bonge',
      displayName: 'Bonge',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://bonge.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'come_and_save',
      name: 'dev-come_and_save',
      displayName: 'Come & Save',
      devApiUrl: 'http://192.168.0.100:8888/PointOfSalesTanzania-come_and_save/public/api',
      prodApiUrl: 'https://comeandsave.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'iddy',
      name: 'dev-iddy',
      displayName: 'Iddy',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://iddy.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'kassim',
      name: 'dev-kassim',
      displayName: 'Kassim',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://kassim.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'leruma',
      name: 'dev-leruma',
      displayName: 'Leruma',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://leruma.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'mazao',
      name: 'dev-mazao',
      displayName: 'Mazao',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://mazao.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'meriwa',
      name: 'dev-meriwa',
      displayName: 'Meriwa',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://meriwa.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'pingo',
      name: 'dev-pingo',
      displayName: 'Pingo',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://pingo.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'plmstore',
      name: 'dev-plmstore',
      displayName: 'PLM Store',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://plmstore.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'postz',
      name: 'dev-postz',
      displayName: 'POSTZ',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://postz.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'qatar',
      name: 'dev-qatar',
      displayName: 'Qatar',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://qatar.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'ruge',
      name: 'dev-ruge',
      displayName: 'Ruge',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://ruge.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'sanira',
      name: 'dev-sanira',
      displayName: 'Sanira',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://sanira.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'sgs',
      name: 'dev-sgs',
      displayName: 'SGS',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://sgs.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'shorasho',
      name: 'dev-shorasho',
      displayName: 'Shorasho',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://shorasho.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'shukuma',
      name: 'dev-shukuma',
      displayName: 'Shukuma',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://shukuma.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'trishbake',
      name: 'dev-trishbake',
      displayName: 'TrishBake',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://trishbake.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'whitestar',
      name: 'dev-whitestar',
      displayName: 'White Star',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://whitestar.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'zai',
      name: 'dev-zai',
      displayName: 'Zai',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://zai.moinfotech.co.tz/api',
    ),
    ClientConfig(
      id: 'zaifood',
      name: 'dev-zaifood',
      displayName: 'Zai Food',
      devApiUrl: '$localBaseUrl',
      prodApiUrl: 'https://zaifood.moinfotech.co.tz/api',
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

  // Get default client (SADA)
  static ClientConfig getDefaultClient() {
    return availableClients.first;
  }
}
