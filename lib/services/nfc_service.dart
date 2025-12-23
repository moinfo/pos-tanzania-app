import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import '../models/customer_card.dart';
import '../models/customer.dart';
import '../models/api_response.dart';
import 'api_service.dart';

/// Result of an NFC scan operation
class NfcScanResult {
  final bool success;
  final String? cardUid;
  final String? error;
  final Customer? customer;

  NfcScanResult({
    required this.success,
    this.cardUid,
    this.error,
    this.customer,
  });

  factory NfcScanResult.success(String cardUid, {Customer? customer}) {
    return NfcScanResult(
      success: true,
      cardUid: cardUid,
      customer: customer,
    );
  }

  factory NfcScanResult.error(String message) {
    return NfcScanResult(
      success: false,
      error: message,
    );
  }
}

/// Service for handling NFC card operations
class NfcService {
  final ApiService _apiService = ApiService();

  // Singleton pattern
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  // Stream controller for NFC events
  final _nfcController = StreamController<NfcScanResult>.broadcast();
  Stream<NfcScanResult> get nfcStream => _nfcController.stream;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Check if NFC is available on this device
  Future<bool> isNfcAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('NFC: Error checking availability - $e');
      return false;
    }
  }

  /// Start scanning for NFC cards
  /// Returns a stream of scan results
  Future<void> startScanning({
    required Function(NfcScanResult) onResult,
    bool lookupCustomer = true,
  }) async {
    if (_isScanning) {
      debugPrint('NFC: Already scanning');
      return;
    }

    final isAvailable = await isNfcAvailable();
    if (!isAvailable) {
      onResult(NfcScanResult.error('NFC is not available on this device'));
      return;
    }

    _isScanning = true;
    debugPrint('NFC: Starting scan...');

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final cardUid = _extractCardUid(tag);
            debugPrint('NFC: Card detected - UID: $cardUid');

            if (cardUid == null || cardUid.isEmpty) {
              onResult(NfcScanResult.error('Could not read card ID'));
              return;
            }

            if (lookupCustomer) {
              // Look up customer by card UID
              final customer = await getCustomerByCardUid(cardUid);
              onResult(NfcScanResult.success(cardUid, customer: customer));
            } else {
              onResult(NfcScanResult.success(cardUid));
            }
          } catch (e) {
            debugPrint('NFC: Error processing tag - $e');
            onResult(NfcScanResult.error('Error reading card: $e'));
          }
        },
        onError: (error) async {
          debugPrint('NFC: Session error - $error');
          onResult(NfcScanResult.error('NFC error: ${error.message}'));
        },
      );
    } catch (e) {
      _isScanning = false;
      debugPrint('NFC: Failed to start session - $e');
      onResult(NfcScanResult.error('Failed to start NFC: $e'));
    }
  }

  /// Stop scanning for NFC cards
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await NfcManager.instance.stopSession();
      _isScanning = false;
      debugPrint('NFC: Scanning stopped');
    } catch (e) {
      debugPrint('NFC: Error stopping session - $e');
    }
  }

  /// Extract card UID from NFC tag
  String? _extractCardUid(NfcTag tag) {
    try {
      // Try different tag types

      // NfcA (most common for MIFARE cards)
      final nfcA = NfcA.from(tag);
      if (nfcA != null) {
        return _bytesToHex(nfcA.identifier);
      }

      // NfcB
      final nfcB = NfcB.from(tag);
      if (nfcB != null) {
        return _bytesToHex(nfcB.identifier);
      }

      // NfcF (FeliCa)
      final nfcF = NfcF.from(tag);
      if (nfcF != null) {
        return _bytesToHex(nfcF.identifier);
      }

      // NfcV (ISO 15693)
      final nfcV = NfcV.from(tag);
      if (nfcV != null) {
        return _bytesToHex(nfcV.identifier);
      }

      // ISO-DEP
      final isoDep = IsoDep.from(tag);
      if (isoDep != null) {
        return _bytesToHex(isoDep.identifier);
      }

      // NDEF
      final ndef = Ndef.from(tag);
      if (ndef != null && ndef.additionalData['identifier'] != null) {
        return _bytesToHex(ndef.additionalData['identifier'] as List<int>);
      }

      debugPrint('NFC: Unknown tag type');
      return null;
    } catch (e) {
      debugPrint('NFC: Error extracting UID - $e');
      return null;
    }
  }

  /// Convert bytes to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
  }

  // =====================================================
  // API OPERATIONS
  // =====================================================

  /// Get customer by card UID
  Future<Customer?> getCustomerByCardUid(String cardUid) async {
    try {
      final response = await _apiService.getCustomerByCardUid(cardUid);
      if (response.isSuccess && response.data != null) {
        debugPrint('NFC: Found customer for card $cardUid');
        return response.data;
      }
      debugPrint('NFC: No customer found for card $cardUid');
      return null;
    } catch (e) {
      debugPrint('NFC: Error looking up customer - $e');
      return null;
    }
  }

  /// Register a new card for a customer
  Future<ApiResponse<CustomerCard>> registerCard({
    required int customerId,
    required String cardUid,
    String cardType = 'nfc',
  }) async {
    try {
      final response = await _apiService.registerCustomerCard(
        customerId: customerId,
        cardUid: cardUid,
        cardType: cardType,
      );
      return response;
    } catch (e) {
      debugPrint('NFC: Error registering card - $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Failed to register card: $e',
      );
    }
  }

  /// Unregister/deactivate a card
  Future<ApiResponse<void>> unregisterCard(int cardId) async {
    try {
      final response = await _apiService.unregisterCustomerCard(cardId);
      return response;
    } catch (e) {
      debugPrint('NFC: Error unregistering card - $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Failed to unregister card: $e',
      );
    }
  }

  /// Get all cards for a customer
  Future<ApiResponse<List<CustomerCard>>> getCustomerCards(int customerId) async {
    try {
      final response = await _apiService.getCustomerCards(customerId);
      return response;
    } catch (e) {
      debugPrint('NFC: Error getting customer cards - $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Failed to get cards: $e',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    stopScanning();
    _nfcController.close();
  }
}
