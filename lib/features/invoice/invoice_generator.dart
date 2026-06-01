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

import 'package:invois/features/business/business_model.dart';
import 'package:invois/features/client/client_model.dart';
import 'package:invois/features/invoice/invoice_model.dart';
import 'package:invois/features/signature/signature_model.dart';

/// A class responsible for generating PDF invoices
class InvoiceGenerator {
  /// Generate a PDF invoice from an invoice model
  static Future<Uint8List> generateInvoice({
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    // Load fonts
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // Create PDF document
    final pdf = pw.Document();

    // Prefer the canonical stored PNG (ADR-0004); fall back to rendering the
    // legacy JSON drawing points for rows captured before S4. Computed up-front
    // so the (synchronous) page builders can embed real image data.
    final Uint8List? signatureImage =
        signature?.imageBytes ?? await _renderSignatureImage(signature);

    // Define colors
    final primaryColor = PdfColors.blueGrey800;
    final accentColor = PdfColors.blue700;
    final lightColor = PdfColors.grey200;
    final darkColor = PdfColors.blueGrey900;
    final successColor = PdfColors.green700;
    final warningColor = PdfColors.orange700;

    // Define text styles
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

    // Format dates
    final dateFormat = DateFormat('MMM dd, yyyy');
    final issueDateStr = dateFormat.format(invoice.issueDate);
    final dueDateStr = dateFormat.format(invoice.dueDate);

    // Get addresses
    final businessAddress = business.streetAddress1;
    final clientAddress = client.streetAddress1;

    // Validate required data
    if (invoice.items.isEmpty) {
      throw Exception('Invoice must have at least one item');
    }

    // Improved pagination logic - more conservative estimate to avoid overflow
    final totalItems = invoice.items.length;
    final estimatedItemsPerPage = _estimateItemsPerPage(invoice);
    final hasComplexTerms =
        invoice.terms.length > 2 ||
        (invoice.terms.isNotEmpty &&
            invoice.terms.any((term) => term.content.length > 100));

    // Enhanced multi-page logic considering items, terms, and taxes
    final totalTerms = invoice.terms.length;
    final totalTaxes = invoice.items.length;

    final needsMultiplePages =
        totalItems > estimatedItemsPerPage ||
        totalItems > 8 && hasComplexTerms ||
        totalTerms > 3 ||
        totalTaxes > 5 ||
        (totalItems > 6 && totalTerms > 2) ||
        (totalItems > 4 && totalTaxes > 3);

    if (needsMultiplePages) {
      // Generate multi-page invoice with improved content distribution
      await _generateImprovedMultiPageInvoice(
        pdf: pdf,
        invoice: invoice,
        business: business,
        client: client,
        signature: signature,
        signatureImage: signatureImage,
        pageFormat: pageFormat,
        font: font,
        fontBold: fontBold,
        fontItalic: fontItalic,
        titleStyle: titleStyle,
        headerStyle: headerStyle,
        subheaderStyle: subheaderStyle,
        bodyStyle: bodyStyle,
        bodyBoldStyle: bodyBoldStyle,
        smallStyle: smallStyle,
        primaryColor: primaryColor,
        accentColor: accentColor,
        lightColor: lightColor,
        darkColor: darkColor,
        successColor: successColor,
        warningColor: warningColor,
        issueDateStr: issueDateStr,
        dueDateStr: dueDateStr,
        businessAddress: businessAddress,
        clientAddress: clientAddress,
        estimatedItemsPerPage: estimatedItemsPerPage,
        hasComplexTerms: hasComplexTerms,
      );
    } else {
      // Generate single page invoice
      await _generateSinglePageInvoice(
        pdf: pdf,
        invoice: invoice,
        business: business,
        client: client,
        signature: signature,
        signatureImage: signatureImage,
        pageFormat: pageFormat,
        font: font,
        fontBold: fontBold,
        fontItalic: fontItalic,
        titleStyle: titleStyle,
        headerStyle: headerStyle,
        subheaderStyle: subheaderStyle,
        bodyStyle: bodyStyle,
        bodyBoldStyle: bodyBoldStyle,
        smallStyle: smallStyle,
        primaryColor: primaryColor,
        accentColor: accentColor,
        lightColor: lightColor,
        darkColor: darkColor,
        successColor: successColor,
        warningColor: warningColor,
        issueDateStr: issueDateStr,
        dueDateStr: dueDateStr,
        businessAddress: businessAddress,
        clientAddress: clientAddress,
      );
    }

    // Return the PDF document as bytes
    return pdf.save();
  }

  /// Render a stored signature into PNG bytes.
  ///
  /// Signatures are persisted as a JSON list of drawing points
  /// (`[{dx, dy, type, pressure}, ...]`). This rebuilds a [SignatureController]
  /// from those points and exports a PNG so it can be embedded in the PDF.
  ///
  /// Returns `null` when there is no signature, the data is empty, or it can't be
  /// parsed/rendered (e.g. legacy or corrupt data) so PDF generation degrades
  /// gracefully to "no signature image" instead of crashing.
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
      // Legacy/corrupt/non-JSON signature data — skip the image.
      return null;
    }
  }

  /// More conservative estimation of items per page
  static int _estimateItemsPerPage(Invoice invoice) {
    // More conservative base estimation
    int baseItems = 10;

    // Account for item description complexity more accurately
    for (final item in invoice.items) {
      if (item.description != null) {
        if (item.description!.length > 200) {
          baseItems -= 3; // Very long descriptions
        } else if (item.description!.length > 100) {
          baseItems -= 2; // Medium-long descriptions
        } else if (item.description!.length > 50) {
          baseItems -= 1; // Somewhat long descriptions
        }
      }
    }

    // More conservative adjustments for additional content
    if (invoice.notes != null && invoice.notes!.isNotEmpty) {
      if (invoice.notes!.length > 200) {
        baseItems -= 4;
      } else if (invoice.notes!.length > 100) {
        baseItems -= 3;
      } else {
        baseItems -= 2;
      }
    }

    // More conservative adjustment for terms
    if (invoice.terms.isNotEmpty) {
      // Each term takes space
      baseItems -= invoice.terms.length;

      // Long terms take even more space
      for (final term in invoice.terms) {
        if (term.content.length > 100) {
          baseItems -= 1;
        }
      }
    }

    // Ensure a safer minimum/maximum
    return baseItems.clamp(6, 12);
  }

  /// Generate single page invoice for shorter lists
  static Future<void> _generateSinglePageInvoice({
    required pw.Document pdf,
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    Uint8List? signatureImage,
    required PdfPageFormat pageFormat,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.TextStyle titleStyle,
    required pw.TextStyle headerStyle,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required pw.TextStyle smallStyle,
    required PdfColor primaryColor,
    required PdfColor accentColor,
    required PdfColor lightColor,
    required PdfColor darkColor,
    required PdfColor successColor,
    required PdfColor warningColor,
    required String issueDateStr,
    required String dueDateStr,
    required String? businessAddress,
    required String? clientAddress,
  }) async {
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section with reduced spacing
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

              pw.SizedBox(height: 20), // Reduced from 30
              // Client information with compact layout
              _buildCompactClientSection(
                client: client,
                clientAddress: clientAddress,
                invoice: invoice,
                subheaderStyle: subheaderStyle,
                bodyStyle: bodyStyle,
                bodyBoldStyle: bodyBoldStyle,
                lightColor: lightColor,
                dateFormat: DateFormat('MMM dd, yyyy'),
              ),

              pw.SizedBox(height: 15), // Reduced from 20
              // Items table with responsive sizing
              _buildResponsiveItemsTable(
                items: invoice.items,
                invoice: invoice,
                bodyStyle: bodyStyle,
                bodyBoldStyle: bodyBoldStyle,
                fontItalic: fontItalic,
                lightColor: lightColor,
                showContinuation: false,
              ),

              pw.SizedBox(height: 8), // Reduced from 10
              // Totals section
              _buildTotalsSection(
                invoice: invoice,
                bodyStyle: bodyStyle,
                bodyBoldStyle: bodyBoldStyle,
              ),

              pw.SizedBox(height: 8), // Reduced from 10
              // Notes and Terms sections with compact layout
              _buildCompactNotesAndTermsSections(
                invoice: invoice,
                subheaderStyle: subheaderStyle,
                bodyStyle: bodyStyle,
                lightColor: lightColor,
              ),

              // Signature section with reduced spacing
              if (signature != null && signatureImage != null) ...[
                pw.SizedBox(height: 15), // Reduced from 20
                _buildCompactSignatureSection(
                  signature: signature,
                  signatureImage: signatureImage,
                  subheaderStyle: subheaderStyle,
                  bodyStyle: bodyStyle,
                  bodyBoldStyle: bodyBoldStyle,
                ),
              ],

              // Footer
              pw.Expanded(child: pw.SizedBox()),
              _buildFooter(context, smallStyle),
            ],
          );
        },
      ),
    );
  }

  /// Generate improved multi-page invoice with better content distribution
  static Future<void> _generateImprovedMultiPageInvoice({
    required pw.Document pdf,
    required Invoice invoice,
    required Business business,
    required Client client,
    Signature? signature,
    Uint8List? signatureImage,
    required PdfPageFormat pageFormat,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.TextStyle titleStyle,
    required pw.TextStyle headerStyle,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required pw.TextStyle smallStyle,
    required PdfColor primaryColor,
    required PdfColor accentColor,
    required PdfColor lightColor,
    required PdfColor darkColor,
    required PdfColor successColor,
    required PdfColor warningColor,
    required String issueDateStr,
    required String dueDateStr,
    required String? businessAddress,
    required String? clientAddress,
    required int estimatedItemsPerPage,
    required bool hasComplexTerms,
  }) async {
    final totalItems = invoice.items.length;
    // ignore: unused_local_variable
    final hasNotes = invoice.notes != null && invoice.notes!.isNotEmpty;
    final hasTerms = invoice.terms.isNotEmpty;
    final hasSignature = signature != null && signatureImage != null;

    // More conservative first page item count to leave room for header content
    int firstPageItems = estimatedItemsPerPage - 3;

    // For complex terms, reserve even less space for items on first page
    if (hasComplexTerms) {
      firstPageItems = (estimatedItemsPerPage / 2).floor();
    }

    // Ensure we show at least some items on first page, but not too many
    firstPageItems = firstPageItems.clamp(3, estimatedItemsPerPage - 2);

    // Place terms on a separate page if they're complex
    bool placeTermsOnSeparatePage =
        hasComplexTerms ||
        (hasTerms && invoice.terms.length > 2) ||
        (totalItems > 10 && hasTerms);

    // Split items intelligently
    final firstPageItemList = invoice.items.take(firstPageItems).toList();
    final remainingItems = invoice.items.skip(firstPageItems).toList();

    // Generate first page with header, some items, and possibly totals
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section
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

              pw.SizedBox(height: 30),

              // Client information
              _buildClientSection(
                client: client,
                clientAddress: clientAddress,
                invoice: invoice,
                subheaderStyle: subheaderStyle,
                bodyStyle: bodyStyle,
                bodyBoldStyle: bodyBoldStyle,
                lightColor: lightColor,
                dateFormat: DateFormat('MMM dd, yyyy'),
              ),

              pw.SizedBox(height: 20),

              // Items table for first page
              _buildItemsTable(
                items: firstPageItemList,
                invoice: invoice,
                bodyStyle: bodyStyle,
                bodyBoldStyle: bodyBoldStyle,
                fontItalic: fontItalic,
                lightColor: lightColor,
                showContinuation: false,
              ),

              pw.SizedBox(height: 10),

              // // Only show totals on the first page if there's no separate terms page
              // // or if we're showing all items on this page
              // if (!placeTermsOnSeparatePage || remainingItems.isEmpty)
              //   _buildTotalsSection(
              //     invoice: invoice,
              //     bodyStyle: bodyStyle,
              //     bodyBoldStyle: bodyBoldStyle,
              //   ),

              // // Only include notes and terms if they're not complex or if we have no remaining items
              // if (!placeTermsOnSeparatePage &&
              //     (remainingItems.isEmpty || !hasComplexTerms)) ...[
              //   pw.SizedBox(height: 20),
              //   _buildNotesAndTermsSections(
              //     invoice: invoice,
              //     subheaderStyle: subheaderStyle,
              //     bodyStyle: bodyStyle,
              //     lightColor: lightColor,
              //   ),
              // ],

              // // Only include signature if it fits and we're not placing terms on separate page
              // if (hasSignature &&
              //     !placeTermsOnSeparatePage &&
              //     remainingItems.isEmpty)
              //   _buildSignatureSection(
              //     signature: signature,
              //     subheaderStyle: subheaderStyle,
              //     bodyStyle: bodyStyle,
              //     bodyBoldStyle: bodyBoldStyle,
              //   ),

              // Footer
              pw.Expanded(child: pw.SizedBox()),
              _buildFooter(context, smallStyle),
            ],
          );
        },
      ),
    );

    // Generate additional pages for remaining items
    if (remainingItems.isNotEmpty) {
      // More conservative items per page for subsequent pages
      final subsequentPagesItemCount = estimatedItemsPerPage - 1;

      final itemPages = <List<dynamic>>[];
      for (
        int i = 0;
        i < remainingItems.length;
        i += subsequentPagesItemCount
      ) {
        final end = (i + subsequentPagesItemCount < remainingItems.length)
            ? i + subsequentPagesItemCount
            : remainingItems.length;
        itemPages.add(remainingItems.sublist(i, end));
      }

      for (int pageIndex = 0; pageIndex < itemPages.length; pageIndex++) {
        final items = itemPages[pageIndex];
        final startItemNumber =
            firstPageItems + (pageIndex * subsequentPagesItemCount) + 1;
        final endItemNumber = startItemNumber + items.length - 1;

        // Determine if this is the last items page
        // ignore: unused_local_variable
        final isLastItemsPage = pageIndex == itemPages.length - 1;

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Enhanced page header
                  _buildContinuationHeader(
                    invoice: invoice,
                    headerStyle: headerStyle,
                    bodyBoldStyle: bodyBoldStyle,
                    startItemNumber: startItemNumber,
                    endItemNumber: endItemNumber,
                    totalItems: totalItems,
                    pageIndex: pageIndex + 1,
                    totalPages: placeTermsOnSeparatePage
                        ? itemPages.length + 2
                        : // +1 for first page, +1 for terms page
                          itemPages.length + 1, // +1 for first page
                  ),

                  pw.SizedBox(height: 20),

                  // Items table for this page
                  _buildItemsTable(
                    items: items,
                    invoice: invoice,
                    bodyStyle: bodyStyle,
                    bodyBoldStyle: bodyBoldStyle,
                    fontItalic: fontItalic,
                    lightColor: lightColor,
                    showContinuation: pageIndex < itemPages.length - 1,
                  ),

                  // Show totals only on the last page of items
                  if (pageIndex == itemPages.length - 1) ...[
                    pw.SizedBox(height: 10),

                    // Totals section
                    _buildTotalsSection(
                      invoice: invoice,
                      bodyStyle: bodyStyle,
                      bodyBoldStyle: bodyBoldStyle,
                    ),

                    pw.SizedBox(height: 20),

                    // Notes and Terms sections
                    _buildNotesAndTermsSections(
                      invoice: invoice,
                      subheaderStyle: subheaderStyle,
                      bodyStyle: bodyStyle,
                      lightColor: lightColor,
                    ),

                    // Signature section
                    if (hasSignature)
                      _buildSignatureSection(
                        signature: signature,
                        signatureImage: signatureImage,
                        subheaderStyle: subheaderStyle,
                        bodyStyle: bodyStyle,
                        bodyBoldStyle: bodyBoldStyle,
                      ),
                  ],

                  // Footer
                  pw.Expanded(child: pw.SizedBox()),
                  _buildFooter(context, smallStyle),
                ],
              );
            },
          ),
        );
      }

      // Add a final page for terms, notes, and signature if needed
      if (placeTermsOnSeparatePage) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Terms page header
                  _buildTermsPageHeader(
                    invoice: invoice,
                    headerStyle: headerStyle,
                    bodyBoldStyle: bodyBoldStyle,
                    pageIndex: itemPages.length + 1,
                    totalPages: itemPages.length + 2,
                  ),

                  pw.SizedBox(height: 30),

                  // Always show notes and terms on the dedicated terms page
                  _buildNotesAndTermsSections(
                    invoice: invoice,
                    subheaderStyle: subheaderStyle,
                    bodyStyle: bodyStyle,
                    lightColor: lightColor,
                  ),

                  pw.SizedBox(height: 30),

                  // Include signature on the terms page
                  if (hasSignature)
                    _buildSignatureSection(
                      signature: signature,
                      signatureImage: signatureImage,
                      subheaderStyle: subheaderStyle,
                      bodyStyle: bodyStyle,
                      bodyBoldStyle: bodyBoldStyle,
                    ),

                  // Footer
                  pw.Expanded(child: pw.SizedBox()),
                  _buildFooter(context, smallStyle),
                ],
              );
            },
          ),
        );
      }
    }
  }

  /// Build a header for the terms and conditions page
  static pw.Widget _buildTermsPageHeader({
    required Invoice invoice,
    required pw.TextStyle headerStyle,
    required pw.TextStyle bodyBoldStyle,
    required int pageIndex,
    required int totalPages,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
                style: headerStyle,
              ),
              pw.Text('Terms & Additional Information', style: bodyBoldStyle),
            ],
          ),
          pw.Text('Page $pageIndex of $totalPages', style: bodyBoldStyle),
        ],
      ),
    );
  }

  /// Build header section
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
        // Business info
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
        // Invoice type and number
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

  /// Build continuation header for additional pages
  static pw.Widget _buildContinuationHeader({
    required Invoice invoice,
    required pw.TextStyle headerStyle,
    required pw.TextStyle bodyBoldStyle,
    required int startItemNumber,
    required int endItemNumber,
    required int totalItems,
    required int pageIndex,
    required int totalPages,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
                style: headerStyle,
              ),
              pw.Text(
                'Items $startItemNumber-$endItemNumber of $totalItems',
                style: bodyBoldStyle,
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Page $pageIndex of $totalPages', style: bodyBoldStyle),
              pw.Text(
                'Continued...',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build client section
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

  /// Build compact client section for single page
  static pw.Widget _buildCompactClientSection({
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
      padding: const pw.EdgeInsets.all(8), // Reduced padding
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
                pw.Text(
                  'BILL TO',
                  style: subheaderStyle.copyWith(fontSize: 11),
                ), // Smaller font
                pw.SizedBox(height: 2), // Reduced spacing
                pw.Text(
                  client.name,
                  style: bodyBoldStyle.copyWith(fontSize: 9),
                ), // Smaller font
                if (client.company != null && client.company!.isNotEmpty)
                  pw.Text(
                    client.company!,
                    style: bodyStyle.copyWith(fontSize: 8),
                  ), // Smaller font
                if (clientAddress != null)
                  pw.Text(
                    clientAddress,
                    style: bodyStyle.copyWith(fontSize: 8),
                  ), // Smaller font
                pw.SizedBox(height: 2), // Reduced spacing
                if (client.email != null)
                  pw.Text(
                    'Email: ${client.email}',
                    style: bodyStyle.copyWith(fontSize: 8),
                  ), // Smaller font
                if (client.phone != null)
                  pw.Text(
                    'Phone: ${client.phone}',
                    style: bodyStyle.copyWith(fontSize: 8),
                  ), // Smaller font
              ],
            ),
          ),
          if (invoice.isRecurring)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RECURRING DETAILS',
                    style: subheaderStyle.copyWith(fontSize: 11),
                  ), // Smaller font
                  pw.SizedBox(height: 2), // Reduced spacing
                  pw.Text(
                    'Frequency: ${invoice.recurringFrequency}',
                    style: bodyStyle.copyWith(fontSize: 8),
                  ), // Smaller font
                  if (invoice.recurringInterval != null)
                    pw.Text(
                      'Interval: ${invoice.recurringInterval}',
                      style: bodyStyle.copyWith(fontSize: 8),
                    ), // Smaller font
                  if (invoice.recurringEndDate != null)
                    pw.Text(
                      'End Date: ${dateFormat.format(invoice.recurringEndDate!)}',
                      style: bodyStyle.copyWith(fontSize: 8),
                    ), // Smaller font
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build items table with improved styling for long lists
  static pw.Widget _buildItemsTable({
    required List<dynamic> items,
    required Invoice invoice,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required pw.Font fontItalic,
    required PdfColor lightColor,
    bool showContinuation = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          top: pw.BorderSide(color: PdfColors.grey300),
          bottom: pw.BorderSide(color: PdfColors.grey300),
          horizontalInside: pw.BorderSide(color: PdfColors.grey300),
        ),
        tableWidth: pw.TableWidth.max,
        columnWidths: {
          0: const pw.FlexColumnWidth(5), // Description
          1: const pw.FlexColumnWidth(1), // Quantity
          2: const pw.FlexColumnWidth(2), // Unit Price
          3: const pw.FlexColumnWidth(2), // Amount
        },
        children: [
          // Table header with improved styling
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: lightColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
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

          // Table rows for each item with alternating colors for better readability
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final quantity = item.stockQuantity ?? 1;
            final currencySymbol =
                CurrencyUtils.currencies[invoice.currency]?.symbol ?? '';
            final unitPriceStr =
                '$currencySymbol${(item.effectiveUnitPriceCents / 100).toStringAsFixed(2)}';
            final totalPriceCents = item.effectiveUnitPriceCents * quantity;
            final totalPriceStr =
                '$currencySymbol${(totalPriceCents / 100).toStringAsFixed(2)}';

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
      ),
    );
  }

  /// Build responsive items table for single page with compact styling
  static pw.Widget _buildResponsiveItemsTable({
    required List<dynamic> items,
    required Invoice invoice,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
    required pw.Font fontItalic,
    required PdfColor lightColor,
    bool showContinuation = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          top: pw.BorderSide(color: PdfColors.grey300),
          bottom: pw.BorderSide(color: PdfColors.grey300),
          horizontalInside: pw.BorderSide(color: PdfColors.grey300),
        ),
        tableWidth: pw.TableWidth.max,
        columnWidths: {
          0: const pw.FlexColumnWidth(5), // Description
          1: const pw.FlexColumnWidth(1), // Quantity
          2: const pw.FlexColumnWidth(2), // Unit Price
          3: const pw.FlexColumnWidth(2), // Amount
        },
        children: [
          // Table header with compact styling
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: lightColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), // Reduced padding
                child: pw.Text(
                  'Description',
                  style: bodyBoldStyle.copyWith(fontSize: 9),
                ), // Smaller font
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), // Reduced padding
                child: pw.Text(
                  'Qty',
                  style: bodyBoldStyle.copyWith(fontSize: 9), // Smaller font
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), // Reduced padding
                child: pw.Text(
                  'Unit Price',
                  style: bodyBoldStyle.copyWith(fontSize: 9), // Smaller font
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8), // Reduced padding
                child: pw.Text(
                  'Amount',
                  style: bodyBoldStyle.copyWith(fontSize: 9), // Smaller font
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),

          // Table rows for each item with compact styling
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final quantity = item.stockQuantity ?? 1;
            final currencySymbol =
                CurrencyUtils.currencies[invoice.currency]?.symbol ?? '';
            final unitPriceStr =
                '$currencySymbol${(item.effectiveUnitPriceCents / 100).toStringAsFixed(2)}';
            final totalPriceCents = item.effectiveUnitPriceCents * quantity;
            final totalPriceStr =
                '$currencySymbol${(totalPriceCents / 100).toStringAsFixed(2)}';

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: index.isEven ? PdfColors.white : PdfColors.grey50,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8), // Reduced padding
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.name,
                        style: bodyStyle.copyWith(fontSize: 8),
                      ), // Smaller font
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        pw.Text(
                          item.description!,
                          style: pw.TextStyle(
                            font: fontItalic,
                            fontSize: 7, // Smaller font
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8), // Reduced padding
                  child: pw.Text(
                    quantity.toString(),
                    style: bodyStyle.copyWith(fontSize: 8), // Smaller font
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8), // Reduced padding
                  child: pw.Text(
                    unitPriceStr,
                    style: bodyStyle.copyWith(fontSize: 8), // Smaller font
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8), // Reduced padding
                  child: pw.Text(
                    totalPriceStr,
                    style: bodyStyle.copyWith(fontSize: 8), // Smaller font
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Build totals section with improved styling
  static pw.Widget _buildTotalsSection({
    required Invoice invoice,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
  }) {
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
                invoice.currency ?? 'MYR',
                bodyStyle,
                bodyBoldStyle,
              ),

              if (invoice.effectiveDiscountAmountCents > 0)
                _buildTotalRow(
                  'Discount ${invoice.discountRate > 0 ? '(${invoice.discountRate.toStringAsFixed(2)}%)' : ''}',
                  invoice.effectiveDiscountAmountCents,
                  invoice.currency ?? 'MYR',
                  bodyStyle,
                  bodyBoldStyle,
                  isDiscount: true,
                ),

              // Add tax rows
              ...invoice.taxes.map((tax) {
                final taxableAmountCents =
                    invoice.effectiveSubtotalCents -
                    invoice.effectiveDiscountAmountCents;
                return _buildTotalRow(
                  '${tax.name} (${tax.rate.toStringAsFixed(2)}%)',
                  (taxableAmountCents * tax.rate / 100).round(),
                  invoice.currency ?? 'MYR',
                  bodyStyle,
                  bodyBoldStyle,
                );
              }),

              pw.Divider(color: PdfColors.grey400, thickness: 1),

              _buildTotalRow(
                'Total',
                invoice.effectiveTotalCents,
                invoice.currency ?? 'MYR',
                bodyBoldStyle.copyWith(fontSize: 14),
                bodyBoldStyle.copyWith(fontSize: 14),
              ),

              if (invoice.effectivePaidAmountCents > 0)
                _buildTotalRow(
                  'Paid',
                  invoice.effectivePaidAmountCents,
                  invoice.currency ?? 'MYR',
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
                  invoice.currency ?? 'MYR',
                  bodyBoldStyle.copyWith(fontSize: 14, color: PdfColors.red700),
                  bodyBoldStyle.copyWith(fontSize: 14, color: PdfColors.red700),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build notes and terms sections
  static pw.Widget _buildNotesAndTermsSections({
    required Invoice invoice,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required PdfColor lightColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Notes section
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

        // Terms section
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
                ...invoice.terms.map((term) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(term.content, style: bodyStyle),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Build compact notes and terms sections for single page
  static pw.Widget _buildCompactNotesAndTermsSections({
    required Invoice invoice,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required PdfColor lightColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Notes section with compact styling
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 12), // Reduced spacing
          pw.Container(
            padding: const pw.EdgeInsets.all(8), // Reduced padding
            decoration: pw.BoxDecoration(
              color: lightColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Notes',
                  style: subheaderStyle.copyWith(fontSize: 11),
                ), // Smaller font
                pw.SizedBox(height: 2), // Reduced spacing
                pw.Text(
                  invoice.notes!,
                  style: bodyStyle.copyWith(fontSize: 8),
                ), // Smaller font
              ],
            ),
          ),
        ],

        // Terms section with compact styling
        if (invoice.terms.isNotEmpty) ...[
          pw.SizedBox(height: 12), // Reduced spacing
          pw.Container(
            padding: const pw.EdgeInsets.all(8), // Reduced padding
            decoration: pw.BoxDecoration(
              color: lightColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Terms & Conditions',
                  style: subheaderStyle.copyWith(fontSize: 11),
                ), // Smaller font
                pw.SizedBox(height: 2), // Reduced spacing
                ...invoice.terms.map((term) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(
                      bottom: 2,
                    ), // Reduced spacing
                    child: pw.Text(
                      term.content,
                      style: bodyStyle.copyWith(fontSize: 8),
                    ), // Smaller font
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Build signature section
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
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
          ),
        ),
      ],
    );
  }

  /// Build compact signature section for single page
  static pw.Widget _buildCompactSignatureSection({
    required Signature signature,
    required Uint8List signatureImage,
    required pw.TextStyle subheaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle bodyBoldStyle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Authorized Signature',
                style: subheaderStyle.copyWith(fontSize: 11),
              ), // Smaller font
              pw.SizedBox(height: 6), // Reduced spacing
              pw.Container(
                height: 50, // Reduced height
                width: 150, // Reduced width
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Image(
                  pw.MemoryImage(signatureImage),
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 4), // Reduced spacing
              pw.Text(
                signature.name,
                style: bodyBoldStyle.copyWith(fontSize: 9),
              ), // Smaller font
              if (signature.title != null)
                pw.Text(
                  signature.title!,
                  style: bodyStyle.copyWith(fontSize: 8),
                ), // Smaller font
            ],
          ),
        ),
      ],
    );
  }

  /// Build footer with page numbers
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

  /// Helper method to build a total row
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

  /// Preview the invoice in a Flutter widget
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

  /// Print the invoice
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

  /// Share the invoice
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
  ///
  /// Writes the PDF to the platform Downloads directory when available (desktop),
  /// otherwise to the application documents directory (mobile). Unlike
  /// [shareInvoice], this does not open the OS share sheet.
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

    // Prefer Downloads (desktop); it is unsupported on mobile (throws/returns
    // null) so fall back to the app documents directory.
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
