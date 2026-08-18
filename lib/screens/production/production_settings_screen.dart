import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/production_messages.dart';

/// Read-only view of the tenant's production configuration.
///
/// Editing is intentionally left on the web: settings/save updates the whole
/// row and a partial write from a phone form is how NOT NULL columns get
/// nulled out -- the very bug the endpoint's own comment describes.
class ProductionSettingsScreen extends StatefulWidget {
  const ProductionSettingsScreen({super.key});

  @override
  State<ProductionSettingsScreen> createState() => _ProductionSettingsScreenState();
}

class _ProductionSettingsScreenState extends State<ProductionSettingsScreen> {
  final ApiService _apiService = ApiService();
  ProductionSettings? _settings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await _apiService.getProductionSettings();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _settings = response.data;
      } else {
        _errorMessage = productionErrorMessage(response.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final s = _settings;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Production Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                )
              : s == null
                  ? const Center(child: Text('Not configured'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _row('Production location', '#${s.productionLocationId}', isDark),
                        _row(
                            'Curing location',
                            s.curingLocationId == null
                                ? 'None - straight to sales'
                                : '#${s.curingLocationId}',
                            isDark),
                        _row('Default curing days', '${s.defaultCuringDays}', isDark),
                        _row(
                            'Raw valuation',
                            s.rawValuation == 'AVG'
                                ? 'Purchase average'
                                : 'Static cost price',
                            isDark),
                        _row('Efficiency tolerance', '${s.tolerancePct}%', isDark),
                        _row('Block on short stock',
                            s.blockOnShortStock ? 'Yes' : 'No', isDark),
                        _row('Reserve raw stock for sale',
                            s.reserveForSale ? 'Yes' : 'No', isDark),
                        _row('Auto-release cured',
                            s.autoReleaseCured ? 'Yes (nightly)' : 'No', isDark),
                        const SizedBox(height: 16),
                        Text(
                          'Settings are edited on the web.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : Colors.grey[600]),
                        ),
                      ],
                    ),
    );
  }

  Widget _row(String label, String value, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
          ],
        ),
      ),
    );
  }
}
