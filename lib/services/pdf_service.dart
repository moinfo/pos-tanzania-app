import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/suspended_sheet.dart';
import '../models/suspended_sheet2.dart';
import '../models/suspended_sheet3.dart';
import '../models/sale.dart';

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
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(companyName, companyAddress, companyPhone),
              pw.SizedBox(height: 24),

              // Title with decorative line
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.red700, width: 4),
                    bottom: pw.BorderSide(color: PdfColors.red700, width: 4),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'SUSPENDED SALE RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Customer Info
              _buildCustomerInfo(sale),
              pw.SizedBox(height: 24),

              // Items Table
              _buildItemsTable(sale),
              pw.SizedBox(height: 24),

              // Total
              _buildTotal(sale),
              pw.SizedBox(height: 20),

              // Date and items summary
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Items: ${sale.items.length}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Date: ${sale.formattedTime}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
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
            companyName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        if (companyAddress != null && companyAddress.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              companyAddress,
              style: const pw.TextStyle(fontSize: 18),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (companyPhone != null && companyPhone.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              'Tel: $companyPhone',
              style: const pw.TextStyle(fontSize: 18),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(SuspendedSheetSale sale) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.red200, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 48,
                height: 48,
                decoration: pw.BoxDecoration(
                  color: PdfColors.red700,
                  borderRadius: pw.BorderRadius.circular(24),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${sale.saleId}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sale.customerName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Text(
                          'Phone: 0${sale.customerPhone}',
                          style: const pw.TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (sale.comment != null && sale.comment!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 14),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.amber, width: 5)),
                ),
                child: pw.Text(
                  'Comment: ${sale.comment}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(SuspendedSheetSale sale) {
    return pw.Table(
      border: pw.TableBorder(
        left: pw.BorderSide(color: PdfColors.grey500, width: 2),
        right: pw.BorderSide(color: PdfColors.grey500, width: 2),
        top: pw.BorderSide(color: PdfColors.grey500, width: 2),
        bottom: pw.BorderSide(color: PdfColors.grey500, width: 2),
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(45),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(110),
        4: const pw.FixedColumnWidth(120),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.red700),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Item Name', isHeader: true),
            _tableCell('Qty', isHeader: true, align: pw.TextAlign.center),
            _tableCell('Unit Price', isHeader: true, align: pw.TextAlign.right),
            _tableCell('Total', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Data rows with alternating colors
        ...sale.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isEvenRow = idx % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEvenRow ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _tableCell('${idx + 1}'),
              _tableCell(item.itemName),
              _tableCell(item.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 17 : 18,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTotal(SuspendedSheetSale sale) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        decoration: pw.BoxDecoration(
          color: PdfColors.red700,
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'TOTAL: ',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.Text(
              '${_currencyFormat.format(sale.saleTotal)} TSh',
              style: pw.TextStyle(
                fontSize: 28,
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
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 2),
        borderRadius: pw.BorderRadius.circular(12),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'CONFIRMATION / UTHIBITISHO',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 20),

          // Swahili instruction
          pw.Text(
            'Kama Mzigo uliopokea ni Sahihi saini hapa',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '(If goods received are correct, sign below)',
            style: pw.TextStyle(
              fontSize: 16,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 28),

          // Receiver Name field
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Receiver Name / Jina la Mpokezi: ',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 2)),
                  ),
                  height: 32,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Signature field
          pw.Text(
            'Signature / Sahihi:',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            height: 90,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 24),

          // Date field
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Date / Tarehe: ',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Container(
                width: 180,
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 2)),
                ),
                height: 32,
              ),
            ],
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

  // ============================================================
  // SHEET2 - DELIVERY SHEET (No prices, with Free column)
  // ============================================================

  /// Generate PDF document for Sheet2 (Delivery Sheet - no prices)
  static Future<Uint8List> generateSheet2Pdf(
    SuspendedSheet2Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(companyName ?? 'DELIVERY SHEET', companyAddress, companyPhone),
              pw.SizedBox(height: 24),

              // Title
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.blue700, width: 4),
                    bottom: pw.BorderSide(color: PdfColors.blue700, width: 4),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'DELIVERY SHEET',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Customer Info
              _buildSheet2CustomerInfo(sale),
              pw.SizedBox(height: 24),

              // Items Table (no prices)
              _buildSheet2ItemsTable(sale),
              pw.SizedBox(height: 24),

              // Total quantity
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Text(
                    'TOTAL: ${sale.totalQuantity.toStringAsFixed(0)} pcs',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Date and items summary
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Items: ${sale.items.length}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Date: ${sale.formattedTime}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
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

  static pw.Widget _buildSheet2CustomerInfo(SuspendedSheet2Sale sale) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.blue200, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 48,
                height: 48,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(24),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${sale.saleId}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sale.customerName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Text(
                          'Phone: 0${sale.customerPhone}',
                          style: const pw.TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (sale.comment != null && sale.comment!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 14),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.amber, width: 5)),
                ),
                child: pw.Text(
                  'Comment: ${sale.comment}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSheet2ItemsTable(SuspendedSheet2Sale sale) {
    return pw.Table(
      border: pw.TableBorder(
        left: pw.BorderSide(color: PdfColors.grey500, width: 2),
        right: pw.BorderSide(color: PdfColors.grey500, width: 2),
        top: pw.BorderSide(color: PdfColors.grey500, width: 2),
        bottom: pw.BorderSide(color: PdfColors.grey500, width: 2),
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(50),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FixedColumnWidth(80),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Item Name', isHeader: true),
            _tableCell('Qty', isHeader: true, align: pw.TextAlign.center),
            _tableCell('Free', isHeader: true, align: pw.TextAlign.center),
          ],
        ),
        // Data rows
        ...sale.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isEvenRow = idx % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEvenRow ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _tableCell('${idx + 1}'),
              _tableCell(item.itemName),
              _tableCell(item.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
              item.freeQuantity > 0
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          '${item.freeQuantity}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    )
                  : _tableCell('-', align: pw.TextAlign.center),
            ],
          );
        }),
      ],
    );
  }

  /// Print Sheet2 directly
  static Future<void> printSheet2(
    SuspendedSheet2Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSheet2Pdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Delivery_Sheet_${sale.saleId}_${sale.customerName}',
    );
  }

  /// Share Sheet2 PDF
  static Future<void> shareSheet2Pdf(
    SuspendedSheet2Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSheet2Pdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Delivery_Sheet_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Download Sheet2 PDF
  static Future<void> downloadSheet2Pdf(
    SuspendedSheet2Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSheet2Pdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Delivery_Sheet_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ============================================================
  // SHEET3 - RECEIPT SHEET (With prices and Free column)
  // ============================================================

  /// Generate PDF document for Sheet3 (Receipt with prices + free items)
  static Future<Uint8List> generateSheet3Pdf(
    SuspendedSheet3Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(companyName ?? 'RECEIPT SHEET', companyAddress, companyPhone),
              pw.SizedBox(height: 24),

              // Title
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.green700, width: 4),
                    bottom: pw.BorderSide(color: PdfColors.green700, width: 4),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'RECEIPT SHEET',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Customer Info
              _buildSheet3CustomerInfo(sale),
              pw.SizedBox(height: 24),

              // Items Table (with prices and free)
              _buildSheet3ItemsTable(sale),
              pw.SizedBox(height: 24),

              // Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green700,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'TOTAL: ',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        '${_currencyFormat.format(sale.saleTotal)} TSh',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Date and items summary
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Items: ${sale.items.length}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Date: ${sale.formattedTime}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
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

  static pw.Widget _buildSheet3CustomerInfo(SuspendedSheet3Sale sale) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.green200, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 48,
                height: 48,
                decoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                  borderRadius: pw.BorderRadius.circular(24),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${sale.saleId}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sale.customerName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Text(
                          'Phone: 0${sale.customerPhone}',
                          style: const pw.TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (sale.comment != null && sale.comment!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 14),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.amber, width: 5)),
                ),
                child: pw.Text(
                  'Comment: ${sale.comment}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSheet3ItemsTable(SuspendedSheet3Sale sale) {
    return pw.Table(
      border: pw.TableBorder(
        left: pw.BorderSide(color: PdfColors.grey500, width: 2),
        right: pw.BorderSide(color: PdfColors.grey500, width: 2),
        top: pw.BorderSide(color: PdfColors.grey500, width: 2),
        bottom: pw.BorderSide(color: PdfColors.grey500, width: 2),
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(55),
        3: const pw.FixedColumnWidth(55),
        4: const pw.FixedColumnWidth(90),
        5: const pw.FixedColumnWidth(100),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green700),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Item', isHeader: true),
            _tableCell('Qty', isHeader: true, align: pw.TextAlign.center),
            _tableCell('Free', isHeader: true, align: pw.TextAlign.center),
            _tableCell('Price', isHeader: true, align: pw.TextAlign.right),
            _tableCell('Total', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Data rows
        ...sale.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isEvenRow = idx % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEvenRow ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _tableCell('${idx + 1}'),
              _tableCell(item.itemName),
              _tableCell(item.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
              item.freeQuantity > 0
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(
                          '${item.freeQuantity}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    )
                  : _tableCell('-', align: pw.TextAlign.center),
              _tableCell(_currencyFormat.format(item.unitPrice), align: pw.TextAlign.right),
              _tableCell(_currencyFormat.format(item.lineTotal), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  /// Print Sheet3 directly
  static Future<void> printSheet3(
    SuspendedSheet3Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSheet3Pdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Receipt_Sheet_${sale.saleId}_${sale.customerName}',
    );
  }

  /// Share Sheet3 PDF
  static Future<void> shareSheet3Pdf(
    SuspendedSheet3Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSheet3Pdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Receipt_Sheet_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Download Sheet3 PDF
  static Future<void> downloadSheet3Pdf(
    SuspendedSheet3Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    final pdfData = await generateSheet3Pdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Receipt_Sheet_${sale.saleId}_${sale.customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ============================================================
  // COMPLETED SALE RECEIPT
  // ============================================================

  /// Generate PDF receipt for a completed sale
  static Future<Uint8List> generateSaleReceiptPdf(
    Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    // NFC payment info
    double? nfcAmountUsed,
    double? nfcBalanceAfter,
    String? nfcCardUid,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              children: [
                // Header
                _buildHeader(companyName, companyAddress, companyPhone),
                pw.SizedBox(height: 24),

                // Title
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 18),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.green700, width: 4),
                      bottom: pw.BorderSide(color: PdfColors.green700, width: 4),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'SALES RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 42,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),

                // Sale Info
                _buildSaleReceiptInfo(sale, dateFormat),
                pw.SizedBox(height: 24),
              ],
            );
          }
          // For subsequent pages, show a simple header
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SALES RECEIPT #${sale.saleId}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Page ${context.pageNumber}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Items Table
            _buildSaleReceiptItemsTable(sale),
            pw.SizedBox(height: 24),

            // Totals
            _buildSaleReceiptTotals(sale),
            pw.SizedBox(height: 20),

            // Payments
            if (sale.payments != null && sale.payments!.isNotEmpty) ...[
              pw.Text(
                'Payment Details',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildSaleReceiptPayments(sale),
            ],
            pw.SizedBox(height: 24),

            // NFC Card Payment Info
            if (nfcAmountUsed != null && nfcAmountUsed > 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.orange200, width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 32,
                          height: 32,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.orange700,
                            borderRadius: pw.BorderRadius.circular(16),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'NFC',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text(
                          'NFC Card Payment',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(color: PdfColors.orange200),
                    pw.SizedBox(height: 12),
                    if (nfcCardUid != null)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Card UID:', style: const pw.TextStyle(fontSize: 18)),
                          pw.Text(
                            nfcCardUid,
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Amount Deducted:', style: const pw.TextStyle(fontSize: 18)),
                        pw.Text(
                          'TZS ${NumberFormat('#,##0').format(nfcAmountUsed)}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                    if (nfcBalanceAfter != null) ...[
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Remaining Balance:', style: const pw.TextStyle(fontSize: 18)),
                          pw.Text(
                            'TZS ${NumberFormat('#,##0').format(nfcBalanceAfter)}',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Receipt #${sale.saleId} - ${dateFormat.format(DateTime.parse(sale.saleTime))}',
                    style: const pw.TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSaleReceiptInfo(Sale sale, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.green200, width: 2),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              color: PdfColors.green700,
              borderRadius: pw.BorderRadius.circular(30),
            ),
            child: pw.Center(
              child: pw.Text(
                '#${sale.saleId}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  sale.customerName ?? 'Walk-in Customer',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Date: ${dateFormat.format(DateTime.parse(sale.saleTime))}',
                  style: const pw.TextStyle(fontSize: 20),
                ),
                if (sale.employeeName != null)
                  pw.Text(
                    'Served by: ${sale.employeeName}',
                    style: const pw.TextStyle(fontSize: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSaleReceiptItemsTable(Sale sale) {
    if (sale.items == null || sale.items!.isEmpty) {
      return pw.Container();
    }

    return pw.Table(
      border: pw.TableBorder(
        left: pw.BorderSide(color: PdfColors.grey500, width: 2),
        right: pw.BorderSide(color: PdfColors.grey500, width: 2),
        top: pw.BorderSide(color: PdfColors.grey500, width: 2),
        bottom: pw.BorderSide(color: PdfColors.grey500, width: 2),
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 1),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(50),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(110),
        4: const pw.FixedColumnWidth(120),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green700),
          children: [
            _tableCellLarge('#', isHeader: true),
            _tableCellLarge('Item', isHeader: true),
            _tableCellLarge('Qty', isHeader: true, align: pw.TextAlign.center),
            _tableCellLarge('Price', isHeader: true, align: pw.TextAlign.right),
            _tableCellLarge('Total', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Data rows
        ...sale.items!.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isEvenRow = idx % 2 == 0;
          final isFreeItem = item.quantityOfferFree == true;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isFreeItem
                  ? PdfColors.green100
                  : (isEvenRow ? PdfColors.white : PdfColors.grey100),
            ),
            children: [
              _tableCellLarge('${idx + 1}'),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.itemName,
                      style: const pw.TextStyle(fontSize: 20),
                    ),
                    if (isFreeItem)
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 6),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          'FREE OFFER',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _tableCellLarge(item.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
              _tableCellLarge(_currencyFormat.format(item.unitPrice), align: pw.TextAlign.right),
              _tableCellLarge(_currencyFormat.format(item.lineTotal), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  // Large table cell for sale receipts
  static pw.Widget _tableCellLarge(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 18 : 20,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSaleReceiptTotals(Sale sale) {
    final hasDiscount = sale.items?.any((item) => item.discount > 0) ?? false;
    final totalDiscount = sale.items?.fold<double>(0, (sum, item) => sum + item.discount) ?? 0;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 320,
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey400, width: 1),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 20)),
                pw.Text('${_currencyFormat.format(sale.subtotal)} TSh', style: const pw.TextStyle(fontSize: 20)),
              ],
            ),
            if (hasDiscount) ...[
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount:', style: pw.TextStyle(fontSize: 20, color: PdfColors.red700)),
                  pw.Text('-${_currencyFormat.format(totalDiscount)} TSh', style: pw.TextStyle(fontSize: 20, color: PdfColors.red700)),
                ],
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Tax:', style: const pw.TextStyle(fontSize: 20)),
                pw.Text('${_currencyFormat.format(sale.taxTotal)} TSh', style: const pw.TextStyle(fontSize: 20)),
              ],
            ),
            pw.Divider(height: 20, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${_currencyFormat.format(sale.total)} TSh',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSaleReceiptPayments(Sale sale) {
    if (sale.payments == null || sale.payments!.isEmpty) {
      return pw.Container();
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: sale.payments!.map((payment) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(payment.paymentType, style: const pw.TextStyle(fontSize: 20)),
                pw.Text(
                  '${_currencyFormat.format(payment.amount)} TSh',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Print completed sale receipt directly
  static Future<void> printSaleReceipt(
    Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    double? nfcAmountUsed,
    double? nfcBalanceAfter,
    String? nfcCardUid,
  }) async {
    final pdfData = await generateSaleReceiptPdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      nfcAmountUsed: nfcAmountUsed,
      nfcBalanceAfter: nfcBalanceAfter,
      nfcCardUid: nfcCardUid,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Sale_Receipt_${sale.saleId}',
    );
  }

  /// Share completed sale receipt PDF
  static Future<void> shareSaleReceiptPdf(
    Sale sale, {
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    double? nfcAmountUsed,
    double? nfcBalanceAfter,
    String? nfcCardUid,
  }) async {
    final pdfData = await generateSaleReceiptPdf(
      sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      nfcAmountUsed: nfcAmountUsed,
      nfcBalanceAfter: nfcBalanceAfter,
      nfcCardUid: nfcCardUid,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Sale_Receipt_${sale.saleId}.pdf',
    );
  }

  /// Generate PDF for NFC deposit receipt
  static Future<Uint8List> generateNfcDepositReceiptPdf({
    required String customerName,
    required String cardUid,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
    String? description,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? employeeName,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );

    final dateFormat = DateFormat('dd MMM yyyy HH:mm:ss');
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Company Header
              if (companyName != null)
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (companyAddress != null)
                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8)),
              if (companyPhone != null)
                pw.Text('Tel: $companyPhone', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),

              // Title
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 1),
                    bottom: pw.BorderSide(width: 1),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'NFC WALLET DEPOSIT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Date & Time
              pw.Text(
                dateFormat.format(now),
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 8),

              // Customer Info
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildReceiptRow('Customer:', customerName),
                    _buildReceiptRow('Card UID:', cardUid),
                    if (description != null && description.isNotEmpty)
                      _buildReceiptRow('Note:', description),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Divider
              pw.Container(
                width: double.infinity,
                height: 1,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 8),

              // Amount Details
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  children: [
                    _buildReceiptRow('Previous Balance:', 'TZS ${_currencyFormat.format(balanceBefore)}'),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '+ TZS ${_currencyFormat.format(amount)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    _buildReceiptRow('New Balance:', 'TZS ${_currencyFormat.format(balanceAfter)}',
                        isBold: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Divider
              pw.Container(
                width: double.infinity,
                height: 1,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 8),

              // New Balance Highlight
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'CURRENT BALANCE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'TZS ${_currencyFormat.format(balanceAfter)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Footer
              if (employeeName != null)
                pw.Text(
                  'Served by: $employeeName',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Thank you for your deposit!',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Print NFC deposit receipt
  static Future<void> printNfcDepositReceipt({
    required String customerName,
    required String cardUid,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
    String? description,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? employeeName,
  }) async {
    final pdfData = await generateNfcDepositReceiptPdf(
      customerName: customerName,
      cardUid: cardUid,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: description,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      employeeName: employeeName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'NFC_Deposit_Receipt',
    );
  }

  /// Share NFC deposit receipt
  static Future<void> shareNfcDepositReceipt({
    required String customerName,
    required String cardUid,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
    String? description,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? employeeName,
  }) async {
    final pdfData = await generateNfcDepositReceiptPdf(
      customerName: customerName,
      cardUid: cardUid,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: description,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      employeeName: employeeName,
    );

    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'NFC_Deposit_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }
}
