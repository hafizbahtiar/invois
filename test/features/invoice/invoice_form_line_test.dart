import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';
import 'package:invois/features/invoice/invoice_quantity_input.dart';

void main() {
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

  InvoiceFormLine draft(
    int quantityMilli, {
    String name = 'X',
    int unitPriceCents = 1000,
  }) => InvoiceFormLine(
    id: -1,
    name: name,
    unitPriceCents: unitPriceCents,
    quantityMilli: quantityMilli,
  );

  group('resolve', () {
    test('lines are sorted by sortOrder', () {
      final result = InvoiceFormLine.resolve(
        lines: [
          line('B', quantityMilli: 2500, sortOrder: 1),
          line('A', quantityMilli: 1500, sortOrder: 0),
        ],
      );
      expect(result.map((l) => l.name), ['A', 'B']);
      expect(result.map((l) => l.quantityMilli), [1500, 2500]);
    });

    test('rebuilds plain form drafts from InvoiceLine snapshots', () {
      final result = InvoiceFormLine.resolve(
        lines: [
          line(
            'Consulting',
            id: 42,
            sourceItemId: 7,
            quantityMilli: 1500,
            unitPriceCents: 1000,
          ),
        ],
      );
      expect(result.single.id, -42);
      expect(result.single.sourceItemId, 7);
      expect(result.single.name, 'Consulting');
      expect(result.single.description, 'line-desc-Consulting');
      expect(result.single.unit, 'hour');
      expect(result.single.currency, 'MYR');
      expect(result.single.unitPriceCents, 1000);
      expect(result.single.quantityMilli, 1500);
    });

    test('empty -> empty', () {
      expect(InvoiceFormLine.resolve(lines: const []), isEmpty);
    });
  });

  group('subtotalCents', () {
    test('empty -> 0', () {
      expect(InvoiceFormLine.subtotalCents(const []), 0);
    });

    test('whole quantity (2 x RM10) -> 2000', () {
      expect(InvoiceFormLine.subtotalCents([draft(2000)]), 2000);
    });

    test('non-whole quantity (1.5 x RM10) -> 1500', () {
      expect(InvoiceFormLine.subtotalCents([draft(1500)]), 1500);
    });

    test('multiple lines sum', () {
      expect(
        InvoiceFormLine.subtotalCents([draft(1500), draft(2500), draft(1000)]),
        1500 + 2500 + 1000,
      );
    });
  });

  group('lineTotalCents getter', () {
    test('1.5 x RM10 = RM15.00', () {
      expect(draft(1500).lineTotalCents, 1500);
    });

    test('0.25 x RM10 = RM2.50', () {
      expect(draft(250).lineTotalCents, 250);
    });
  });

  group('parser -> form line -> subtotal', () {
    test('typing "1.5" yields a 1.5x subtotal', () {
      final q = InvoiceQuantityInput.parse('1.5').quantityMilli!;
      final formLine = draft(q);
      expect(q, 1500);
      expect(InvoiceFormLine.subtotalCents([formLine]), 1500);
    });

    test('typing "0.25" yields a 0.25x subtotal', () {
      final q = InvoiceQuantityInput.parse('0.25').quantityMilli!;
      final formLine = draft(q);
      expect(InvoiceFormLine.subtotalCents([formLine]), 250);
    });
  });
}
