import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_numbering.dart';

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
