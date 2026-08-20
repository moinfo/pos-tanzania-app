import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sale.dart';
import '../services/api_service.dart';
import 'constants.dart';

/// Sending a sale receipt as a plain SMS.
///
/// Shared by the checkout success dialog and the sales history, so a customer
/// gets the same message whichever screen the seller sends it from.
class ReceiptSms {
  /// The order as plain text -- deliberately terse: past 160 characters most
  /// networks split the message into several charged parts, and a seller sends
  /// these all day.
  static String compose(Sale sale) {
    final money = NumberFormat('#,##0');
    final shop = ApiService.currentClient?.displayName ?? 'POS';
    final lines = <String>['$shop - Risiti #${sale.saleId}'];

    for (final item in sale.items ?? const <SaleItem>[]) {
      final qty = money.format(item.quantity);
      // Free lines carry a zero price; say so rather than printing "0".
      final amount =
          item.unitPrice == 0 ? 'BURE' : money.format(item.lineTotal);
      lines.add('${item.itemName} $qty x $amount');
    }

    lines.add('JUMLA: ${money.format(sale.total)} TSh');
    lines.add('Asante!');
    return lines.join('\n');
  }

  /// Hands the order to the phone's SMS app, pre-addressed to the customer.
  ///
  /// Deliberately the normal composer rather than a background send: the
  /// seller sees the text, can edit it, and it is charged to their own line
  /// as they expect.
  static Future<void> send(
    BuildContext context,
    Sale sale, {
    String? phone,
  }) async {
    final number = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    final body = Uri.encodeComponent(compose(sale));

    // iOS wants '&' to start the query, Android accepts '?'.
    final separator = Platform.isIOS ? '&' : '?';
    final uri = Uri.parse('sms:$number${separator}body=$body');

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw 'no SMS app';
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(number.isEmpty
              ? 'This customer has no phone number saved'
              : 'Could not open the SMS app'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }
}
