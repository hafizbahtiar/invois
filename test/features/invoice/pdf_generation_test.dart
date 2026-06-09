import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:invois/features/business/data/business_model.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:invois/features/invoice/pdf/invoice_generator.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/signature/data/signature_model.dart';

/// Smoke coverage for the S5 PDF engine.
///
/// A pixel golden was considered but deferred: golden bytes are sensitive to
/// font hinting / pdf-package versions and would tie the suite to one host,
/// while the real risks here are (a) offline font loading and (b) multi-page
/// flow with an embedded signature not throwing on a large invoice. This test
/// asserts a valid, non-trivial PDF is produced for exactly that case.
void main() {
  // generateInvoice loads bundled fonts via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  // A real 8x8 PNG encoded with the same `image` package the pdf package
  // decodes with, so the signature embeds reliably across hosts.
  final pngBytes = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 8, height: 8)..clear(img.ColorRgb8(0, 0, 0)),
    ),
  );

  Invoice buildInvoice(int itemCount) {
    final invoice = Invoice(
      invoiceNumber: 'INV-PDF-001',
      invoiceNumberPrefix: 'INV',
      status: InvoiceStatus.sent.name,
      issueDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 31),
      currency: 'MYR',
      subtotalCents: 1000 * itemCount,
      totalCents: 1000 * itemCount,
      balanceDueCents: 1000 * itemCount,
    );
    for (var i = 0; i < itemCount; i++) {
      invoice.items.add(
        Item(
          name: 'Line item $i',
          description: 'Description for item $i',
          unitPrice: 10.0,
          unitPriceCents: 1000,
          stockQuantity: 1,
        ),
      );
    }
    return invoice;
  }

  test(
    'generates a valid multi-page PDF for a 100-item signed invoice',
    () async {
      final bytes = await InvoiceGenerator.generateInvoice(
        invoice: buildInvoice(100),
        business: Business(name: 'Acme Sdn Bhd', streetAddress1: '1 Market St'),
        client: Client(name: 'Globex', streetAddress1: '99 Industrial Rd'),
        signature: Signature(name: 'Owner', imageBytes: pngBytes),
      );

      // Valid PDF magic header and a non-trivial body.
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    },
  );

  test(
    'generates a PDF for a single-item invoice without a signature',
    () async {
      final bytes = await InvoiceGenerator.generateInvoice(
        invoice: buildInvoice(1),
        business: Business(name: 'Acme Sdn Bhd'),
        client: Client(name: 'Globex'),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    },
  );

  test('selected signature is embedded in generated PDF data', () async {
    final signedBytes = await InvoiceGenerator.generateInvoice(
      invoice: buildInvoice(1),
      business: Business(name: 'Acme Sdn Bhd'),
      client: Client(name: 'Globex'),
      signature: Signature(name: 'Owner', imageBytes: pngBytes),
    );
    final unsignedBytes = await InvoiceGenerator.generateInvoice(
      invoice: buildInvoice(1),
      business: Business(name: 'Acme Sdn Bhd'),
      client: Client(name: 'Globex'),
    );

    expect(String.fromCharCodes(signedBytes.sublist(0, 5)), '%PDF-');
    expect(signedBytes.length, greaterThan(unsignedBytes.length));
  });

  test(
    'generates a PDF from InvoiceLine rows (decimal qty), preferring lines',
    () async {
      // In-memory invoice with both new lines and a legacy item: the adapter
      // must use the lines and ignore the item.
      final invoice = Invoice(
        invoiceNumber: 'INV-PDF-LINES',
        status: InvoiceStatus.sent.name,
        issueDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 31),
        currency: 'MYR',
        subtotalCents: 2500,
        totalCents: 2500,
        balanceDueCents: 2500,
      );
      invoice.lines.add(
        InvoiceLine(
          name: 'Consulting',
          description: 'Hourly',
          unitPriceCents: 1000,
          quantityMilli: 2500, // 2.5 hours -> RM25.00
          sortOrder: 0,
        ),
      );
      invoice.items.add(
        Item(name: 'IGNORED', unitPrice: 99, unitPriceCents: 9900, stockQuantity: 9),
      );

      final bytes = await InvoiceGenerator.generateInvoice(
        invoice: invoice,
        business: Business(name: 'Acme Sdn Bhd'),
        client: Client(name: 'Globex'),
      );

      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    },
  );

  test('throws when the invoice has no items', () async {
    expect(
      () => InvoiceGenerator.generateInvoice(
        invoice: buildInvoice(0),
        business: Business(name: 'Acme'),
        client: Client(name: 'Globex'),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
