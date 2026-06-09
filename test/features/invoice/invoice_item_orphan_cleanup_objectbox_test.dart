@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_item_orphan_cleanup.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/item/item_model.dart';

/// Stage 4D: orphan legacy Item cleanup against a real store. Requires native
/// `libobjectbox`:  flutter test --tags objectbox --run-skipped
void main() {
  late Store store;
  late InvoiceRepository repo;

  Invoice draft(String number) => Invoice(
    invoiceNumber: number,
    status: InvoiceStatus.draft.name,
    issueDate: DateTime(2026, 1, 1),
    dueDate: DateTime(2026, 1, 31),
    subtotalCents: 1000,
    totalCents: 1000,
  );

  Item itm(String name) =>
      Item(name: name, unitPrice: 10, unitPriceCents: 1000, currency: 'MYR');

  // Creates an orphan: an Item linked then unlinked (row persists, no relation).
  Future<void> makeOrphan(String number) async {
    final saved = (await repo.create(draft(number)) as Ok<Invoice>).value;
    await repo.addItemToInvoice(saved.id!, itm('Orphan-$number'));
    await repo.clearItemsFromInvoice(saved.id!);
  }

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:orphan-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = InvoiceRepository(InvoiceLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  test('no orphans -> deletes nothing', () async {
    final saved = (await repo.create(draft('INV-1')) as Ok<Invoice>).value;
    await repo.addItemToInvoice(saved.id!, itm('A')); // referenced

    final report = OrphanItemCleanup(store).run(dryRun: false);
    expect(report.orphanItems, 0);
    expect(report.deletedItems, 0);
    expect(store.box<Item>().count(), 1);
  });

  test('dry-run reports the orphan but deletes nothing', () async {
    await makeOrphan('INV-2');

    final report = OrphanItemCleanup(store).run(dryRun: true);
    expect(report.orphanItems, 1);
    expect(report.deletedItems, 0);
    expect(report.skippedItems, 1);
    expect(store.box<Item>().count(), 1); // still there
  });

  test('delete removes the orphan', () async {
    await makeOrphan('INV-3');
    expect(store.box<Item>().count(), 1);

    final report = OrphanItemCleanup(store).run(dryRun: false);
    expect(report.orphanItems, 1);
    expect(report.deletedItems, 1);
    expect(store.box<Item>().count(), 0);
  });

  test('referenced invoice items are preserved (mixed with an orphan)', () async {
    final saved = (await repo.create(draft('INV-4')) as Ok<Invoice>).value;
    await repo.addItemToInvoice(saved.id!, itm('Keep')); // referenced
    await makeOrphan('INV-5'); // one orphan

    final report = OrphanItemCleanup(store).run(dryRun: false);
    expect(report.scannedItems, 2);
    expect(report.referencedItems, 1);
    expect(report.deletedItems, 1);
    expect(store.box<Item>().count(), 1); // the referenced 'Keep' remains
  });

  test('items across multiple invoices are all preserved', () async {
    final a = (await repo.create(draft('INV-6')) as Ok<Invoice>).value;
    final b = (await repo.create(draft('INV-7')) as Ok<Invoice>).value;
    await repo.addItemToInvoice(a.id!, itm('A1'));
    await repo.addItemToInvoice(a.id!, itm('A2'));
    await repo.addItemToInvoice(b.id!, itm('B1'));

    final report = OrphanItemCleanup(store).run(dryRun: false);
    expect(report.deletedItems, 0);
    expect(store.box<Item>().count(), 3);
  });

  test('cleanup is idempotent', () async {
    await makeOrphan('INV-8');

    expect(OrphanItemCleanup(store).run(dryRun: false).deletedItems, 1);
    expect(OrphanItemCleanup(store).run(dryRun: false).deletedItems, 0);
  });

  test('item referenced only by InvoiceLine.sourceItemId is preserved', () async {
    final saved = (await repo.create(draft('INV-9')) as Ok<Invoice>).value;
    // An Item not linked via Invoice.items...
    final orphanLikeId = store.box<Item>().put(itm('Sourced'));
    // ...but claimed as the provenance of a persisted line.
    await repo.replaceInvoiceLines(saved.id!, [
      InvoiceLine(
        sourceItemId: orphanLikeId,
        name: 'Sourced',
        unitPriceCents: 1000,
        quantityMilli: 1000,
      ),
    ]);

    final report = OrphanItemCleanup(store).run(dryRun: false);
    expect(report.deletedItems, 0); // guard preserved it
    expect(store.box<Item>().get(orphanLikeId), isNotNull);
  });
}
