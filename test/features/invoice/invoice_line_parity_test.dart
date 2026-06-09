import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/invoice_composer.dart';
import 'package:invois/features/invoice/invoice_line_math.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';
import 'package:invois/features/item/item_model.dart';

/// Step 4C-4A: proves the new line math is byte-for-byte consistent with the
/// legacy composer subtotal for whole-quantity invoices — the precondition for
/// later switching totals/composer to derive from `InvoiceLineReader`.
void main() {
  Item item(String name, {int? stockQuantity, int unitPriceCents = 1000}) =>
      Item(
        name: name,
        unitPrice: unitPriceCents / 100,
        unitPriceCents: unitPriceCents,
        stockQuantity: stockQuantity,
      );

  // Legacy subtotal exactly as the composer computes it today.
  int composerSubtotal(List<Item> items) => InvoiceComposer.subtotalCents(
    items.map(
      (i) => ComposerLine(
        unitPriceCents: i.effectiveUnitPriceCents,
        quantity: i.stockQuantity ?? 1,
      ),
    ),
  );

  // Subtotal via the new adapter (sum of per-line rounded totals).
  int lineSubtotal(List<Item> items) =>
      InvoiceLineReader.resolveWithLegacyFallback(
        lines: const [],
        items: items,
      ).fold(0, (sum, v) => sum + v.lineTotalCents);

  group('legacy subtotal parity (composer == sum of line totals)', () {
    test('single item, qty 1', () {
      final items = [item('A', stockQuantity: 1, unitPriceCents: 1000)];
      expect(lineSubtotal(items), composerSubtotal(items));
      expect(lineSubtotal(items), 1000);
    });

    test('single item, qty 2', () {
      final items = [item('A', stockQuantity: 2, unitPriceCents: 1000)];
      expect(lineSubtotal(items), composerSubtotal(items));
      expect(lineSubtotal(items), 2000);
    });

    test('multiple items with varied prices/quantities', () {
      final items = [
        item('A', stockQuantity: 1, unitPriceCents: 1000),
        item('B', stockQuantity: 3, unitPriceCents: 333),
        item('C', stockQuantity: 2, unitPriceCents: 500),
      ];
      expect(lineSubtotal(items), composerSubtotal(items));
      expect(lineSubtotal(items), 1000 + 999 + 1000);
    });

    test('null quantity falls back to 1 (parity)', () {
      final items = [item('A', stockQuantity: null, unitPriceCents: 1234)];
      expect(lineSubtotal(items), composerSubtotal(items));
      expect(lineSubtotal(items), 1234);
    });

    test('zero / negative quantity falls back to 1 (parity)', () {
      // composer uses (stockQuantity ?? 1) so 0 stays 0 there; the adapter maps
      // <=0 -> 1 unit. Documents the ONE intentional difference for invalid data.
      final items = [item('A', stockQuantity: 0, unitPriceCents: 1000)];
      expect(composerSubtotal(items), 0); // legacy: 1000 * 0
      expect(lineSubtotal(items), 1000); // adapter: invalid qty -> 1 unit
    });

    test('large values stay exact (no double overflow)', () {
      final items = [item('A', stockQuantity: 50, unitPriceCents: 100000000)];
      expect(lineSubtotal(items), composerSubtotal(items));
      expect(lineSubtotal(items), 5000000000);
    });

    test('zero unit price', () {
      final items = [item('A', stockQuantity: 5, unitPriceCents: 0)];
      expect(lineSubtotal(items), composerSubtotal(items));
      expect(lineSubtotal(items), 0);
    });
  });

  group('decimal quantity line totals (new capability)', () {
    test('2.5 x RM10.00 = RM25.00', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 1000,
          quantityMilli: 2500,
        ),
        2500,
      );
    });

    test('1.5 x RM3.33 = RM5.00 (half-up at 4.995)', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 333,
          quantityMilli: 1500,
        ),
        500,
      );
    });

    test('0.25 x RM10.00 = RM2.50', () {
      expect(
        InvoiceLineMath.lineTotalCents(
          unitPriceCents: 1000,
          quantityMilli: 250,
        ),
        250,
      );
    });
  });
}
