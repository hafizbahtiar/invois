import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/domain/invoice_numbering.dart';

void main() {
  Invoice invoice(
    String number, {
    int? id,
    int businessId = 1,
    String? prefix,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: number,
      invoiceNumberPrefix: prefix,
      businessId: businessId,
      issueDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 31),
    );
  }

  group('InvoiceNumbering.nextNumber', () {
    test('empty business starts at INV-0001', () {
      expect(InvoiceNumbering.nextNumber(const []), 'INV-0001');
    });

    test('increments after INV-0001 and INV-0002', () {
      expect(
        InvoiceNumbering.nextNumber([invoice('INV-0001'), invoice('INV-0002')]),
        'INV-0003',
      );
    });

    test('ignores manual numbers that do not match the sequence pattern', () {
      expect(
        InvoiceNumbering.nextNumber([
          invoice('CUSTOM-9'),
          invoice('INV-0004'),
          invoice('2026-001'),
        ]),
        'INV-0005',
      );
    });

    test('supports legacy prefix plus number storage', () {
      expect(
        InvoiceNumbering.nextNumber([invoice('0007', prefix: 'INV-')]),
        'INV-0008',
      );
    });
  });

  group('InvoiceNumbering prefix scopes', () {
    final mixed = [
      invoice('INV-0001'),
      invoice('INV-0002'),
      invoice('QUO-0005'),
      invoice('0003', prefix: 'QUO-'), // legacy split storage, same scope
    ];

    test('INV scope only counts INV numbers', () {
      expect(InvoiceNumbering.nextNumber(mixed, prefix: 'INV-'), 'INV-0003');
    });

    test('QUO scope only counts QUO numbers', () {
      expect(InvoiceNumbering.nextNumber(mixed, prefix: 'QUO-'), 'QUO-0006');
    });

    test('a fresh scope starts at 0001', () {
      expect(InvoiceNumbering.nextNumber(mixed, prefix: 'EST-'), 'EST-0001');
      expect(InvoiceNumbering.nextSequence(mixed, prefix: 'EST-'), '0001');
    });

    test('scope match is trimmed and case-insensitive', () {
      expect(InvoiceNumbering.nextSequence(mixed, prefix: 'quo-'), '0006');
      expect(InvoiceNumbering.nextSequence(mixed, prefix: ' QUO- '), '0006');
    });

    test('INV2026- is its own scope, separate from INV-', () {
      final invoices = [invoice('INV-0009'), invoice('INV2026-0001')];
      expect(
        InvoiceNumbering.nextNumber(invoices, prefix: 'INV2026-'),
        'INV2026-0002',
      );
      expect(InvoiceNumbering.nextNumber(invoices, prefix: 'INV-'), 'INV-0010');
    });

    test('sequence width follows the existing numbers in the scope', () {
      expect(
        InvoiceNumbering.nextNumber([invoice('INV-001')], prefix: 'INV-'),
        'INV-002',
      );
      expect(
        InvoiceNumbering.nextNumber([invoice('INV-1')], prefix: 'INV-'),
        'INV-2',
      );
      // Rollover never truncates.
      expect(
        InvoiceNumbering.nextNumber([invoice('INV-999')], prefix: 'INV-'),
        'INV-1000',
      );
    });

    test('no-prefix plain numbers form the empty scope', () {
      final invoices = [invoice('0001'), invoice('0002'), invoice('INV-0009')];
      expect(InvoiceNumbering.nextSequence(invoices, prefix: ''), '0003');
    });

    test('legacy/malformed numbers never crash generation', () {
      final invoices = [
        invoice(''),
        invoice('DRAFT'),
        invoice('???'),
        invoice('99999999999999999999999999999999'), // int overflow -> skipped
        invoice('INV-0002'),
      ];
      expect(InvoiceNumbering.nextNumber(invoices, prefix: 'INV-'), 'INV-0003');
    });
  });

  group('InvoiceNumbering.tryParse', () {
    test('splits prefix, sequence, and width', () {
      final parts = InvoiceNumbering.tryParse('INV2026-0042')!;
      expect(parts.prefix, 'INV2026-');
      expect(parts.sequence, 42);
      expect(parts.width, 4);
    });

    test('returns null for numbers without trailing digits', () {
      expect(InvoiceNumbering.tryParse('DRAFT'), isNull);
      expect(InvoiceNumbering.tryParse(''), isNull);
      expect(InvoiceNumbering.tryParse('INV-0001-FINAL'), isNull);
    });
  });

  group('InvoiceNumbering.isAvailable', () {
    test('rejects duplicate number in the provided business invoice list', () {
      expect(
        InvoiceNumbering.isAvailable(
          invoices: [invoice('INV-0001', id: 1)],
          invoiceNumber: 'INV-0001',
        ),
        isFalse,
      );
    });

    test('allows edit invoice to keep its own number', () {
      expect(
        InvoiceNumbering.isAvailable(
          invoices: [invoice('INV-0001', id: 1)],
          invoiceNumber: 'INV-0001',
          excludingInvoiceId: 1,
        ),
        isTrue,
      );
    });
  });
}
