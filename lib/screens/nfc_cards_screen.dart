import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/pdf_service.dart';
import '../models/customer_card.dart';
import '../models/customer.dart';
import '../models/nfc_wallet.dart';
import '../models/permission_model.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../widgets/nfc_scan_dialog.dart';
import '../widgets/permission_wrapper.dart';
import '../utils/constants.dart';

class NfcCardsScreen extends StatefulWidget {
  const NfcCardsScreen({super.key});

  @override
  State<NfcCardsScreen> createState() => _NfcCardsScreenState();
}

class _NfcCardsScreenState extends State<NfcCardsScreen> {
  final ApiService _apiService = ApiService();
  final NfcService _nfcService = NfcService();

  List<CustomerCard> _cards = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _nfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _loadCards();
  }

  Future<void> _checkNfcAvailability() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    if (mounted) {
      setState(() => _nfcAvailable = isAvailable);
    }
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getAllCustomerCards();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _cards = response.data!;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  Future<void> _scanAndLookupCard() async {
    final result = await showDialog<NfcScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NfcScanDialog(lookupCustomer: true),
    );

    if (result != null && result.success && mounted) {
      if (result.customer != null) {
        // Card found with customer
        _showCustomerDetailsDialog(result.customer!, result.cardUid!);
      } else {
        // Card not registered
        _showUnregisteredCardDialog(result.cardUid!);
      }
    }
  }

  void _showCustomerDetailsDialog(Customer customer, String cardUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            const Text('Card Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  customer.firstName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                '${customer.firstName} ${customer.lastName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: customer.phoneNumber.isNotEmpty
                  ? Text(customer.phoneNumber)
                  : null,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            Text(
              'Card UID',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              cardUid,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUnregisteredCardDialog(String cardUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Card Not Registered'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This card is not linked to any customer.'),
            const SizedBox(height: 16),
            Text(
              'Card UID',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              cardUid,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _selectCustomerForCard(cardUid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Register Card'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomerForCard(String cardUid) async {
    // Show customer selection dialog
    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => const _CustomerPickerDialog(),
    );

    if (customer != null && mounted) {
      // Register the card
      final response = await _nfcService.registerCard(
        customerId: customer.personId,
        cardUid: cardUid,
      );

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card registered to ${customer.firstName} ${customer.lastName}'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadCards(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _registerNewCard() async {
    // First select a customer
    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => const _CustomerPickerDialog(),
    );

    if (customer != null && mounted) {
      // Then scan the card
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => NfcRegisterCardDialog(customer: customer),
      );

      if (result == true) {
        _loadCards(); // Refresh the list
      }
    }
  }

  Future<void> _deactivateCard(CustomerCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Card'),
        content: Text(
          'Are you sure you want to deactivate this card?\n\n'
          'Customer: ${card.customerName}\n'
          'Card UID: ${card.cardUid}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final response = await _nfcService.unregisterCard(card.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
          ),
        );

        if (response.isSuccess) {
          _loadCards();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Cards'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Scan card button
          if (_nfcAvailable)
            IconButton(
              icon: const Icon(Icons.nfc),
              onPressed: _scanAndLookupCard,
              tooltip: 'Scan Card',
            ),
        ],
      ),
      body: !_nfcAvailable
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nfc_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NFC is not available on this device',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(_errorMessage!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadCards,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _cards.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.credit_card_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No NFC cards registered',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _registerNewCard,
                                icon: const Icon(Icons.add),
                                label: const Text('Register First Card'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadCards,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _cards.length,
                            itemBuilder: (context, index) {
                              return _buildCardItem(_cards[index], isDark);
                            },
                          ),
                        ),
      floatingActionButton: _nfcAvailable
          ? PermissionWrapper(
              permissionId: PermissionIds.nfcCardsRegister,
              child: FloatingActionButton(
                onPressed: _registerNewCard,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildCardItem(CustomerCard card, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with customer info and menu
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.nfc,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.customerName ?? 'Unknown Customer',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        card.cardUid,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'settings':
                        _showCardSettings(card);
                        break;
                      case 'deactivate':
                        _deactivateCard(card);
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
                    return [
                      if (permissionProvider.hasPermission(PermissionIds.nfcCardsSettings))
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings),
                              SizedBox(width: 8),
                              Text('Settings'),
                            ],
                          ),
                        ),
                      if (permissionProvider.hasPermission(PermissionIds.nfcCardsUnregister))
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Deactivate', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Balance display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(card.balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildBalanceStat('Deposited', currencyFormat.format(card.totalDeposited), Colors.white70),
                      const SizedBox(width: 24),
                      _buildBalanceStat('Spent', currencyFormat.format(card.totalSpent), Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Feature indicators
            if (card.nfcConfirmRequired || card.nfcPaymentEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (card.nfcConfirmRequired)
                      Chip(
                        label: const Text('Confirmation Required', style: TextStyle(fontSize: 11)),
                        backgroundColor: Colors.orange.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: Colors.orange),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    if (card.nfcPaymentEnabled)
                      Chip(
                        label: const Text('Wallet Payment Enabled', style: TextStyle(fontSize: 11)),
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: Colors.green),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: PermissionWrapper(
                    permissionId: PermissionIds.nfcCardsDeposit,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDepositDialog(card),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Deposit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PermissionWrapper(
                    permissionId: PermissionIds.nfcCardsStatement,
                    child: OutlinedButton.icon(
                      onPressed: () => _showStatement(card),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Statement'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _showDepositDialog(CustomerCard card) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deposit to Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${card.customerName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (TZS)',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount = double.parse(amountController.text);
    final description = descriptionController.text.trim();

    // Scan NFC card to confirm deposit
    final scanResult = await showDialog<NfcScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NfcScanDialog(
        title: 'Confirm Deposit',
        subtitle: 'Scan the NFC card to confirm deposit of TZS ${NumberFormat('#,###').format(amount)}',
        expectedCardUid: card.cardUid,
      ),
    );

    if (scanResult == null || !scanResult.success || !mounted) return;

    // Check if scanned card matches
    if (scanResult.cardUid != card.cardUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card mismatch! Please scan the correct card.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Process deposit
    setState(() => _isLoading = true);

    final response = await _apiService.depositToNfcCard(
      cardUid: card.cardUid,
      amount: amount,
      description: description.isEmpty ? null : description,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (response.isSuccess && response.data != null) {
        final result = response.data!;
        final currencyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 12),
                const Text('Deposit Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // New Balance - Prominent display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'NEW BALANCE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(result.balanceAfter),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildResultRow('Deposited Amount', '+${currencyFormat.format(result.amount)}', isHighlight: true),
                      const Divider(height: 16),
                      _buildResultRow('Previous Balance', currencyFormat.format(result.balanceBefore)),
                      _buildResultRow('Customer', card.customerName ?? 'Unknown'),
                      _buildResultRow('Card UID', card.cardUid),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Print and Share buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await PdfService.printNfcDepositReceipt(
                            customerName: card.customerName ?? 'Customer',
                            cardUid: card.cardUid,
                            amount: result.amount,
                            balanceBefore: result.balanceBefore,
                            balanceAfter: result.balanceAfter,
                            description: description.isEmpty ? null : description,
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await PdfService.shareNfcDepositReceipt(
                            customerName: card.customerName ?? 'Customer',
                            cardUid: card.cardUid,
                            amount: result.amount,
                            balanceBefore: result.balanceBefore,
                            balanceAfter: result.balanceAfter,
                            description: description.isEmpty ? null : description,
                          );
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _loadCards(); // Refresh the list
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildResultRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.success : null,
              fontSize: isHighlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatement(CustomerCard card) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NfcStatementScreen(card: card),
      ),
    );
  }

  Future<void> _showCardSettings(CustomerCard card) async {
    bool nfcConfirmRequired = card.nfcConfirmRequired;
    bool nfcPaymentEnabled = card.nfcPaymentEnabled;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('NFC Card Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Require NFC Confirmation'),
                subtitle: const Text('Customer must scan card for credit sales and payments'),
                value: nfcConfirmRequired,
                onChanged: (value) => setDialogState(() => nfcConfirmRequired = value),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Enable Wallet Payment'),
                subtitle: const Text('Allow paying with card balance'),
                value: nfcPaymentEnabled,
                onChanged: (value) => setDialogState(() => nfcPaymentEnabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    // Save settings via API
    final response = await _apiService.updateCustomerNfcSettings(
      customerId: card.customerId,
      nfcConfirmRequired: nfcConfirmRequired,
      nfcPaymentEnabled: nfcPaymentEnabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.isSuccess ? 'Settings saved' : response.message),
          backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
        ),
      );

      if (response.isSuccess) {
        _loadCards(); // Refresh the list
      }
    }
  }
}

/// NFC Statement Screen
class NfcStatementScreen extends StatefulWidget {
  final CustomerCard card;

  const NfcStatementScreen({super.key, required this.card});

  @override
  State<NfcStatementScreen> createState() => _NfcStatementScreenState();
}

class _NfcStatementScreenState extends State<NfcStatementScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  NfcStatement? _statement;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getNfcStatement(cardUid: widget.card.cardUid);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _statement = response.data!;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final currencyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Statement'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatement,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatement,
                  child: Column(
                    children: [
                      // Summary header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: isDark ? AppColors.darkSurface : AppColors.primary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.card.customerName ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Current Balance: ${currencyFormat.format(_statement?.card.balance ?? 0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total Deposits',
                                    currencyFormat.format(_statement?.totalDeposits ?? 0),
                                    Icons.arrow_downward,
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total Payments',
                                    currencyFormat.format(_statement?.totalPayments ?? 0),
                                    Icons.arrow_upward,
                                    Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Transactions list
                      Expanded(
                        child: _statement?.transactions.isEmpty ?? true
                            ? const Center(
                                child: Text('No transactions yet'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _statement!.transactions.length,
                                itemBuilder: (context, index) {
                                  final txn = _statement!.transactions[index];
                                  final isDeposit = txn.amount > 0;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: (isDeposit ? Colors.green : Colors.red)
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isDeposit
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: isDeposit ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      title: Text(
                                        txn.transactionType.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateFormat.format(txn.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.darkTextLight
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          if (txn.description != null &&
                                              txn.description!.isNotEmpty)
                                            Text(
                                              txn.description!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors.darkTextLight
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isDeposit ? '+' : ''}${currencyFormat.format(txn.amount)}',
                                            style: TextStyle(
                                              color: isDeposit ? Colors.green : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Bal: ${currencyFormat.format(txn.balanceAfter)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppColors.darkTextLight
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      isThreeLine: txn.description != null &&
                                          txn.description!.isNotEmpty,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

/// Dialog to pick a customer for card registration
class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog();

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final response = await _apiService.getCustomers(limit: 100);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _customers = response.data!;
          _filteredCustomers = _customers;
        }
      });
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers
            .where((customer) =>
                customer.firstName.toLowerCase().contains(query.toLowerCase()) ||
                customer.lastName.toLowerCase().contains(query.toLowerCase()) ||
                customer.phoneNumber.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterCustomers,
            ),
            const SizedBox(height: 16),

            // Customers list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                      ? const Center(child: Text('No customers found'))
                      : ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    customer.firstName[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  '${customer.firstName} ${customer.lastName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: customer.phoneNumber.isNotEmpty
                                    ? Text(customer.phoneNumber)
                                    : null,
                                onTap: () => Navigator.pop(context, customer),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
