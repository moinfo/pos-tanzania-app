import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../models/customer_card.dart';
import '../models/customer.dart';
import '../providers/theme_provider.dart';
import '../widgets/nfc_scan_dialog.dart';
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
          ? FloatingActionButton(
              onPressed: _registerNewCard,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCardItem(CustomerCard card, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
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
        title: Text(
          card.customerName ?? 'Unknown Customer',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.cardUid,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
              ),
            ),
            if (card.customerPhone != null && card.customerPhone!.isNotEmpty)
              Text(
                card.customerPhone!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => _deactivateCard(card),
          tooltip: 'Deactivate Card',
        ),
        isThreeLine: card.customerPhone != null && card.customerPhone!.isNotEmpty,
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
