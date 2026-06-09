import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/pdf/invoice_generator.dart';

/// Stage 1 (P2-008): invoice numbers can contain characters illegal in file
/// paths. `sanitizeFileName` must produce a safe, non-empty base name.
void main() {
  group('InvoiceGenerator.sanitizeFileName', () {
    test('replaces path separators and illegal characters', () {
      expect(InvoiceGenerator.sanitizeFileName('INV/2024/001'), 'INV-2024-001');
      expect(InvoiceGenerator.sanitizeFileName(r'INV\2024\001'), 'INV-2024-001');
      expect(InvoiceGenerator.sanitizeFileName('INV:2024*001?'), 'INV-2024-001');
    });

    test('keeps already-safe names intact', () {
      expect(InvoiceGenerator.sanitizeFileName('INV-0001'), 'INV-0001');
    });

    test('collapses repeated separators and trims edges', () {
      expect(InvoiceGenerator.sanitizeFileName('  //INV//1//  '), 'INV-1');
    });

    test('never returns an empty string', () {
      expect(InvoiceGenerator.sanitizeFileName('///'), 'invoice');
      expect(InvoiceGenerator.sanitizeFileName(''), 'invoice');
    });
  });
}
