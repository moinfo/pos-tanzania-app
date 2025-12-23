import 'package:flutter/material.dart';
import '../services/nfc_service.dart';
import '../models/customer.dart';
import '../utils/constants.dart';

/// Dialog for scanning NFC cards
class NfcScanDialog extends StatefulWidget {
  final bool lookupCustomer;
  final Function(String cardUid, Customer? customer)? onCardScanned;

  const NfcScanDialog({
    super.key,
    this.lookupCustomer = true,
    this.onCardScanned,
  });

  @override
  State<NfcScanDialog> createState() => _NfcScanDialogState();
}

class _NfcScanDialogState extends State<NfcScanDialog>
    with SingleTickerProviderStateMixin {
  final NfcService _nfcService = NfcService();
  bool _isScanning = false;
  bool _nfcAvailable = true;
  String? _statusMessage;
  bool _hasError = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _checkNfcAndStartScanning();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nfcService.stopScanning();
    super.dispose();
  }

  Future<void> _checkNfcAndStartScanning() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    if (!mounted) return;

    if (!isAvailable) {
      setState(() {
        _nfcAvailable = false;
        _statusMessage = 'NFC is not available on this device';
        _hasError = true;
      });
      return;
    }

    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold card near the device...';
      _hasError = false;
    });

    await _nfcService.startScanning(
      lookupCustomer: widget.lookupCustomer,
      onResult: (result) {
        if (!mounted) return;

        if (result.success) {
          // Card scanned successfully
          setState(() {
            _isScanning = false;
            if (result.customer != null) {
              _statusMessage = 'Customer found: ${result.customer!.firstName} ${result.customer!.lastName}';
            } else if (widget.lookupCustomer) {
              _statusMessage = 'Card scanned, but no customer linked';
            } else {
              _statusMessage = 'Card UID: ${result.cardUid}';
            }
          });

          // Notify callback
          if (widget.onCardScanned != null) {
            widget.onCardScanned!(result.cardUid!, result.customer);
          }

          // Auto-close after brief delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pop(context, result);
            }
          });
        } else {
          setState(() {
            _statusMessage = result.error ?? 'Error scanning card';
            _hasError = true;
          });

          // Restart scanning after error
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isScanning) {
              _startScanning();
            }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan NFC Card',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _nfcService.stopScanning();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // NFC Icon with animation
            if (_nfcAvailable)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isScanning ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _hasError
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.nfc,
                        size: 64,
                        color: _hasError ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nfc_outlined,
                  size: 64,
                  color: AppColors.error,
                ),
              ),

            const SizedBox(height: 24),

            // Status message
            Text(
              _statusMessage ?? 'Initializing NFC...',
              style: TextStyle(
                fontSize: 16,
                color: _hasError ? AppColors.error : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Progress indicator when scanning
            if (_isScanning)
              const LinearProgressIndicator(
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),

            const SizedBox(height: 24),

            // Retry button if there's an error
            if (_hasError && _nfcAvailable)
              ElevatedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for registering an NFC card to a customer
class NfcRegisterCardDialog extends StatefulWidget {
  final Customer customer;
  final String? preScannedCardUid;

  const NfcRegisterCardDialog({
    super.key,
    required this.customer,
    this.preScannedCardUid,
  });

  @override
  State<NfcRegisterCardDialog> createState() => _NfcRegisterCardDialogState();
}

class _NfcRegisterCardDialogState extends State<NfcRegisterCardDialog> {
  final NfcService _nfcService = NfcService();
  String? _cardUid;
  bool _isScanning = false;
  bool _isRegistering = false;
  String? _statusMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.preScannedCardUid != null) {
      _cardUid = widget.preScannedCardUid;
      _statusMessage = 'Card ready to register';
    }
  }

  @override
  void dispose() {
    _nfcService.stopScanning();
    super.dispose();
  }

  Future<void> _startScanning() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    if (!isAvailable) {
      setState(() {
        _statusMessage = 'NFC is not available on this device';
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold card near the device...';
      _hasError = false;
    });

    await _nfcService.startScanning(
      lookupCustomer: false, // Don't lookup, we want the raw UID
      onResult: (result) {
        if (!mounted) return;

        _nfcService.stopScanning();

        if (result.success && result.cardUid != null) {
          setState(() {
            _cardUid = result.cardUid;
            _isScanning = false;
            _statusMessage = 'Card scanned successfully';
          });
        } else {
          setState(() {
            _isScanning = false;
            _statusMessage = result.error ?? 'Error scanning card';
            _hasError = true;
          });
        }
      },
    );
  }

  Future<void> _registerCard() async {
    if (_cardUid == null) return;

    setState(() {
      _isRegistering = true;
      _statusMessage = 'Registering card...';
    });

    final response = await _nfcService.registerCard(
      customerId: widget.customer.personId,
      cardUid: _cardUid!,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card registered to ${widget.customer.firstName}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() {
        _isRegistering = false;
        _statusMessage = response.message;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Register NFC Card',
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

            // Customer info
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    widget.customer.firstName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  '${widget.customer.firstName} ${widget.customer.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: widget.customer.phoneNumber.isNotEmpty
                    ? Text(widget.customer.phoneNumber)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // Card UID display
            if (_cardUid != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Card UID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _cardUid ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isRegistering ? null : _startScanning,
                      tooltip: 'Scan different card',
                    ),
                  ],
                ),
              )
            else
              // Scan button
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScanning,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.nfc),
                label: Text(_isScanning ? 'Scanning...' : 'Scan Card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

            const SizedBox(height: 16),

            // Status message
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _hasError ? AppColors.error : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 24),

            // Register button
            if (_cardUid != null)
              ElevatedButton(
                onPressed: _isRegistering ? null : _registerCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isRegistering
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Registering...'),
                        ],
                      )
                    : const Text('Register Card'),
              ),
          ],
        ),
      ),
    );
  }
}
