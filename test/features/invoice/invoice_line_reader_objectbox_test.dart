@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_line_backfill.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/invoice/invoice_line_view.dart';
import 'package:invois/features/item/item_model.dart';

/// Exercises production line-only reads and migration/recovery fallback reads
/// against a real store. Requires native `libobjectbox`:
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

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:line-reader-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = InvoiceRepository(InvoiceLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  test('production reader does not fall back to legacy Item rows', () async {
    final saved = (await repo.create(draft('INV-L0')) as Ok<Invoice>).value;
    await repo.addItemToInvoice(
      saved.id!,
      Item(
        name: 'Legacy',
        unitPrice: 10,
        unitPriceCents: 1000,
        stockQuantity: 2,
      ),
    );

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(InvoiceLineReader.fromInvoiceLinesOnly(invoice), isEmpty);
  });

  test('migration/recovery reader falls back to Item rows', () async {
    final saved = (await repo.create(draft('INV-L1')) as Ok<Invoice>).value;
    await repo.addItemToInvoice(
      saved.id!,
      Item(
        name: 'Legacy',
        unitPrice: 10,
        unitPriceCents: 1000,
        stockQuantity: 2,
      ),
    );

    final invoice = store.box<Invoice>().get(saved.id!)!;
    final views = InvoiceLineReader.fromInvoiceWithLegacyFallback(invoice);

    expect(views.single.name, 'Legacy');
    expect(views.single.quantityMilli, 2000); // stockQuantity 2 -> 2000
    expect(views.single.lineTotalCents, 2000); // RM10 x 2
  });

  test(
    'backfilled invoice (has lines) prefers InvoiceLine snapshots',
    () async {
      final saved = (await repo.create(draft('INV-L2')) as Ok<Invoice>).value;
      await repo.addItemToInvoice(
        saved.id!,
        Item(
          name: 'Source',
          unitPrice: 10,
          unitPriceCents: 1000,
          stockQuantity: 5,
        ),
      );
      // Create the InvoiceLine snapshots from legacy items.
      InvoiceLineBackfill(store).run();

      final invoice = store.box<Invoice>().get(saved.id!)!;
      final views = InvoiceLineReader.fromInvoiceWithLegacyFallback(invoice);

      expect(views.length, 1);
      expect(views.single.name, 'Source');
      expect(views.single.quantityMilli, 5000);
      expect(views.single.sourceItemId, isNotNull); // came from a line snapshot
    },
  );

  test('empty invoice -> empty views', () async {
    final saved = (await repo.create(draft('INV-L3')) as Ok<Invoice>).value;
    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(InvoiceLineReader.fromInvoiceWithLegacyFallback(invoice), isEmpty);
  });
}
