/// Feature flags for each client
class ClientFeatures {
  final bool hasContracts;
  final bool hasZReports;
  final bool hasCashSubmit;
  final bool hasBanking;
  final bool hasProfitSubmit;
  final bool hasExpenses;
  final bool hasCustomers;
  final bool hasSuppliers;
  final bool hasItems;
  final bool hasCredits;
  final bool hasSupplierCredits;
  final bool hasReceivings;
  final bool hasSales;
  final bool hasCommissionDashboard; // Leruma-specific commission tracking dashboard
  final bool hasItemsExtendedInfo; // Leruma-specific: variation, days since sale, mainstore quantity
  final bool hasReceivingsSummary; // Leruma-specific: receivings summary reports
  final bool hasSuppliersByLocation; // Leruma-specific: filter suppliers by stock location's supervisor
  final bool hasSupervisorByLocation; // Leruma-specific: filter supervisors by stock location (banking)
  final bool hasReceivingCreditCardOnly; // Leruma-specific: only allow Credit Card payment in receivings

  // NFC Card functionality
  final bool hasNfcCard; // Enable NFC card wallet features (balance, deposit, payment)

  // Offline mode configuration
  final bool hasOfflineMode; // Enable/disable offline functionality

  // Landing page / Public shop
  final bool hasLandingPage; // Enable public shop landing page (Come & Save only)

  // TRA (Tanzania Revenue Authority) module
  final bool hasTRA; // Enable TRA module for tax reporting (Leruma only)

  const ClientFeatures({
    this.hasContracts = true,
    this.hasZReports = true,
    this.hasCashSubmit = true,
    this.hasBanking = true,
    this.hasProfitSubmit = true,
    this.hasExpenses = true,
    this.hasCustomers = true,
    this.hasSuppliers = true,
    this.hasItems = true,
    this.hasCredits = true,
    this.hasSupplierCredits = true,
    this.hasReceivings = true,
    this.hasSales = true,
    this.hasCommissionDashboard = false, // Default: disabled (only Leruma uses this)
    this.hasItemsExtendedInfo = false, // Default: disabled (only Leruma uses this)
    this.hasReceivingsSummary = false, // Default: disabled (only Leruma uses this)
    this.hasSuppliersByLocation = false, // Default: disabled (only Leruma uses this)
    this.hasSupervisorByLocation = false, // Default: disabled (only Leruma uses this)
    this.hasReceivingCreditCardOnly = false, // Default: disabled (only Leruma uses this)
    this.hasNfcCard = false, // Default: disabled - enable per client
    this.hasOfflineMode = false, // Default: disabled - enable per client as needed
    this.hasLandingPage = false, // Default: disabled - only Come & Save uses this
    this.hasTRA = false, // Default: disabled - only Leruma uses this
  });
}

class ClientConfig {
  final String id;
  final String name;
  final String displayName;
  final String devApiUrl;
  final String prodApiUrl;
  final String? logoUrl;
  final bool isActive;
  final ClientFeatures features;

  ClientConfig({
    required this.id,
    required this.name,
    required this.displayName,
    required this.devApiUrl,
    required this.prodApiUrl,
    this.logoUrl,
    this.isActive = true,
    this.features = const ClientFeatures(), // Default: all features enabled
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'devApiUrl': devApiUrl,
      'prodApiUrl': prodApiUrl,
      'logoUrl': logoUrl,
      'isActive': isActive,
    };
  }

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      devApiUrl: json['devApiUrl'] as String,
      prodApiUrl: json['prodApiUrl'] as String,
      logoUrl: json['logoUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'ClientConfig(id: $id, name: $name, displayName: $displayName)';
  }
}
