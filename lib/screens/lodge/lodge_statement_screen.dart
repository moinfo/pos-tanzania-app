import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET lodge/bookings/{id}/statement` -- README 3.6: charges/payments in
/// date order with a running balance; future (paid-ahead) nights render
/// greyed out, credit rows render amber.
class LodgeStatementScreen extends StatefulWidget {
  final int bookingId;

  const LodgeStatementScreen({super.key, required this.bookingId});

  @override
  State<LodgeStatementScreen> createState() => _LodgeStatementScreenState();
}

class _LodgeStatementScreenState extends State<LodgeStatementScreen> {
  final ApiService _apiService = ApiService();
  LodgeStatement? _statement;
  LodgeMeta? _meta;
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

    final results = await Future.wait([
      _apiService.getLodgeStatement(widget.bookingId),
      _apiService.getLodgeMeta(),
    ]);
    if (!mounted) return;

    final statementResponse = results[0];
    final metaResponse = results[1];

    setState(() {
      _isLoading = false;
      if (statementResponse.isSuccess) {
        _statement = statementResponse.data as LodgeStatement;
      } else {
        _errorMessage = statementResponse.message;
      }
      if (metaResponse.isSuccess) _meta = metaResponse.data as LodgeMeta;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;
    final cs = _meta?.currencySymbol ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('Statement'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null || _statement == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage ?? 'Haikupatikana', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Jaribu tena')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_statement!.booking.guestName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? AppColors.darkText : AppColors.lightText)),
                          const SizedBox(height: 4),
                          Text('Chumba ${_statement!.booking.roomNumber ?? '-'}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                          const Divider(height: 20),
                          Text('Anadaiwa leo: $cs ${Formatters.formatCurrency(_statement!.ledger.balanceNow)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _statement!.ledger.balanceNow > 0
                                      ? AppColors.error
                                      : AppColors.success)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._statement!.rows.map((row) => _buildRow(row, isDark, cs)),
                  ],
                ),
    );
  }

  Widget _buildRow(LodgeStatementRow row, bool isDark, String cs) {
    final isCredit = row.type == 'credit';
    final textColor = row.future
        ? (isDark ? AppColors.darkTextLight : Colors.grey)
        : isCredit
            ? AppColors.warning
            : (isDark ? AppColors.darkText : AppColors.lightText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(Formatters.formatDate(row.date),
                style: TextStyle(fontSize: 12, color: textColor)),
          ),
          Expanded(
            child: Text(
              row.charge != null ? 'Malazi' : (isCredit ? 'Kwa mkopo' : 'Malipo'),
              style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
          if (row.charge != null)
            Text('+$cs ${Formatters.formatCurrency(row.charge!)}',
                style: TextStyle(fontSize: 12.5, color: textColor)),
          if (row.payment != null)
            Text('-$cs ${Formatters.formatCurrency(row.payment!)}',
                style: TextStyle(fontSize: 12.5, color: textColor)),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text('$cs ${Formatters.formatCurrency(row.balance)}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor)),
          ),
        ],
      ),
    );
  }
}
