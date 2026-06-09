import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_composer.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';

void main() {
  group('InvoiceLineReader.subtotalCentsFromLines', () {
    test('uses lines only (decimal supported)', () {
      expect(
        InvoiceLineReader.subtotalCentsFromLines([
          InvoiceLine(name: 'A', unitPriceCents: 1000, quantityMilli: 2500),
        ]),
        2500,
      );
    });

    test('missing lines -> 0', () {
      expect(InvoiceLineReader.subtotalCentsFromLines(const []), 0);
    });
  });

  group('compose: subtotalCentsOverride from the lines path', () {
    test('decimal-quantity subtotal flows through discount/tax/total', () {
      final subtotal = InvoiceLineReader.subtotalCentsFromLines([
        InvoiceLine(name: 'Hrs', unitPriceCents: 1000, quantityMilli: 2500),
      ]);
      final totals = InvoiceComposer.compose(
        subtotalCentsOverride: subtotal,
        discountRate: 10.0,
        taxRates: const [6.0],
      );
      expect(totals.subtotalCents, 2500);
      expect(totals.discountAmountCents, 250);
      expect(totals.taxAmountCents, 135);
      expect(totals.totalCents, 2500 - 250 + 135);
    });
  });
}
