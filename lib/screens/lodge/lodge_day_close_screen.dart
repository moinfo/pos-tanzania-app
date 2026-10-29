import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET/POST lodge/day-close` -- README 3.15: close out yesterday's cash
/// (opening + cash in - cash expenses - banked - submitted = closing),
/// usually done the next morning.
class LodgeDayCloseScreen extends StatefulWidget {
  const LodgeDayCloseScreen({super.key});

  @override
  State<LodgeDayCloseScreen> createState() => _LodgeDayCloseScreenState();
}

class _LodgeDayCloseScreenState extends State<LodgeDayCloseScreen> {
  final ApiService _apiService = ApiService();
  final _bankedController = TextEditingController(text: '0');
  final _submittedController = TextEditingController(text: '0');
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now().subtract(const Duration(days: 1));
  LodgeDayClose? _data;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bankedController.dispose();
    _submittedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeDayClose(date: Formatters.formatDateForApi(_date));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _data = response.data;
        _bankedController.text = _data!.figures.banked.toStringAsFixed(0);
        _submittedController.text = _data!.figures.cashSubmitted.toStringAsFixed(0);
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _load();
  }

  Future<void> _submit() async {
    final banked = double.tryParse(_bankedController.text) ?? 0;
    final submitted = double.tryParse(_submittedController.text) ?? 0;

    setState(() => _isSubmitting = true);
    final response = await _apiService.closeLodgeDay(
      date: Formatters.formatDateForApi(_date),
      banked: banked,
      cashSubmitted: submitted,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response.isSuccess && response.data != null) {
      setState(() => _data = response.data);
      final sent = response.data!.bossReport.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent > 0 ? 'Day closed. Boss report sent to $sent number(s).' : 'Day closed.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('Day Close'),
        actions: [
          if (_data?.canPickDate ?? false)
            IconButton(icon: const Icon(Icons.calendar_today, size: 20), onPressed: _pickDate),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage ?? 'Not found'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final f = _data!.figures;
    final banked = double.tryParse(_bankedController.text) ?? 0;
    final submitted = double.tryParse(_submittedController.text) ?? 0;
    final closing = f.openingCash + f.cashIn - f.cashExpenses - banked - submitted;
    final readOnly = _data!.closed && !_data!.canEditClose;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(Formatters.formatDateForApi(_date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _card(isDark, children: [
            _row('Opening cash', f.openingCash, isDark),
            _row('Cash sales', f.cashIn, isDark),
            _row('Lipa Namba', f.lipaIn, isDark),
            _row('Bank', f.bankIn, isDark),
            _row('Credit (info only)', f.creditIn, isDark),
            _row('Cash expenses', -f.cashExpenses, isDark),
          ]),
          const SizedBox(height: 12),
          if (readOnly)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('This day is closed.')),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _bankedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Banked', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _submittedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cash submitted', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: closing < 0
                  ? AppColors.error.withOpacity(0.12)
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Closing cash', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(Formatters.formatCurrency(closing),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: closing < 0 ? AppColors.error : null)),
              ],
            ),
          ),
          if (!readOnly) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Close day'),
              ),
            ),
          ],
          if (_data!.recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Recent closes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ..._data!.recent.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.date),
                      Row(
                        children: [
                          Text(Formatters.formatCurrency(r.closingCash)),
                          const SizedBox(width: 6),
                          Icon(r.closed ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 16, color: r.closed ? AppColors.success : Colors.grey),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, double value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
          Text(Formatters.formatCurrency(value),
              style: TextStyle(fontWeight: FontWeight.w600, color: value < 0 ? AppColors.error : null)),
        ],
      ),
    );
  }
}
