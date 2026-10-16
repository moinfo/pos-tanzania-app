import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/receiving.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/tr_text.dart';
import '../../l10n/lang.dart';

/// Pick which of a receiving's items are coming back, and how many of each.
///
/// A delivery of 50 items where two are being returned used to put all 50 in
/// the cart for 48 of them to be deleted one line at a time. Nothing is
/// ticked here to begin with: the common case is a handful of items, and
/// "Select all" is one tap away for the whole delivery.
///
/// Returns a map keyed "itemId:itemLocation" of the quantities chosen, or
/// null if the clerk backed out.
class ReturnItemsPicker extends StatefulWidget {
  final ReceivingDetails receiving;

  const ReturnItemsPicker({super.key, required this.receiving});

  @override
  State<ReturnItemsPicker> createState() => _ReturnItemsPickerState();
}

class _ReturnItemsPickerState extends State<ReturnItemsPicker> {
  /// Quantity chosen per item, keyed "itemId:itemLocation". An item absent
  /// from here is not coming back.
  final Map<String, double> _chosen = {};

  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  List<ReceivingReturnable> get _lines => widget.receiving.returnableLines
      .where((row) => row.returnable > 0)
      .toList();

  List<ReceivingReturnable> get _visible {
    if (_search.isEmpty) return _lines;
    final needle = _search.toLowerCase();
    return _lines
        .where((row) => row.itemName.toLowerCase().contains(needle))
        .toList();
  }

  static String _key(ReceivingReturnable row) =>
      '${row.itemId}:${row.itemLocation}';

  /// 50, not 50.0 -- these numbers are read out loud at a counter.
  static String _plain(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  double get _totalChosen =>
      _chosen.values.fold(0.0, (sum, quantity) => sum + quantity);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(ReceivingReturnable row, bool ticked) {
    setState(() {
      if (ticked) {
        // Ticking an item means all of it unless the clerk says otherwise;
        // that is what "return this item" usually means.
        _chosen[_key(row)] = row.returnable;
      } else {
        _chosen.remove(_key(row));
      }
    });
  }

  Future<void> _editQuantity(ReceivingReturnable row) async {
    final key = _key(row);
    final controller = TextEditingController(
      text: _plain(_chosen[key] ?? row.returnable),
    );

    final typed = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.itemName),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Quantity to return'.tr,
            border: const OutlineInputBorder(),
            helperText: '${_plain(row.returnable)} returnable'.tr,
          ),
          onSubmitted: (value) =>
              Navigator.pop(context, double.tryParse(value.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (typed == null || !mounted) return;

    final quantity = typed.abs();
    if (quantity == 0) {
      setState(() => _chosen.remove(key));
      return;
    }

    if (quantity > row.returnable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_plain(row.returnable)} is the most that can be '
            'returned for ${row.itemName}.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _chosen[key] = quantity);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final lines = _lines;
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: Text('Return from #${widget.receiving.receivingId}'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.warning,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (_chosen.length == lines.length) {
                _chosen.clear();
              } else {
                for (final row in lines) {
                  _chosen[_key(row)] = row.returnable;
                }
              }
            }),
            child: Text(
              _chosen.length == lines.length ? 'Clear' : 'Select all',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.receiving.supplierName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '${lines.length} item(s) returnable',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextLight : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                // 50 items is a long scroll to find two.
                if (lines.length > 8) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _search = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search this receiving...'.tr,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      lines.isEmpty
                          ? 'Nothing left to return on this receiving.'
                          : 'No item here matches "$_search".',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = visible[index];
                      final key = _key(row);
                      final chosen = _chosen[key];
                      final ticked = chosen != null;

                      return CheckboxListTile(
                        value: ticked,
                        onChanged: (value) => _toggle(row, value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.warning,
                        title: Text(
                          row.itemName.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          row.returned > 0
                              ? '${_plain(row.returnable)} returnable '
                                  '(${_plain(row.returned)} of '
                                  '${_plain(row.received)} already back)'
                              : '${_plain(row.returnable)} returnable',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextLight
                                : Colors.grey.shade600,
                          ),
                        ),
                        secondary: ticked
                            ? OutlinedButton(
                                onPressed: () => _editQuantity(row),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.warning,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                ),
                                child: Text(_plain(chosen)),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _chosen.isEmpty
                          ? 'Nothing selected'
                          : '${_chosen.length} item(s), '
                              '${_plain(_totalChosen)} unit(s)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _chosen.isEmpty
                            ? Colors.grey.shade600
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _chosen.isEmpty
                        ? null
                        : () => Navigator.pop(context, Map.of(_chosen)),
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Return selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
