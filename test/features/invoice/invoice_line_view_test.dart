import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';
import 'package:invois/features/item/item_model.dart';

/// Pure line readers. Production uses InvoiceLine rows only; migration/recovery
/// helpers keep the legacy Item fallback. No ObjectBox store needed — entities
/// are constructed directly.
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
    int quantityMilli = 1000,
    int unitPriceCents = 1000,
    int sortOrder = 0,
  }) => InvoiceLine(
    name: name,
    unitPriceCents: unitPriceCents,
    quantityMilli: quantityMilli,
    sortOrder: sortOrder,
  );

  group('InvoiceLineReader.resolveLinesOnly — production source', () {
    test('uses InvoiceLine rows sorted by sortOrder', () {
      final views = InvoiceLineReader.resolveLinesOnly([
        line('B', sortOrder: 1),
        line('A', sortOrder: 0),
      ]);
      expect(views.map((v) => v.name), ['A', 'B']);
    });

    test('does not fall back to legacy items', () {
      final views = InvoiceLineReader.resolveLinesOnly(const []);
      expect(views, isEmpty);
    });

    test('subtotalCentsFromLines uses only InvoiceLine rows', () {
      expect(
        InvoiceLineReader.subtotalCentsFromLines([
          line('A', unitPriceCents: 1000, quantityMilli: 2500),
          line('B', unitPriceCents: 500, quantityMilli: 1000),
        ]),
        3000,
      );
    });
  });

  group('InvoiceLineReader.resolve — migration/recovery fallback', () {
    test('prefers InvoiceLine rows when lines is non-empty', () {
      final views = InvoiceLineReader.resolve(
        lines: [line('FromLine')],
        items: [item('FromItem')],
      );
      expect(views.map((v) => v.name), ['FromLine']);
    });

    test('falls back to legacy items when lines is empty', () {
      final views = InvoiceLineReader.resolve(
        lines: const [],
        items: [item('FromItem', stockQuantity: 2)],
      );
      expect(views.single.name, 'FromItem');
      expect(views.single.quantityMilli, 2000);
    });

    test('empty invoice -> empty list', () {
      expect(
        InvoiceLineReader.resolve(lines: const [], items: const []),
        isEmpty,
      );
    });
  });

  group('legacy quantity mapping', () {
    test('null -> 1000', () {
      final v = InvoiceLineReader.resolve(
        lines: const [],
        items: [item('A', stockQuantity: null)],
      ).single;
      expect(v.quantityMilli, 1000);
    });

    test('<= 0 -> 1000', () {
      final v = InvoiceLineReader.resolve(
        lines: const [],
        items: [item('A', stockQuantity: 0)],
      ).single;
      expect(v.quantityMilli, 1000);
    });

    test('2 -> 2000', () {
      final v = InvoiceLineReader.resolve(
        lines: const [],
        items: [item('A', stockQuantity: 2)],
      ).single;
      expect(v.quantityMilli, 2000);
    });
  });

  group('line total + display', () {
    test('lineTotalCents uses InvoiceLineMath (RM10 x 2.5 = 2500c)', () {
      final v = InvoiceLineView.fromLine(
        line('A', unitPriceCents: 1000, quantityMilli: 2500),
      );
      expect(v.lineTotalCents, 2500);
      expect(v.displayQuantity, '2.5');
    });

    test('legacy item line total (RM10 x 3 = 3000c)', () {
      final v = InvoiceLineReader.resolve(
        lines: const [],
        items: [item('A', stockQuantity: 3, unitPriceCents: 1000)],
      ).single;
      expect(v.lineTotalCents, 3000);
    });
  });

  group('order preservation', () {
    test('InvoiceLine rows are sorted by sortOrder', () {
      final views = InvoiceLineReader.resolve(
        lines: [
          line('B', sortOrder: 1),
          line('A', sortOrder: 0),
          line('C', sortOrder: 2),
        ],
        items: const [],
      );
      expect(views.map((v) => v.name), ['A', 'B', 'C']);
    });

    test('legacy items keep relation order, sortOrder assigned by index', () {
      final views = InvoiceLineReader.resolve(
        lines: const [],
        items: [item('first'), item('second'), item('third')],
      );
      expect(views.map((v) => v.name), ['first', 'second', 'third']);
      expect(views.map((v) => v.sortOrder), [0, 1, 2]);
    });
  });

  test('mixed: when both lines and items exist, only lines are used', () {
    final views = InvoiceLineReader.resolve(
      lines: [line('L1'), line('L2', sortOrder: 1)],
      items: [item('I1'), item('I2')],
    );
    expect(views.map((v) => v.name), ['L1', 'L2']);
  });
}
