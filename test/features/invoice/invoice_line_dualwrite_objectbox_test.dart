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

/// Step 4C-4B: dual-write mechanism (`replaceInvoiceLines` + `InvoiceLineBuilder`,
/// as called by `onUpsert`). Requires native `libobjectbox`:
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

  // Mimics onUpsert's persistence: legacy items, then dual-write lines.
  Future<Invoice> save(String number, List<Item> items) async {
    final saved = (await repo.create(draft(number)) as Ok<Invoice>).value;
    await repo.clearItemsFromInvoice(saved.id!);
    for (final it in items) {
      await repo.addItemToInvoice(saved.id!, it);
    }
    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromItems(items),
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

  test('create writes both legacy items and Invoice.lines', () async {
    final saved = await save('INV-1', [
      item('A', qty: 2),
      item('B', qty: 1),
    ]);

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.items.length, 2); // legacy retained
    expect(invoice.lines.length, 2); // lines written

    final views = InvoiceLineReader.fromInvoice(invoice);
    expect(views.map((v) => v.name), ['A', 'B']);
    expect(views[0].quantityMilli, 2000);
  });

  test('edit replaces lines (no duplicates, count matches)', () async {
    final saved = await save('INV-2', [item('A', qty: 1), item('B', qty: 1)]);

    // Re-save with a different set (B removed, C added).
    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromItems([item('A', qty: 1), item('C', qty: 3)]),
    );

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.lines.length, 2); // not 4
    expect(store.box<InvoiceLine>().count(), 2); // no orphaned line rows
    final names =
        (invoice.lines.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
            .map((l) => l.name);
    expect(names, ['A', 'C']);
  });

  test('removing all submitted items clears lines but keeps legacy item rows',
      () async {
    final saved = await save('INV-3', [item('A', qty: 1)]);
    final itemRowsBefore = store.box<Item>().count();

    await repo.replaceInvoiceLines(saved.id!, InvoiceLineBuilder.fromItems([]));

    expect(store.box<InvoiceLine>().count(), 0);
    expect(store.box<Item>().count(), itemRowsBefore); // legacy untouched
  });

  test('idempotent re-save keeps the same line count/order', () async {
    final items = [item('A', qty: 1), item('B', qty: 2)];
    final saved = await save('INV-4', items);

    await repo.replaceInvoiceLines(saved.id!, InvoiceLineBuilder.fromItems(items));
    await repo.replaceInvoiceLines(saved.id!, InvoiceLineBuilder.fromItems(items));

    expect(store.box<Invoice>().get(saved.id!)!.lines.length, 2);
    expect(store.box<InvoiceLine>().count(), 2);
  });

  test('stored subtotal snapshot is unchanged by the dual-write', () async {
    final saved = await save('INV-5', [item('A', qty: 1)]);
    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.subtotalCents, 10000); // from draft(), untouched
    expect(invoice.totalCents, 10000);
  });

  test('fromFormLines persists the exact decimal quantityMilli (Step 4C-4D-2C)',
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
    expect(InvoiceLineReader.fromInvoice(invoice).single.lineTotalCents, 1500);
  });
}
