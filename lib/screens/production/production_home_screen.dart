import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/production_messages.dart';
import 'production_batches_screen.dart';
import 'production_lots_screen.dart';
import 'production_reports_screen.dart';

/// Entry point for the production module.
class ProductionHomeScreen extends StatelessWidget {
  const ProductionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canSeeReports = permissions.hasPermission(PermissionIds.productionReports);
    final canSeeConfig = permissions.hasPermission(PermissionIds.productionCostmap);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Production'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _tile(
            context,
            isDark,
            Icons.precision_manufacturing_outlined,
            'Batches',
            'Open a batch, record output, void mistakes',
            () => const ProductionBatchesScreen(),
          ),
          _tile(
            context,
            isDark,
            Icons.layers_outlined,
            'Sand Lots',
            'Landed cost per lot and what it yielded',
            () => const ProductionLotsScreen(),
          ),
          if (canSeeReports)
            _tile(
              context,
              isDark,
              Icons.bar_chart,
              'Reports',
              'Efficiency, costing, variance and material journey',
              () => const ProductionReportsScreen(),
            ),
          _tile(
            context,
            isDark,
            Icons.menu_book_outlined,
            'Recipes',
            'Yield per bag and raw materials of each product',
            () => const ProductionRecipesScreen(),
          ),
          if (canSeeConfig)
            _tile(
              context,
              isDark,
              Icons.settings_outlined,
              'Settings',
              'Locations, valuation and tolerance',
              () => const ProductionSettingsScreen(),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, bool isDark, IconData icon, String title,
      String subtitle, Widget Function() builder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => builder())),
      ),
    );
  }
}

/// Read-only. Creating a recipe means picking raw materials and yield rates --
/// setup work that belongs on the web form, where the whole item catalogue is
/// to hand. The write endpoints exist if this ever needs to change.
class ProductionRecipesScreen extends StatefulWidget {
  const ProductionRecipesScreen({super.key});

  @override
  State<ProductionRecipesScreen> createState() => _ProductionRecipesScreenState();
}

class _ProductionRecipesScreenState extends State<ProductionRecipesScreen> {
  final ApiService _apiService = ApiService();
  final _number = NumberFormat('#,##0.##');

  List<ProductionRecipe> _recipes = [];
  bool _showInactive = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getProductionRecipes(all: _showInactive);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _recipes = response.data!;
      } else {
        _errorMessage = productionErrorMessage(response.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Recipes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            tooltip: _showInactive ? 'Active only' : 'Show inactive',
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
              _load();
            },
          ),
        ],
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
              : _recipes.isEmpty
                  ? Center(
                      child: Text('No recipes',
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : Colors.grey[500])),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _recipes.length,
                      itemBuilder: (_, i) => _buildCard(_recipes[i], isDark),
                    ),
    );
  }

  Widget _buildCard(ProductionRecipe r, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textColor)),
                ),
                if (!r.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Text('inactive',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_number.format(r.standardYieldPerBag)} per bag'
              '${r.curingDays != null ? ' · ${r.curingDays} curing days' : ' · curing from settings'}',
              style: TextStyle(fontSize: 12.5, color: subColor),
            ),
            if (r.items.isNotEmpty) ...[
              const Divider(height: 18),
              ...r.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.itemName ?? 'Item #${item.itemId}',
                            style: TextStyle(fontSize: 12.5, color: subColor)),
                        Text('${_number.format(item.qtyPerBag)} / bag',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

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
