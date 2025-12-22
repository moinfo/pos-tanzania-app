import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/suspended_sheet.dart';

class PdfService {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  // Cache the font to avoid loading it multiple times
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  /// Load Unicode-compatible fonts
  static Future<void> _loadFonts() async {
    if (_regularFont == null || _boldFont == null) {
      // Use Roboto from Google Fonts (supports Unicode/Swahili)
      _regularFont = await PdfGoogleFonts.robotoRegular();
      _boldFont = await PdfGoogleFonts.robotoBold();
    }
  }

  /// Generate PDF document for a suspended sale
  static Future<Uint8List> generateSuspendedSalePdf(
    SuspendedSheetSale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    // Load Unicode fonts
    await _loadFonts();

    final pdf = pw.Document();

    // Create theme with Unicode fonts
    final theme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(companyName, companyAddress, companyPhone),
              pw.SizedBox(height: 20),

              // Title
              pw.Center(
                child: pw.Text(
                  'SUSPENDED SALE RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Customer Info
              _buildCustomerInfo(sale),
              pw.SizedBox(height: 20),

              // Items Table
              _buildItemsTable(sale),
              pw.SizedBox(height: 20),

              // Total
              _buildTotal(sale),
              pw.SizedBox(height: 30),

              // Date
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date: ${sale.formattedTime}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Signature Section
              _buildSignatureSection(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String? companyName, String? companyAddress, String? companyPhone) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (companyName != null && companyName.isNotEmpty)
          pw.Text(
            companyName,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        if (companyAddress != null && companyAddress.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              companyAddress,
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (companyPhone != null && companyPhone.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Tel: $companyPhone',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(SuspendedSheetSale sale) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.red100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${sale.saleId}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sale.customerName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Phone: 0${sale.customerPhone}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (sale.comment != null && sale.comment!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'Comment: ${sale.comment}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(SuspendedSheetSale sale) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(90),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Item', isHeader: true),
            _tableCell('Qty', isHeader: true, align: pw.TextAlign.right),
            _tableCell('Price', isHeader: true, align: pw.TextAlign.right),
            _tableCell('Total', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Data rows
        ...sale.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _tableCell('${idx + 1}'),
              _tableCell(item.itemName),
              _tableCell(item.quantity.toStringAsFixed(0), align: pw.TextAlign.right),
              _tableCell(_currencyFormat.format(item.unitPrice), align: pw.TextAlign.right),
              _tableCell(_currencyFormat.format(item.lineTotal), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTotal(SuspendedSheetSale sale) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.red700,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'TOTAL: ',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.Text(
              '${_currencyFormat.format(sale.saleTotal)} TSh',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSignatureSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Kama Mzigo uliopokea ni Sahihi saini hapa',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Text(
                'Receiver Name: ',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Expanded(
                child: pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
                  ),
                  height: 20,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Signature:',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 50,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
          ),
        ],
      ),
    );
  }

  /// Print the suspended sale directly
  static Future<void> printSuspendedSale(
    SuspendedSheetSale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSuspendedSalePdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Suspended_Sale_${sale.saleId}_${sale.customerName}',
    );
  }

  /// Preview PDF (shows print dialog with preview)
  static Future<void> previewPdf(
    SuspendedSheetSale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSuspendedSalePdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Suspended_Sale_${sale.saleId}_${sale.customerName}',
    );
  }

  /// Save PDF to device and return file path
  static Future<String> savePdfToDevice(
    SuspendedSheetSale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSuspendedSalePdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'Suspended_Sale_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfData);

    return file.path;
  }

  /// Download PDF (save and share for user to save in their preferred location)
  static Future<void> downloadPdf(
    SuspendedSheetSale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    // Use sharePdf from printing package instead - it handles iOS positioning automatically
    final pdfData = await generateSuspendedSalePdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Suspended_Sale_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Share PDF via share sheet
  static Future<void> sharePdf(
    SuspendedSheetSale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSuspendedSalePdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Suspended_Sale_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}.pdf',
    );
  }
}
