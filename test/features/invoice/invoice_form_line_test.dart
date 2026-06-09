import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';
import 'package:invois/features/item/item_model.dart';

/// Step 4C-4D-2A: in-memory decimal-quantity carrier for the form. Pure tests
/// (no store, no UI).
void main() {
  Item item(String name, {int? stockQuantity, int unitPriceCents = 1000}) => Item(
    name: name,
    unitPrice: unitPriceCents / 100,
    unitPriceCents: unitPriceCents,
    stockQuantity: stockQuantity,
  );

  InvoiceLine line(String name, {required int quantityMilli, int sortOrder = 0}) =>
      InvoiceLine(
        name: name,
        unitPriceCents: 1000,
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
    test('non-whole 1500 is held without loss; legacyQuantity truncates to 1', () {
      final l = InvoiceFormLine(item: item('A'), quantityMilli: 1500);
      expect(l.quantityMilli, 1500); // preserved
      expect(l.legacyQuantity, 1); // documented truncation for legacy UI
    });
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

    test('lines present (count matches) win, paired by sortOrder', () {
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

    test('count mismatch -> fall back to items (safety)', () {
      final result = InvoiceFormLine.resolve(
        items: [item('A', stockQuantity: 3)],
        lines: [
          line('A', quantityMilli: 1500),
          line('extra', quantityMilli: 1000, sortOrder: 1),
        ],
      );
      expect(result.single.quantityMilli, 3000); // from item, not line
    });

    test('empty -> empty', () {
      expect(
        InvoiceFormLine.resolve(items: const [], lines: const []),
        isEmpty,
      );
    });
  });
}
