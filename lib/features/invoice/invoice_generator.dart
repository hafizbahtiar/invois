import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart' as signature_lib;

import 'package:invois/features/business/data/business_model.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:invois/features/invoice/invoice_model.dart';
import 'package:invois/features/invoice/pdf/pdf_fonts.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/signature/data/signature_model.dart';

/// Generates PDF invoices.
///
/// S5: a single [pw.MultiPage] flows content across pages automatically (the
/// items table splits and repeats its header row), replacing the previous
/// manual single-/multi-page pagination heuristics. Fonts are bundled
/// (offline-first) via [loadInvoiceFonts].
class InvoiceGenerator {
  /// Generate a PDF invoice from an invoice model.
  static Future<Uint8List> generateInvoice({
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    // Load bundled fonts (offline-first, R4) — no network fetch.
    final fonts = await loadInvoiceFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;
    final fontItalic = fonts.italic;

    // Prefer the canonical stored PNG (ADR-0004); fall back to rendering the
    // legacy JSON drawing points for rows captured before S4.
    final Uint8List? signatureImage =
        signature?.imageBytes ?? await _renderSignatureImage(signature);

    // Colors
    final primaryColor = PdfColors.blueGrey800;
    final accentColor = PdfColors.blue700;
    final lightColor = PdfColors.grey200;
    final darkColor = PdfColors.blueGrey900;

    // Text styles
    final titleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 24,
      color: primaryColor,
    );
    final headerStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 16,
      color: primaryColor,
    );
    final subheaderStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 12,
      color: darkColor,
    );
    final bodyStyle = pw.TextStyle(font: font, fontSize: 10, color: darkColor);
    final bodyBoldStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 10,
      color: darkColor,
    );
    final smallStyle = pw.TextStyle(
      font: font,
      fontSize: 8,
      color: PdfColors.grey600,
    );

    final dateFormat = DateFormat('MMM dd, yyyy');
    final issueDateStr = dateFormat.format(invoice.issueDate);
    final dueDateStr = dateFormat.format(invoice.dueDate);
    final businessAddress = business.streetAddress1;
    final clientAddress = client.streetAddress1;

    if (invoice.items.isEmpty) {
      throw Exception('Invoice must have at least one item');
    }

    final hasSignature = signature != null && signatureImage != null;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => _buildFooter(context, smallStyle),
        build: (context) => [
          _buildHeaderSection(
            invoice: invoice,
            business: business,
            businessAddress: businessAddress,
            issueDateStr: issueDateStr,
            dueDateStr: dueDateStr,
            titleStyle: titleStyle,
            headerStyle: headerStyle,
            bodyStyle: bodyStyle,
            bodyBoldStyle: bodyBoldStyle,
            accentColor: accentColor,
            fontBold: fontBold,
          ),
          pw.SizedBox(height: 20),
          _buildClientSection(
            client: client,
            clientAddress: clientAddress,
            invoice: invoice,
            subheaderStyle: subheaderStyle,
            bodyStyle: bodyStyle,
            bodyBoldStyle: bodyBoldStyle,
            lightColor: lightColor,
            dateFormat: dateFormat,
          ),
          pw.SizedBox(height: 15),
          _buildItemsTable(
            items: invoice.items.toList(),
            invoice: invoice,
            bodyStyle: bodyStyle,
            bodyBoldStyle: bodyBoldStyle,
            fontItalic: fontItalic,
            lightColor: lightColor,
          ),
          pw.SizedBox(height: 10),
          _buildTotalsSection(
            invoice: invoice,
            bodyStyle: bodyStyle,
            bodyBoldStyle: bodyBoldStyle,
          ),
          _buildNotesAndTermsSections(
            invoice: invoice,
            subheaderStyle: subheaderStyle,
            bodyStyle: bodyStyle,
            lightColor: lightColor,
          ),
          if (hasSignature)
            _buildSignatureSection(
              signature: signature,
              signatureImage: signatureImage,
              subheaderStyle: subheaderStyle,
              bodyStyle: bodyStyle,
              bodyBoldStyle: bodyBoldStyle,
            ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Render a stored signature's legacy JSON points into PNG bytes.
  ///
  /// Returns `null` when there is no signature, the data is empty, or it can't
  /// be parsed/rendered — so PDF generation degrades gracefully to "no
  /// signature image" instead of crashing.
  static Future<Uint8List?> _renderSignatureImage(Signature? signature) async {
    final data = signature?.signatureData;
    if (data == null || data.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(data);
      if (decoded is! List || decoded.isEmpty) return null;

      final points = decoded.map<signature_lib.Point>((point) {
        return signature_lib.Point(
          Offset(
            (point['dx'] as num).toDouble(),
            (point['dy'] as num).toDouble(),
          ),
          signature_lib.PointType.values[(point['type'] as int?) ?? 0],
          (point['pressure'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();

      if (points.isEmpty) return null;

      final controller = signature_lib.SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
        points: points,
      );
      try {
        return await controller.toPngBytes();
      } finally {
        controller.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeaderSection({
    required Invoice invoice,
    required Business business,
    required String? businessAddress,
    required String issueDateStr,
    required String dueDateStr,
    required pw.TextStyle titleStyle,
    required pw.TextStyle headerStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required PdfColor accentColor,
    required pw.Font fontBold,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(business.name, style: titleStyle),
            if (business.description != null &&
                business.description!.isNotEmpty)
              pw.Text(business.description!, style: bodyStyle),
            if (businessAddress != null)
              pw.Text(businessAddress, style: bodyStyle),
            pw.SizedBox(height: 4),
            if (business.email != null)
              pw.Text('Email: ${business.email}', style: bodyStyle),
            if (business.phone != null)
              pw.Text('Phone: ${business.phone}', style: bodyStyle),
            if (business.website != null)
              pw.Text('Web: ${business.website}', style: bodyStyle),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Issue Date:', style: bodyBoldStyle),
                    pw.Text('Due Date:', style: bodyBoldStyle),
                    if (invoice.reference != null)
                      pw.Text('Reference:', style: bodyBoldStyle),
                    pw.Text('Status:', style: bodyBoldStyle),
                  ],
                ),
                pw.SizedBox(width: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(issueDateStr, style: bodyStyle),
                    pw.Text(dueDateStr, style: bodyStyle),
                    if (invoice.reference != null)
                      pw.Text(invoice.reference!, style: bodyStyle),
                    pw.Text(invoice.statusDisplay, style: bodyStyle),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildClientSection({
    required Client client,
    required String? clientAddress,
    required Invoice invoice,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required PdfColor lightColor,
    required DateFormat dateFormat,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: lightColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILL TO', style: subheaderStyle),
                pw.SizedBox(height: 4),
                pw.Text(client.name, style: bodyBoldStyle),
                if (client.company != null && client.company!.isNotEmpty)
                  pw.Text(client.company!, style: bodyStyle),
                if (clientAddress != null)
                  pw.Text(clientAddress, style: bodyStyle),
                pw.SizedBox(height: 4),
                if (client.email != null)
                  pw.Text('Email: ${client.email}', style: bodyStyle),
                if (client.phone != null)
                  pw.Text('Phone: ${client.phone}', style: bodyStyle),
              ],
            ),
          ),
          if (invoice.isRecurring)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RECURRING DETAILS', style: subheaderStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Frequency: ${invoice.recurringFrequency}',
                    style: bodyStyle,
                  ),
                  if (invoice.recurringInterval != null)
                    pw.Text(
                      'Interval: ${invoice.recurringInterval}',
                      style: bodyStyle,
                    ),
                  if (invoice.recurringEndDate != null)
                    pw.Text(
                      'End Date: ${dateFormat.format(invoice.recurringEndDate!)}',
                      style: bodyStyle,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Items table that flows across pages in [pw.MultiPage]: the header row
  /// repeats on each page, and the table splits row-by-row.
  static pw.Widget _buildItemsTable({
    required List<Item> items,
    required Invoice invoice,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required pw.Font fontItalic,
    required PdfColor lightColor,
  }) {
    final currencySymbol =
        CurrencyUtils.currencies[invoice.currency]?.symbol ?? '';
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.grey300),
        bottom: pw.BorderSide(color: PdfColors.grey300),
        horizontalInside: pw.BorderSide(color: PdfColors.grey300),
      ),
      tableWidth: pw.TableWidth.max,
      columnWidths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: lightColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text('Description', style: bodyBoldStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'Qty',
                style: bodyBoldStyle,
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'Unit Price',
                style: bodyBoldStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'Amount',
                style: bodyBoldStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final quantity = item.stockQuantity ?? 1;
          final unitPriceStr =
              '$currencySymbol${(item.effectiveUnitPriceCents / 100).toStringAsFixed(2)}';
          final totalPriceStr =
              '$currencySymbol${(item.effectiveUnitPriceCents * quantity / 100).toStringAsFixed(2)}';
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index.isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.name, style: bodyStyle),
                    if (item.description != null &&
                        item.description!.isNotEmpty)
                      pw.Text(
                        item.description!,
                        style: pw.TextStyle(
                          font: fontItalic,
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  quantity.toString(),
                  style: bodyStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  unitPriceStr,
                  style: bodyStyle,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  totalPriceStr,
                  style: bodyStyle,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTotalsSection({
    required Invoice invoice,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
  }) {
    final currency = invoice.currency ?? 'MYR';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildTotalRow(
                'Subtotal',
                invoice.effectiveSubtotalCents,
                currency,
                bodyStyle,
                bodyBoldStyle,
              ),
              if (invoice.effectiveDiscountAmountCents > 0)
                _buildTotalRow(
                  'Discount ${invoice.discountRate > 0 ? '(${invoice.discountRate.toStringAsFixed(2)}%)' : ''}',
                  invoice.effectiveDiscountAmountCents,
                  currency,
                  bodyStyle,
                  bodyBoldStyle,
                  isDiscount: true,
                ),
              ...invoice.taxes.map((tax) {
                final taxableAmountCents =
                    invoice.effectiveSubtotalCents -
                    invoice.effectiveDiscountAmountCents;
                return _buildTotalRow(
                  '${tax.name} (${tax.rate.toStringAsFixed(2)}%)',
                  (taxableAmountCents * tax.rate / 100).round(),
                  currency,
                  bodyStyle,
                  bodyBoldStyle,
                );
              }),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              _buildTotalRow(
                'Total',
                invoice.effectiveTotalCents,
                currency,
                bodyBoldStyle.copyWith(fontSize: 14),
                bodyBoldStyle.copyWith(fontSize: 14),
              ),
              if (invoice.effectivePaidAmountCents > 0)
                _buildTotalRow(
                  'Paid',
                  invoice.effectivePaidAmountCents,
                  currency,
                  bodyStyle,
                  bodyBoldStyle,
                  isDiscount: true,
                ),
              if (invoice.effectivePaidAmountCents > 0)
                pw.Divider(color: PdfColors.grey400, thickness: 1),
              if (invoice.effectivePaidAmountCents > 0)
                _buildTotalRow(
                  'Balance Due',
                  invoice.effectiveBalanceDueCents,
                  currency,
                  bodyBoldStyle.copyWith(fontSize: 14, color: PdfColors.red700),
                  bodyBoldStyle.copyWith(fontSize: 14, color: PdfColors.red700),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNotesAndTermsSections({
    required Invoice invoice,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required PdfColor lightColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Notes', style: subheaderStyle),
                pw.SizedBox(height: 4),
                pw.Text(invoice.notes!, style: bodyStyle),
              ],
            ),
          ),
        ],
        if (invoice.terms.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Terms & Conditions', style: subheaderStyle),
                pw.SizedBox(height: 4),
                ...invoice.terms.map(
                  (term) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(term.content, style: bodyStyle),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildSignatureSection({
    required Signature signature,
    required Uint8List signatureImage,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('Authorized Signature', style: subheaderStyle),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 70,
          width: 200,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Image(
            pw.MemoryImage(signatureImage),
            fit: pw.BoxFit.contain,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(signature.name, style: bodyBoldStyle),
        if (signature.title != null)
          pw.Text(signature.title!, style: bodyStyle),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.TextStyle smallStyle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated with Invois',
                style: smallStyle.copyWith(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: smallStyle.copyWith(
                    color: PdfColors.white,
                    fontSize: 9,
                    font: pw.Font.helveticaBold(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(
    String label,
    int amountCents,
    String currencyCode,
    pw.TextStyle labelStyle,
    pw.TextStyle amountStyle, {
    bool isDiscount = false,
  }) {
    final currencySymbol = CurrencyUtils.currencies[currencyCode]?.symbol ?? '';
    final amount = amountCents / 100;
    final amountStr = isDiscount
        ? '-$currencySymbol${amount.toStringAsFixed(2)}'
        : '$currencySymbol${amount.toStringAsFixed(2)}';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: labelStyle),
          pw.Text(amountStr, style: amountStyle),
        ],
      ),
    );
  }

  /// Preview the invoice in a Flutter widget.
  static Widget previewInvoice({
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) {
    return PdfPreview(
      enableScrollToPage: true,
      build: (format) => generateInvoice(
        invoice: invoice,
        business: business,
        client: client,
        signature: signature,
        pageFormat: format,
      ),
      initialPageFormat: pageFormat,
      allowPrinting: false,
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
    );
  }

  /// Print the invoice.
  static Future<void> printInvoice({
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final pdfData = await generateInvoice(
      invoice: invoice,
      business: business,
      client: client,
      signature: signature,
      pageFormat: pageFormat,
    );
    await Printing.layoutPdf(
      onLayout: (_) => pdfData,
      format: pageFormat,
      name: '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
    );
  }

  /// Share the invoice via the OS share sheet.
  static Future<void> shareInvoice({
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final pdfData = await generateInvoice(
      invoice: invoice,
      business: business,
      client: client,
      signature: signature,
      pageFormat: pageFormat,
    );
    await Printing.sharePdf(
      bytes: pdfData,
      filename:
          '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}.pdf',
    );
  }

  /// Save the invoice to a file on disk and return the absolute file path.
  static Future<String> saveInvoice({
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final pdfData = await generateInvoice(
      invoice: invoice,
      business: business,
      client: client,
      signature: signature,
      pageFormat: pageFormat,
    );
    final filename =
        '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}.pdf';
    Directory? directory;
    try {
      directory = await getDownloadsDirectory();
    } catch (_) {
      directory = null;
    }
    directory ??= await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, filename));
    await file.writeAsBytes(pdfData);
    return file.path;
  }
}
