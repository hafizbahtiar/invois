@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_line_backfill.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/item/item_model.dart';

/// Step 4B: additive, idempotent InvoiceLine backfill. Requires native
/// `libobjectbox` — tagged `objectbox`, skipped by default:
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

  Future<Invoice> seedInvoiceWithItems(String number, List<Item> items) async {
    final saved = (await repo.create(draft(number)) as Ok<Invoice>).value;
    for (final item in items) {
      await repo.addItemToInvoice(saved.id!, item);
    }
    return saved;
  }

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:line-backfill-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = InvoiceRepository(InvoiceLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  test('store opens with the regenerated model (InvoiceLine present)', () {
    expect(store.box<InvoiceLine>().count(), 0);
  });

  test('creates one InvoiceLine per legacy item, preserving order + snapshot',
      () async {
    final saved = await seedInvoiceWithItems('INV-1', [
      Item(name: 'Alpha', unitPrice: 10, unitPriceCents: 1000, stockQuantity: 2),
      Item(name: 'Beta', unitPrice: 5, unitPriceCents: 500, stockQuantity: null),
    ]);

    final report = InvoiceLineBackfill(store).run();
    expect(report.invoicesBackfilled, 1);
    expect(report.linesCreated, 2);

    final lines =
        (store.box<Invoice>().get(saved.id!)!.lines.toList())
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    expect(lines.map((l) => l.name), ['Alpha', 'Beta']);
    expect(lines[0].quantityMilli, 2000);
    expect(lines[1].quantityMilli, 1000); // null legacy qty -> one unit
    expect(lines[0].unitPriceCents, 1000);
    expect(lines[1].unitPriceCents, 500);
    expect(lines[0].sourceItemId, isNotNull);
  });

  test('is idempotent — second run creates nothing', () async {
    await seedInvoiceWithItems('INV-2', [
      Item(name: 'A', unitPrice: 10, unitPriceCents: 1000, stockQuantity: 1),
    ]);

    final first = InvoiceLineBackfill(store).run();
    expect(first.invoicesBackfilled, 1);

    final second = InvoiceLineBackfill(store).run();
    expect(second.invoicesBackfilled, 0);
    expect(second.linesCreated, 0);
    expect(store.box<InvoiceLine>().count(), 1);
  });

  test('does not delete or mutate legacy Item rows', () async {
    await seedInvoiceWithItems('INV-3', [
      Item(name: 'A', unitPrice: 10, unitPriceCents: 1000, stockQuantity: 3),
      Item(name: 'B', unitPrice: 2, unitPriceCents: 200, stockQuantity: 4),
    ]);
    final itemsBefore = store.box<Item>().count();

    InvoiceLineBackfill(store).run();

    expect(store.box<Item>().count(), itemsBefore); // legacy items untouched
  });

  test('skips an invoice with no legacy items', () async {
    await repo.create(draft('INV-EMPTY'));

    final report = InvoiceLineBackfill(store).run();
    expect(report.invoicesBackfilled, 0);
    expect(report.linesCreated, 0);
    expect(store.box<InvoiceLine>().count(), 0);
  });

  test('handles invalid legacy quantity safely (<=0 -> one unit)', () async {
    final saved = await seedInvoiceWithItems('INV-4', [
      Item(name: 'Z', unitPrice: 10, unitPriceCents: 1000, stockQuantity: 0),
    ]);

    InvoiceLineBackfill(store).run();

    final line = store.box<Invoice>().get(saved.id!)!.lines.first;
    expect(line.quantityMilli, 1000);
  });
}
