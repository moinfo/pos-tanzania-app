import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/permission_model.dart';
import '../providers/permission_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ItemCategoriesScreen extends StatefulWidget {
  const ItemCategoriesScreen({super.key});

  @override
  State<ItemCategoriesScreen> createState() => _ItemCategoriesScreenState();
}

class _ItemCategoriesScreenState extends State<ItemCategoriesScreen> {
  final _apiService = ApiService();

  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.getItemCategories();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _categories = response.data ?? [];
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? category}) async {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category['name'] as String : '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category name is required')),
                );
                return;
              }
              Navigator.pop(context);
              await _saveCategory(
                name: name,
                id: isEdit ? category['id'] as int : null,
              );
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    nameController.dispose();
  }

  Future<void> _saveCategory({required String name, int? id}) async {
    final response = id != null
        ? await _apiService.updateItemCategory(id, name)
        : await _apiService.createItemCategory(name);

    if (!mounted) return;

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(id != null ? 'Category updated' : 'Category added')),
      );
      _loadCategories();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final response = await _apiService.deleteItemCategory(category['id'] as int);
    if (!mounted) return;

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted')),
      );
      _loadCategories();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final permissionProvider = context.watch<PermissionProvider>();
    final isDark = themeProvider.isDarkMode;

    final canEdit = permissionProvider.hasPermission(PermissionIds.itemsCategories);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Categories'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showCategoryDialog(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCategories,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(
                      child: Text(
                        'No categories yet',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              child: Text(
                                (cat['name'] as String).substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              cat['name'] as String,
                              style: TextStyle(
                                color: isDark ? AppColors.darkText : AppColors.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: canEdit
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showCategoryDialog(category: cat);
                                      } else if (value == 'delete') {
                                        _confirmDelete(cat);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ]),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [
                                          Icon(Icons.delete,
                                              size: 20,
                                              color: AppColors.error),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style: TextStyle(
                                                  color: AppColors.error)),
                                        ]),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }
}