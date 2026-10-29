import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_booking_detail_screen.dart';

/// `GET lodge/payments` -- README 3.11: totals by payment type, then the
/// list. Edit/delete come in a later phase; `editable=false` rows (the
/// guest already checked out) are shown locked either way.
class LodgePaymentsScreen extends StatefulWidget {
  const LodgePaymentsScreen({super.key});

  @override
  State<LodgePaymentsScreen> createState() => _LodgePaymentsScreenState();
}

class _LodgePaymentsScreenState extends State<LodgePaymentsScreen> {
  final ApiService _apiService = ApiService();
  LodgePaymentsByType? _data;
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
    final response = await _apiService.getLodgePayments();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _data = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
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
        title: const Text('Payments'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_data!.byType.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _data!.byType.entries
                              .map((e) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkCard : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(Formatters.formatCompactCurrency(e.value),
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(e.key, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 12),
                      ..._data!.payments.map((p) => Card(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: !p.editable ? const Icon(Icons.lock_outline, size: 18) : null,
                              title: Text('${p.paymentType} · ${Formatters.formatCurrency(p.amount)}'),
                              subtitle: Text(
                                  '${Formatters.formatDate(p.paymentTime)}${p.receivedByName != null ? ' · ${p.receivedByName}' : ''}'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LodgeBookingDetailScreen(bookingId: p.bookingId)),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}
