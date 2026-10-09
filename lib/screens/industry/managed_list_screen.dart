import 'package:flutter/material.dart';
import '../../models/api_response.dart';
import '../../utils/constants.dart';

/// Describes one editable field on a [ManagedListScreen]'s add/edit form.
class ManagedField {
  final String formKey;
  final String label;
  final bool isCheckbox;

  const ManagedField({required this.formKey, required this.label, this.isCheckbox = false});
}

/// Generic CRUD list screen for the search/get_row/save/delete shape shared
/// by Casual Labourers and Machines. [T] is the row model; [rowToFields]
/// converts it to the form's initial values for editing.
class ManagedListScreen<T> extends StatefulWidget {
  final String title;
  final List<ManagedField> fields;
  final Future<ApiResponse<Map<String, dynamic>>> Function({
    required String search,
    required int limit,
    required int offset,
  }) onSearch;
  final Future<ApiResponse<T>> Function(int id) onGetRow;
  final Future<ApiResponse<Map<String, dynamic>>> Function({
    int? id,
    required Map<String, String> fields,
  }) onSave;
  final Future<ApiResponse<Map<String, dynamic>>> Function(int id) onDelete;
  final Map<String, String> Function(T row) rowToFields;
  final String Function(Map<String, dynamic> searchRow) rowTitle;
  final String? Function(Map<String, dynamic> searchRow) rowSubtitle;
  final int Function(Map<String, dynamic> searchRow) rowId;
  final VoidCallback onSessionExpired;
  final Widget Function(BuildContext context, Map<String, dynamic> row, VoidCallback onTap, VoidCallback onDelete)?
      itemBuilder;
  final Future<bool?> Function(BuildContext context, int? id)? customFormOpener;

  const ManagedListScreen({
    super.key,
    required this.title,
    required this.fields,
    required this.onSearch,
    required this.onGetRow,
    required this.onSave,
    required this.onDelete,
    required this.rowToFields,
    required this.rowTitle,
    required this.rowSubtitle,
    required this.rowId,
    required this.onSessionExpired,
    this.itemBuilder,
    this.customFormOpener,
  });

  @override
  State<ManagedListScreen<T>> createState() => _ManagedListScreenState<T>();
}

class _ManagedListScreenState<T> extends State<ManagedListScreen<T>> {
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.onSearch(search: _searchController.text, limit: 100, offset: 0);

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
      return;
    }

    final rows = (response.data!['rows'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      _rows = rows;
      _isLoading = false;
    });
  }

  Future<void> _openForm({int? id}) async {
    if (widget.customFormOpener != null) {
      final saved = await widget.customFormOpener!(context, id);
      if (saved == true) _load();
      return;
    }

    Map<String, String> initial = {for (final f in widget.fields) f.formKey: ''};

    if (id != null) {
      final rowResponse = await widget.onGetRow(id);
      if (!mounted) return;
      if (rowResponse.statusCode == 440) {
        widget.onSessionExpired();
        return;
      }
      if (rowResponse.isSuccess && rowResponse.data != null) {
        initial = widget.rowToFields(rowResponse.data as T);
      }
    }

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EntryFormDialog(
        title: id == null ? 'Add' : 'Edit',
        fields: widget.fields,
        initialValues: initial,
        onSubmit: (values) => widget.onSave(id: id, fields: values),
      ),
    );

    if (saved == true) _load();
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await widget.onDelete(id);
    if (!mounted) return;

    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message),
        backgroundColor: response.isSuccess ? Colors.green : Colors.red,
      ),
    );

    if (response.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: AppColors.brandPrimary),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  _searchController.clear();
                  _load();
                }),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          16, 0, 16, 16 + MediaQuery.of(context).size.height * 0.05),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final id = widget.rowId(row);
                        if (widget.itemBuilder != null) {
                          return widget.itemBuilder!(
                            context,
                            row,
                            () => _openForm(id: id),
                            () => _delete(id),
                          );
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(widget.rowTitle(row)),
                            subtitle: widget.rowSubtitle(row) != null
                                ? Text(widget.rowSubtitle(row)!)
                                : null,
                            onTap: () => _openForm(id: id),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _delete(id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandPrimary,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _EntryFormDialog extends StatefulWidget {
  final String title;
  final List<ManagedField> fields;
  final Map<String, String> initialValues;
  final Future<ApiResponse<Map<String, dynamic>>> Function(Map<String, String> values) onSubmit;

  const _EntryFormDialog({
    required this.title,
    required this.fields,
    required this.initialValues,
    required this.onSubmit,
  });

  @override
  State<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<_EntryFormDialog> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checkboxValues = {};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      if (field.isCheckbox) {
        _checkboxValues[field.formKey] = widget.initialValues[field.formKey] == '1';
      } else {
        _controllers[field.formKey] =
            TextEditingController(text: widget.initialValues[field.formKey] ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final values = <String, String>{
      for (final field in widget.fields)
        field.formKey: field.isCheckbox
            ? (_checkboxValues[field.formKey] == true ? '1' : '0')
            : (_controllers[field.formKey]?.text ?? ''),
    };

    final response = await widget.onSubmit(values);

    if (!mounted) return;

    if (response.isSuccess) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = response.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.fields.map((field) {
              if (field.isCheckbox) {
                return CheckboxListTile(
                  title: Text(field.label),
                  value: _checkboxValues[field.formKey] ?? false,
                  onChanged: (v) => setState(() => _checkboxValues[field.formKey] = v ?? false),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[field.formKey],
                  decoration: InputDecoration(labelText: field.label),
                ),
              );
            }),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
          child: _isSaving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
