import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/invoice_line_math.dart';

/// Pure quantity/line-total rules (no store needed).
void main() {
  group('InvoiceLineMath.lineTotalCents', () {
    test('whole quantity: RM10.00 x 2 = 2000c', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 1000,
          quantityMilli: 2000,
        ),
        2000,
      );
    });

    test('decimal quantity: RM10.00 x 2.5 = 2500c', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 1000,
          quantityMilli: 2500,
        ),
        2500,
      );
    });

    test('half-up rounding: RM3.33 x 1.5 = 4.995 -> 500c', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 333,
          quantityMilli: 1500,
        ),
        500,
      );
    });

    test('rounding boundary: 1c x 1.5 = 0.015 -> 2c', () {
      expect(
        InvoiceLineMath.lineTotalCents(unitPriceCents: 1, quantityMilli: 1500),
        2,
      );
    });

    test('exact one unit: RM3.33 x 1 = 333c', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 333,
          quantityMilli: 1000,
        ),
        333,
      );
    });

    test('zero quantity -> 0c', () {
      expect(
        InvoiceLineMath.lineTotalCents(unitPriceCents: 1000, quantityMilli: 0),
        0,
      );
    });
  });

  group('InvoiceLineMath.formatQuantity', () {
    test('whole', () => expect(InvoiceLineMath.formatQuantity(1000), '1'));
    test('half', () => expect(InvoiceLineMath.formatQuantity(2500), '2.5'));
    test('two dp', () => expect(InvoiceLineMath.formatQuantity(1250), '1.25'));
    test('milli', () => expect(InvoiceLineMath.formatQuantity(1), '0.001'));
    test('big whole', () => expect(InvoiceLineMath.formatQuantity(3000), '3'));
  });
}
