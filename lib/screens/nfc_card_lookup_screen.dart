import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../models/nfc_wallet.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';

class NfcCardLookupScreen extends StatefulWidget {
  const NfcCardLookupScreen({super.key});

  @override
  State<NfcCardLookupScreen> createState() => _NfcCardLookupScreenState();
}

class _NfcCardLookupScreenState extends State<NfcCardLookupScreen> {
  final ApiService _apiService = ApiService();
  final NfcService _nfcService = NfcService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

  bool _isScanning = false;
  bool _isLoading = false;
  String? _errorMessage;
  NfcCardBalance? _cardBalance;
  String? _scannedCardUid;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    if (!isAvailable && mounted) {
      setState(() {
        _errorMessage = 'NFC is not available on this device';
      });
    }
  }

  Future<void> _scanCard() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _cardBalance = null;
      _scannedCardUid = null;
    });

    await _nfcService.startScanning(
      lookupCustomer: false,
      onResult: (result) async {
        // Stop scanning after first result
        await _nfcService.stopScanning();

        if (!mounted) return;

        if (!result.success) {
          setState(() {
            _isScanning = false;
            _errorMessage = result.error ?? 'Failed to read NFC card';
          });
          return;
        }

        final cardUid = result.cardUid;
        if (cardUid == null) {
          setState(() {
            _isScanning = false;
            _errorMessage = 'Failed to read card UID';
          });
          return;
        }

        setState(() {
          _isScanning = false;
          _isLoading = true;
          _scannedCardUid = cardUid;
        });

        // Fetch card balance and info
        final balanceResponse = await _apiService.getNfcCardBalance(cardUid);

        if (mounted) {
          setState(() {
            _isLoading = false;
            if (balanceResponse.isSuccess && balanceResponse.data != null) {
              _cardBalance = balanceResponse.data;
            } else {
              _errorMessage = balanceResponse.message ?? 'Card not found or not registered';
            }
          });
        }
      },
    );
  }

  void _clearResult() {
    setState(() {
      _cardBalance = null;
      _scannedCardUid = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Card Lookup'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          if (_cardBalance != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearResult,
              tooltip: 'Clear',
            ),
        ],
      ),
      body: _buildBody(isDark),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isScanning) {
      return _buildScanningView(isDark);
    }

    if (_isLoading) {
      return _buildLoadingView(isDark);
    }

    if (_cardBalance != null) {
      return _buildCardInfoView(isDark);
    }

    return _buildInitialView(isDark);
  }

  Widget _buildInitialView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.nfc,
                size: 80,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'NFC Card Lookup',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan a customer\'s NFC card to view their balance and card information',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton.icon(
              onPressed: _scanCard,
              icon: const Icon(Icons.contactless, color: Colors.white),
              label: const Text('Scan NFC Card', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.nfc,
                  size: 80,
                  color: Colors.orange[700],
                ),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Ready to Scan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hold the NFC card near the back of your device',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () {
              _nfcService.stopScanning();
              setState(() => _isScanning = false);
            },
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading card information...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfoView(bool isDark) {
    final balance = _cardBalance!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[700]!, Colors.orange[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.nfc, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'NFC Wallet Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        balance.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _currencyFormat.format(balance.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Card: ${_scannedCardUid ?? "Unknown"}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Customer Info Card
          Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Customer Name', balance.customerName, isDark),
                  _buildInfoRow('Customer ID', balance.customerId.toString(), isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Summary Card
          Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Transaction Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Total Deposited', _currencyFormat.format(balance.totalDeposited), isDark, valueColor: AppColors.success),
                  _buildInfoRow('Total Spent', _currencyFormat.format(balance.totalSpent), isDark, valueColor: AppColors.error),
                  _buildInfoRow('Current Balance', _currencyFormat.format(balance.balance), isDark, valueColor: balance.balance > 0 ? AppColors.success : AppColors.textLight),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings Card
          Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Card Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildSettingRow('NFC Payment', balance.nfcPaymentEnabled, isDark),
                  _buildSettingRow('Confirmation Required', balance.nfcConfirmRequired, isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Scan Another Card Button
          ElevatedButton.icon(
            onPressed: _scanCard,
            icon: const Icon(Icons.contactless, color: Colors.white),
            label: const Text('Scan Another Card', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? AppColors.darkText : AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, bool enabled, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: enabled ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  enabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
