import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';
import 'package:invois/features/invoice/invoice_quantity_input.dart';
import 'package:invois/features/item/item_model.dart';

/// Step 4C-4D-2A/2C/2B: in-memory decimal-quantity carrier for the form. Pure
/// tests (no store, no UI).
void main() {
  Item item(String name, {int? stockQuantity, int unitPriceCents = 1000}) =>
      Item(
        name: name,
        unitPrice: unitPriceCents / 100,
        unitPriceCents: unitPriceCents,
        stockQuantity: stockQuantity,
      );

  InvoiceLine line(
    String name, {
    required int quantityMilli,
    int sortOrder = 0,
    int? id,
    int? sourceItemId,
    int unitPriceCents = 1000,
  }) => InvoiceLine(
    id: id,
    sourceItemId: sourceItemId,
    name: name,
    description: 'line-desc-$name',
    unit: 'hour',
    currency: 'MYR',
    unitPriceCents: unitPriceCents,
    quantityMilli: quantityMilli,
    sortOrder: sortOrder,
  );

  group('InvoiceFormLine.fromItem', () {
    test('default (null stockQuantity) -> 1000', () {
      expect(InvoiceFormLine.fromItem(item('A')).quantityMilli, 1000);
    });
    test('stockQuantity 2 -> 2000', () {
      expect(
        InvoiceFormLine.fromItem(item('A', stockQuantity: 2)).quantityMilli,
        2000,
      );
    });
    test('invalid (0/neg) -> 1000', () {
      expect(
        InvoiceFormLine.fromItem(item('A', stockQuantity: 0)).quantityMilli,
        1000,
      );
      expect(
        InvoiceFormLine.fromItem(item('A', stockQuantity: -5)).quantityMilli,
        1000,
      );
    });
  });

  group('legacyQuantity (integer compatibility)', () {
    test('1000 -> 1', () {
      expect(
        InvoiceFormLine(item: item('A'), quantityMilli: 1000).legacyQuantity,
        1,
      );
    });
    test('2000 -> 2', () {
      expect(
        InvoiceFormLine(item: item('A'), quantityMilli: 2000).legacyQuantity,
        2,
      );
    });
    test(
      'non-whole 1500 is held without loss; legacyQuantity truncates to 1',
      () {
        final l = InvoiceFormLine(item: item('A'), quantityMilli: 1500);
        expect(l.quantityMilli, 1500); // preserved
        expect(l.legacyQuantity, 1); // documented truncation for legacy UI
      },
    );
  });

  group('resolve', () {
    test('items only -> derived from stockQuantity', () {
      final result = InvoiceFormLine.resolve(
        items: [item('A', stockQuantity: 2), item('B', stockQuantity: 1)],
        lines: const [],
      );
      expect(result.map((l) => l.item.name), ['A', 'B']);
      expect(result.map((l) => l.quantityMilli), [2000, 1000]);
    });

    test('lines present win and are sorted by sortOrder', () {
      final result = InvoiceFormLine.resolve(
        items: [item('A', stockQuantity: 1), item('B', stockQuantity: 1)],
        lines: [
          line('B', quantityMilli: 2500, sortOrder: 1),
          line('A', quantityMilli: 1500, sortOrder: 0),
        ],
      );
      expect(result.map((l) => l.item.name), ['A', 'B']);
      // Uses the line quantity, not stockQuantity*1000.
      expect(result.map((l) => l.quantityMilli), [1500, 2500]);
    });

    test(
      'lines-only invoice rebuilds temporary form carriers from snapshots',
      () {
        final result = InvoiceFormLine.resolve(
          items: const [],
          lines: [
            line(
              'Consulting',
              id: 42,
              quantityMilli: 1500,
              unitPriceCents: 1000,
            ),
          ],
        );
        expect(result.single.item.name, 'Consulting');
        expect(result.single.item.description, 'line-desc-Consulting');
        expect(result.single.item.unit, 'hour');
        expect(result.single.item.currency, 'MYR');
        expect(result.single.item.effectiveUnitPriceCents, 1000);
        expect(result.single.quantityMilli, 1500);
        expect(result.single.item.id, -42); // temporary, not a legacy Item id
      },
    );

    test('line sourceItemId is preserved for legacy-backed rows', () {
      final result = InvoiceFormLine.resolve(
        items: const [],
        lines: [line('Backfilled', sourceItemId: 7, quantityMilli: 2000)],
      );
      expect(result.single.item.id, 7);
      expect(result.single.quantityMilli, 2000);
    });

    test('empty -> empty', () {
      expect(
        InvoiceFormLine.resolve(items: const [], lines: const []),
        isEmpty,
      );
    });
  });

  group('subtotalCents (drives live + stored subtotal)', () {
    InvoiceFormLine fl(int quantityMilli, {int unitPriceCents = 1000}) =>
        InvoiceFormLine(
          item: item('X', unitPriceCents: unitPriceCents),
          quantityMilli: quantityMilli,
        );

    test(
      'empty -> 0',
      () => expect(InvoiceFormLine.subtotalCents(const []), 0),
    );

    test('whole quantity (2 x RM10) -> 2000', () {
      expect(InvoiceFormLine.subtotalCents([fl(2000)]), 2000);
    });

    test('non-whole quantity (1.5 x RM10) -> 1500', () {
      expect(InvoiceFormLine.subtotalCents([fl(1500)]), 1500);
    });

    test('multiple lines sum', () {
      expect(
        InvoiceFormLine.subtotalCents([fl(1500), fl(2500), fl(1000)]),
        1500 + 2500 + 1000,
      );
    });

    test('uses quantityMilli, NOT the item stockQuantity', () {
      // Item says stock 1, but the form line says 1.5 -> subtotal must be 1.5x.
      final line = InvoiceFormLine(
        item: item('X', stockQuantity: 1, unitPriceCents: 1000),
        quantityMilli: 1500,
      );
      expect(InvoiceFormLine.subtotalCents([line]), 1500);
    });
  });

  group('legacyQuantityFor (Item.stockQuantity compat, clamped >= 1)', () {
    test('whole quantities floor', () {
      expect(InvoiceFormLine.legacyQuantityFor(1000), 1);
      expect(InvoiceFormLine.legacyQuantityFor(2000), 2);
      expect(InvoiceFormLine.legacyQuantityFor(2500), 2); // 2.5 -> 2
    });
    test('fractional < 1 clamps to 1 (so legacy validation passes)', () {
      expect(InvoiceFormLine.legacyQuantityFor(250), 1); // 0.25 -> 1
      expect(InvoiceFormLine.legacyQuantityFor(999), 1); // 0.999 -> 1
      expect(InvoiceFormLine.legacyQuantityFor(1), 1); // 0.001 -> 1
    });
  });

  group('lineTotalCents getter', () {
    test('1.5 x RM10 = RM15.00', () {
      final l = InvoiceFormLine(
        item: item('X', unitPriceCents: 1000),
        quantityMilli: 1500,
      );
      expect(l.lineTotalCents, 1500);
    });
    test('0.25 x RM10 = RM2.50', () {
      final l = InvoiceFormLine(
        item: item('X', unitPriceCents: 1000),
        quantityMilli: 250,
      );
      expect(l.lineTotalCents, 250);
    });
  });

  group('parser -> form line -> subtotal (UI pipeline, Step 4C-4D-2B)', () {
    test('typing "1.5" yields a 1.5x subtotal', () {
      final q = InvoiceQuantityInput.parse('1.5').quantityMilli!;
      final line = InvoiceFormLine(
        item: item('X', unitPriceCents: 1000),
        quantityMilli: q,
      );
      expect(q, 1500);
      expect(InvoiceFormLine.subtotalCents([line]), 1500);
      expect(line.legacyQuantity, 1); // compat stockQuantity
    });

    test('typing "0.25" yields a 0.25x subtotal, compat stock 1', () {
      final q = InvoiceQuantityInput.parse('0.25').quantityMilli!;
      final line = InvoiceFormLine(
        item: item('X', unitPriceCents: 1000),
        quantityMilli: q,
      );
      expect(InvoiceFormLine.subtotalCents([line]), 250);
      expect(line.legacyQuantity, 1);
    });
  });
}
