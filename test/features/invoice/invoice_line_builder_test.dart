import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/domain/invoice_form_line.dart';
import 'package:invois/features/invoice/domain/invoice_line_builder.dart';

void main() {
  InvoiceFormLine formLine(
    String name, {
    int quantityMilli = 1000,
    int unitPriceCents = 1000,
    int? sourceItemId,
  }) => InvoiceFormLine(
    id: -1,
    sourceItemId: sourceItemId,
    name: name,
    description: 'desc-$name',
    unit: 'piece',
    currency: 'MYR',
    unitPriceCents: unitPriceCents,
    quantityMilli: quantityMilli,
  );

  test('maps fields and preserves order', () {
    final lines = InvoiceLineBuilder.fromFormLines([
      formLine('A', sourceItemId: 11, quantityMilli: 2000),
      formLine('B', sourceItemId: 12, quantityMilli: 1000, unitPriceCents: 500),
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

  test('preserves exact decimal quantityMilli', () {
    final lines = InvoiceLineBuilder.fromFormLines([
      formLine('A', quantityMilli: 1500, unitPriceCents: 1000),
    ]);
    expect(lines.single.quantityMilli, 1500);
    expect(lines.single.unitPriceCents, 1000);
    expect(lines.single.sortOrder, 0);
  });
}
