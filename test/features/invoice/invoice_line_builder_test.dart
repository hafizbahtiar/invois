import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/invoice_composer.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';
import 'package:invois/features/invoice/invoice_line_builder.dart';
import 'package:invois/features/item/item_model.dart';

/// Pure builder that maps submitted form rows or legacy items to InvoiceLine
/// snapshots.
void main() {
  Item item(
    String name, {
    int? stockQuantity,
    int unitPriceCents = 1000,
    int? id,
  }) => Item(
    id: id,
    name: name,
    description: 'desc-$name',
    unit: 'piece',
    currency: 'MYR',
    unitPrice: unitPriceCents / 100,
    unitPriceCents: unitPriceCents,
    stockQuantity: stockQuantity,
  );

  test('maps fields and preserves order', () {
    final lines = InvoiceLineBuilder.fromItems([
      item('A', id: 11, stockQuantity: 2, unitPriceCents: 1000),
      item('B', id: 12, stockQuantity: 1, unitPriceCents: 500),
    ]);

    expect(lines.map((l) => l.name), ['A', 'B']);
    expect(lines.map((l) => l.sortOrder), [0, 1]);
    expect(lines[0].quantityMilli, 2000);
    expect(lines[0].unitPriceCents, 1000);
    expect(lines[0].description, 'desc-A');
    expect(lines[0].unit, 'piece');
    expect(lines[0].currency, 'MYR');
    expect(lines[0].sourceItemId, 11);
  });

  test('quantity mapping: null/<=0 -> 1000, n -> n*1000', () {
    expect(
      InvoiceLineBuilder.fromItems([
        item('A', stockQuantity: null),
      ]).single.quantityMilli,
      1000,
    );
    expect(
      InvoiceLineBuilder.fromItems([
        item('A', stockQuantity: 0),
      ]).single.quantityMilli,
      1000,
    );
    expect(
      InvoiceLineBuilder.fromItems([
        item('A', stockQuantity: 4),
      ]).single.quantityMilli,
      4000,
    );
  });

  test('unsaved item (id 0/null) -> sourceItemId null', () {
    final lines = InvoiceLineBuilder.fromItems([item('A', id: 0)]);
    expect(lines.single.sourceItemId, isNull);
  });

  test('sum of built line totals equals legacy composer subtotal', () {
    final items = [
      item('A', stockQuantity: 1, unitPriceCents: 1000),
      item('B', stockQuantity: 3, unitPriceCents: 333),
      item('C', stockQuantity: 2, unitPriceCents: 500),
    ];
    final builtSubtotal = InvoiceLineBuilder.fromItems(items).fold(0, (sum, l) {
      return sum + ((l.unitPriceCents * l.quantityMilli + 500) ~/ 1000);
    });
    final composerSubtotal = InvoiceComposer.subtotalCents(
      items.map(
        (i) => ComposerLine(
          unitPriceCents: i.effectiveUnitPriceCents,
          quantity: i.stockQuantity ?? 1,
        ),
      ),
    );
    expect(builtSubtotal, composerSubtotal);
  });

  group('fromFormLines (authoritative quantityMilli)', () {
    test('preserves exact quantityMilli (not from stockQuantity)', () {
      final lines = InvoiceLineBuilder.fromFormLines([
        InvoiceFormLine(
          item: item('A', id: 7, stockQuantity: 1, unitPriceCents: 1000),
          quantityMilli: 1500, // 1.5 — diverges from stockQuantity
        ),
      ]);
      expect(lines.single.quantityMilli, 1500);
      expect(lines.single.unitPriceCents, 1000);
      expect(lines.single.sourceItemId, 7);
      expect(lines.single.sortOrder, 0);
    });

    test('preserves order and maps fields', () {
      final lines = InvoiceLineBuilder.fromFormLines([
        InvoiceFormLine(item: item('A'), quantityMilli: 1000),
        InvoiceFormLine(item: item('B'), quantityMilli: 2500),
      ]);
      expect(lines.map((l) => l.name), ['A', 'B']);
      expect(lines.map((l) => l.quantityMilli), [1000, 2500]);
      expect(lines.map((l) => l.sortOrder), [0, 1]);
    });

    test('negative temporary form ids do not become legacy sourceItemId', () {
      final lines = InvoiceLineBuilder.fromFormLines([
        InvoiceFormLine(item: item('LineOnly', id: -42), quantityMilli: 1500),
      ]);
      expect(lines.single.sourceItemId, isNull);
    });
  });
}
