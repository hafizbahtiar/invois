import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_composer.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';
import 'package:invois/features/item/item_model.dart';

/// Subtotal coverage for production line-only reads and migration/recovery
/// fallback reads. Discount/tax/total still flow through the composer via
/// subtotalCentsOverride.
void main() {
  Item item(String name, {int? stockQuantity, int unitPriceCents = 1000}) =>
      Item(
        name: name,
        unitPrice: unitPriceCents / 100,
        unitPriceCents: unitPriceCents,
        stockQuantity: stockQuantity,
      );

  group('InvoiceLineReader.subtotalCentsFromLines', () {
    test('uses lines only (decimal supported)', () {
      expect(
        InvoiceLineReader.subtotalCentsFromLines([
          InvoiceLine(name: 'A', unitPriceCents: 1000, quantityMilli: 2500),
        ]),
        2500,
      );
    });

    test('missing lines -> 0, no legacy fallback', () {
      expect(InvoiceLineReader.subtotalCentsFromLines(const []), 0);
    });
  });

  group('InvoiceLineReader.subtotalCents migration/recovery fallback', () {
    test('falls back to legacy items', () {
      expect(
        InvoiceLineReader.subtotalCents(
          lines: const [],
          items: [
            item('A', stockQuantity: 2),
            item('B', stockQuantity: 1, unitPriceCents: 500),
          ],
        ),
        2500,
      );
    });

    test('uses lines when present (decimal supported)', () {
      expect(
        InvoiceLineReader.subtotalCents(
          lines: [
            InvoiceLine(name: 'A', unitPriceCents: 1000, quantityMilli: 2500),
          ],
          items: [item('IGNORED', stockQuantity: 9, unitPriceCents: 9900)],
        ),
        2500,
      );
    });

    test('empty -> 0', () {
      expect(
        InvoiceLineReader.subtotalCents(lines: const [], items: const []),
        0,
      );
    });

    test('invalid legacy qty (<=0) defensively maps to one unit', () {
      // Documented adapter rule (vs legacy composer which would use 0).
      expect(
        InvoiceLineReader.subtotalCents(
          lines: const [],
          items: [item('A', stockQuantity: 0, unitPriceCents: 1000)],
        ),
        1000,
      );
    });
  });

  group('compose: subtotalCentsOverride parity with the lines path', () {
    test('legacy whole-quantity invoice with discount + tax matches', () {
      final items = [
        item('A', stockQuantity: 1, unitPriceCents: 1000),
        item('B', stockQuantity: 3, unitPriceCents: 333),
      ];
      final lineSubtotal = InvoiceLineReader.subtotalCents(
        lines: const [],
        items: items,
      );

      final viaOverride = InvoiceComposer.compose(
        subtotalCentsOverride: lineSubtotal,
        discountAmountCents: 200,
        taxRates: const [6.0],
        paidAmountCents: 500,
      );
      final viaLines = InvoiceComposer.compose(
        lines: items.map(
          (i) => ComposerLine(
            unitPriceCents: i.effectiveUnitPriceCents,
            quantity: i.stockQuantity ?? 1,
          ),
        ),
        discountAmountCents: 200,
        taxRates: const [6.0],
        paidAmountCents: 500,
      );

      expect(viaOverride.subtotalCents, viaLines.subtotalCents);
      expect(viaOverride.discountAmountCents, viaLines.discountAmountCents);
      expect(viaOverride.taxAmountCents, viaLines.taxAmountCents);
      expect(viaOverride.totalCents, viaLines.totalCents);
      expect(viaOverride.balanceDueCents, viaLines.balanceDueCents);
    });

    test('decimal-quantity subtotal flows through discount/tax/total', () {
      // 2.5 x RM10 = RM25.00 subtotal
      final subtotal = InvoiceLineReader.subtotalCents(
        lines: [
          InvoiceLine(name: 'Hrs', unitPriceCents: 1000, quantityMilli: 2500),
        ],
        items: const [],
      );
      final totals = InvoiceComposer.compose(
        subtotalCentsOverride: subtotal,
        discountRate: 10.0, // 10% of 2500 = 250
        taxRates: const [6.0], // 6% of (2500-250)=2250 -> 135
      );
      expect(totals.subtotalCents, 2500);
      expect(totals.discountAmountCents, 250);
      expect(totals.taxAmountCents, 135);
      expect(totals.totalCents, 2500 - 250 + 135);
    });
  });
}
