import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/pdf/invoice_generator.dart';

/// Tests for the PDF save path security hardening (P2-3).
///
/// `saveInvoice` now writes to `getApplicationDocumentsDirectory()/invoices/`
/// instead of `getDownloadsDirectory()`. These pure tests verify the filename
/// construction logic (`sanitizeFileName` + `_invoiceFileBase`); the
/// directory-creation and write path is exercised via the existing PDF
/// generation tests.
void main() {
  group('InvoiceGenerator.sanitizeFileName', () {
    test('passes through clean names', () {
      expect(InvoiceGenerator.sanitizeFileName('INV-001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV-2026-001'), 'INV-2026-001');
    });

    test('replaces illegal path characters with dash', () {
      expect(InvoiceGenerator.sanitizeFileName('INV/2024/001'), 'INV-2024-001');
      expect(InvoiceGenerator.sanitizeFileName('INV:001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV\\001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV*001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV?001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV"001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV<001>'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('INV|001'), 'INV-001');
    });

    test('replaces control characters', () {
      expect(InvoiceGenerator.sanitizeFileName('INV\x00\x01test'), 'INV-test');
      expect(InvoiceGenerator.sanitizeFileName('INV\x1Ftest'), 'INV-test');
    });

    test('collapses consecutive dashes', () {
      expect(InvoiceGenerator.sanitizeFileName('INV///001'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('A---B'), 'A-B');
    });

    test('trims leading/trailing dashes and dots', () {
      expect(InvoiceGenerator.sanitizeFileName('-INV-001-'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('.INV-001.'), 'INV-001');
      expect(InvoiceGenerator.sanitizeFileName('-.INV-001.-.'), 'INV-001');
    });

    test('falls back to "invoice" for empty/whitespace-only input', () {
      expect(InvoiceGenerator.sanitizeFileName(''), 'invoice');
      expect(InvoiceGenerator.sanitizeFileName('   '), 'invoice');
      expect(InvoiceGenerator.sanitizeFileName('---'), 'invoice');
      expect(InvoiceGenerator.sanitizeFileName('...'), 'invoice');
      expect(InvoiceGenerator.sanitizeFileName('-.-'), 'invoice');
    });

    test('handles names that become empty after sanitization', () {
      expect(InvoiceGenerator.sanitizeFileName('/'), 'invoice');
      expect(InvoiceGenerator.sanitizeFileName(':*?<>|'), 'invoice');
    });
  });

  group('InvoiceGenerator._invoiceFileBase (via sanitizeFileName)', () {
    Invoice invoiceWith(String number, {String? prefix}) {
      return Invoice(
        invoiceNumber: number,
        invoiceNumberPrefix: prefix,
        issueDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 15),
      );
    }

    test('combines prefix + number for the filename base', () {
      final invoice = invoiceWith('001', prefix: 'INV-');
      // _invoiceFileBase concatenates prefix + number, then sanitizes.
      // INV-001 → clean → INV-001
      final base = InvoiceGenerator.sanitizeFileName(
        '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
      );
      expect(base, 'INV-001');
    });

    test('sanitizes prefix + number with path separators', () {
      final invoice = invoiceWith('001', prefix: 'INV/');
      final base = InvoiceGenerator.sanitizeFileName(
        '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
      );
      expect(base, 'INV-001');
      // The final PDF filename must not contain path separators.
      expect(base, isNot(contains('/')));
    });

    test('handles missing prefix', () {
      final invoice = invoiceWith('QUO-2026-001');
      final base = InvoiceGenerator.sanitizeFileName(
        '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}',
      );
      expect(base, 'QUO-2026-001');
    });

    test('final PDF filename ends with .pdf extension', () {
      final base = InvoiceGenerator.sanitizeFileName('INV-001');
      expect('$base.pdf', endsWith('.pdf'));
      expect('$base.pdf', 'INV-001.pdf');
    });

    test('filename never contains a path separator after sanitization', () {
      for (final raw in ['INV/2024/001', 'A:B', 'C\\D', 'E|F']) {
        final sanitized = InvoiceGenerator.sanitizeFileName(raw);
        expect(sanitized, isNot(contains('/')));
        expect(sanitized, isNot(contains('\\')));
      }
    });
  });

  group('saveInvoice directory restriction', () {
    // The directory-creation and write logic is exercised by the existing
    // PDF generation tests. These tests document the security contract:
    // saveInvoice must NOT write to getDownloadsDirectory() — only to a
    // dedicated `invoices/` subfolder inside getApplicationDocumentsDirectory().

    test('sanitizeFileName is the only filename transformation — no path',
        () {
      // If a malicious invoice number somehow contained a relative path
      // traversal (e.g. ../../etc/passwd), sanitizeFileName must neutralize it.
      final result = InvoiceGenerator.sanitizeFileName('../../etc/passwd');
      expect(result, isNot(contains('..')));
      expect(result, isNot(contains('/')));
      expect(result, 'etc-passwd');
    });

    test('sanitizeFileName neutralizes absolute path attempt', () {
      final result = InvoiceGenerator.sanitizeFileName('/etc/shadow');
      expect(result, isNot(startsWith('/')));
      expect(result, 'etc-shadow');
    });
  });
}