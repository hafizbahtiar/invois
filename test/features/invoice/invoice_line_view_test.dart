import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';

void main() {
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

  group('InvoiceLineReader.resolveLinesOnly', () {
    test('uses InvoiceLine rows sorted by sortOrder', () {
      final views = InvoiceLineReader.resolveLinesOnly([
        line('B', sortOrder: 1),
        line('A', sortOrder: 0),
      ]);
      expect(views.map((v) => v.name), ['A', 'B']);
    });

    test('missing lines -> empty list', () {
      expect(InvoiceLineReader.resolveLinesOnly(const []), isEmpty);
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

  group('line total + display', () {
    test('lineTotalCents uses InvoiceLineMath (RM10 x 2.5 = 2500c)', () {
      final v = InvoiceLineView.fromLine(
        line('A', unitPriceCents: 1000, quantityMilli: 2500),
      );
      expect(v.lineTotalCents, 2500);
      expect(v.displayQuantity, '2.5');
    });
  });
}
