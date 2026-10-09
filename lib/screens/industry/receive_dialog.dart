import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ReceiveResult {
  final int quantity;
  final String note;
  ReceiveResult({required this.quantity, required this.note});
}

/// Shared "Receive" form (roller bags / mattresses) - same shape, different
/// label, used by Roller and Mattress screens.
class ReceiveDialog extends StatefulWidget {
  final String title;
  final String quantityLabel;

  const ReceiveDialog({super.key, required this.title, required this.quantityLabel});

  @override
  State<ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<ReceiveDialog> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: widget.quantityLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
          onPressed: () {
            final quantity = int.tryParse(_quantityController.text) ?? 0;
            Navigator.pop(
              context,
              ReceiveResult(quantity: quantity, note: _noteController.text),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
