@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';
import 'package:invois/features/invoice/invoice_line_builder.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';
import 'package:invois/features/item/item_model.dart';

/// Stage 4E-1: line-only write mechanism (`replaceInvoiceLines` +
/// `InvoiceLineBuilder`, as called by `onUpsert`). Requires native
/// `libobjectbox`:
///   flutter test --tags objectbox --run-skipped
void main() {
  late Store store;
  late InvoiceRepository repo;

  Invoice draft(String number) => Invoice(
    invoiceNumber: number,
    status: InvoiceStatus.draft.name,
    issueDate: DateTime(2026, 1, 1),
    dueDate: DateTime(2026, 1, 31),
    subtotalCents: 10000,
    totalCents: 10000,
  );

  Item item(String name, {required int qty, int unitPriceCents = 1000}) => Item(
    name: name,
    unitPrice: unitPriceCents / 100,
    unitPriceCents: unitPriceCents,
    currency: 'MYR',
    stockQuantity: qty,
  );

  InvoiceFormLine formLine(
    String name, {
    required int quantityMilli,
    int unitPriceCents = 1000,
    int? sourceItemId,
  }) => InvoiceFormLine(
    item: item(name, qty: 1, unitPriceCents: unitPriceCents)..id = sourceItemId,
    quantityMilli: quantityMilli,
  );

  // Mimics Stage 4E-1 onUpsert persistence: invoice row, then Invoice.lines
  // only. No legacy Item rows or Invoice.items relation writes.
  Future<Invoice> save(String number, List<InvoiceFormLine> lines) async {
    final saved = (await repo.create(draft(number)) as Ok<Invoice>).value;
    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines(lines),
    );
    return saved;
  }

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:dualwrite-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = InvoiceRepository(InvoiceLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  test('create writes Invoice.lines and no legacy Invoice.items', () async {
    final saved = await save('INV-1', [
      formLine('A', quantityMilli: 2000),
      formLine('B', quantityMilli: 1000),
    ]);

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.items, isEmpty); // no new legacy relation writes
    expect(store.box<Item>().count(), 0); // no new legacy rows
    expect(invoice.lines.length, 2); // lines written

    final views = InvoiceLineReader.fromInvoiceLinesOnly(invoice);
    expect(views.map((v) => v.name), ['A', 'B']);
    expect(views[0].quantityMilli, 2000);
  });

  test('edit replaces lines (no duplicates, count matches)', () async {
    final saved = await save('INV-2', [
      formLine('A', quantityMilli: 1000),
      formLine('B', quantityMilli: 1000),
    ]);

    // Re-save with a different set (B removed, C added).
    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines([
        formLine('A', quantityMilli: 1000),
        formLine('C', quantityMilli: 3000),
      ]),
    );

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.lines.length, 2); // not 4
    expect(store.box<InvoiceLine>().count(), 2); // no orphaned line rows
    expect(invoice.items, isEmpty);
    expect(store.box<Item>().count(), 0);
    final names =
        (invoice.lines.toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
            .map((l) => l.name);
    expect(names, ['A', 'C']);
  });

  test(
    'removing all submitted lines clears lines and creates no legacy items',
    () async {
      final saved = await save('INV-3', [formLine('A', quantityMilli: 1000)]);

      await repo.replaceInvoiceLines(
        saved.id!,
        InvoiceLineBuilder.fromFormLines(const []),
      );

      expect(store.box<InvoiceLine>().count(), 0);
      expect(store.box<Invoice>().get(saved.id!)!.items, isEmpty);
      expect(store.box<Item>().count(), 0);
    },
  );

  test('idempotent re-save keeps the same line count/order', () async {
    final lines = [
      formLine('A', quantityMilli: 1000),
      formLine('B', quantityMilli: 2000),
    ];
    final saved = await save('INV-4', lines);

    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines(lines),
    );
    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines(lines),
    );

    expect(store.box<Invoice>().get(saved.id!)!.lines.length, 2);
    expect(store.box<InvoiceLine>().count(), 2);
    expect(store.box<Item>().count(), 0);
  });

  test('stored subtotal snapshot is unchanged by line writes', () async {
    final saved = await save('INV-5', [formLine('A', quantityMilli: 1000)]);
    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.subtotalCents, 10000); // from draft(), untouched
    expect(invoice.totalCents, 10000);
  });

  test(
    'fromFormLines persists the exact decimal quantityMilli (Step 4C-4D-2C)',
    () async {
      final saved = (await repo.create(draft('INV-DEC')) as Ok<Invoice>).value;

      await repo.replaceInvoiceLines(
        saved.id!,
        InvoiceLineBuilder.fromFormLines([
          InvoiceFormLine(
            item: item('Hours', qty: 1, unitPriceCents: 1000),
            quantityMilli: 1500, // 1.5 — must survive persistence
          ),
        ]),
      );

      final invoice = store.box<Invoice>().get(saved.id!)!;
      expect(invoice.lines.single.quantityMilli, 1500);
      // The unified reader (detail/PDF) then sees 1.5 x RM10 = RM15.00.
      expect(
        InvoiceLineReader.fromInvoiceLinesOnly(invoice).single.lineTotalCents,
        1500,
      );
      expect(invoice.items, isEmpty);
      expect(store.box<Item>().count(), 0);
    },
  );

  test(
    'line-only edit leaves pre-existing legacy Item rows untouched',
    () async {
      final saved = (await repo.create(draft('INV-OLD')) as Ok<Invoice>).value;
      await repo.addItemToInvoice(
        saved.id!,
        item('Legacy', qty: 1, unitPriceCents: 1000),
      );
      final legacyItemCount = store.box<Item>().count();

      await repo.replaceInvoiceLines(
        saved.id!,
        InvoiceLineBuilder.fromFormLines([
          formLine('Edited', quantityMilli: 2500, unitPriceCents: 1000),
        ]),
      );

      final invoice = store.box<Invoice>().get(saved.id!)!;
      expect(store.box<Item>().count(), legacyItemCount); // no new legacy rows
      expect(invoice.items.single.name, 'Legacy'); // old relation retained
      final views = InvoiceLineReader.fromInvoiceLinesOnly(invoice);
      expect(views.single.name, 'Edited'); // lines are authoritative
      expect(views.single.quantityMilli, 2500);
    },
  );
}
