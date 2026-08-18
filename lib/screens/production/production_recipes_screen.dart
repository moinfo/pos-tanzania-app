import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/production_messages.dart';

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
