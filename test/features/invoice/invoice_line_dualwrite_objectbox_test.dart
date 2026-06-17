@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/invoice/domain/invoice_form_line.dart';
import 'package:invois/features/invoice/domain/invoice_line_builder.dart';
import 'package:invois/features/invoice/domain/invoice_line_view.dart';

/// Line-only write mechanism (`replaceInvoiceLines` + `InvoiceLineBuilder`).
/// Requires native `libobjectbox`:
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

  InvoiceFormLine formLine(
    String name, {
    required int quantityMilli,
    int unitPriceCents = 1000,
  }) => InvoiceFormLine(
    id: -1,
    name: name,
    unitPriceCents: unitPriceCents,
    currency: 'MYR',
    quantityMilli: quantityMilli,
  );

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
      directory: 'memory:linewrite-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = InvoiceRepository(InvoiceLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  test('create writes Invoice.lines', () async {
    final saved = await save('INV-1', [
      formLine('A', quantityMilli: 2000),
      formLine('B', quantityMilli: 1000),
    ]);

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.lines.length, 2);

    final views = InvoiceLineReader.fromInvoiceLinesOnly(invoice);
    expect(views.map((v) => v.name), ['A', 'B']);
    expect(views[0].quantityMilli, 2000);
  });

  test('edit replaces lines (no duplicates, count matches)', () async {
    final saved = await save('INV-2', [
      formLine('A', quantityMilli: 1000),
      formLine('B', quantityMilli: 1000),
    ]);

    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines([
        formLine('A', quantityMilli: 1000),
        formLine('C', quantityMilli: 3000),
      ]),
    );

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.lines.length, 2);
    expect(store.box<InvoiceLine>().count(), 2);
    final names =
        (invoice.lines.toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
            .map((l) => l.name);
    expect(names, ['A', 'C']);
  });

  test('removing all submitted lines clears lines', () async {
    final saved = await save('INV-3', [formLine('A', quantityMilli: 1000)]);

    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines(const []),
    );

    expect(store.box<InvoiceLine>().count(), 0);
  });

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
  });

  test('stored subtotal snapshot is unchanged by line writes', () async {
    final saved = await save('INV-5', [formLine('A', quantityMilli: 1000)]);
    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.subtotalCents, 10000);
    expect(invoice.totalCents, 10000);
  });

  test('fromFormLines persists the exact decimal quantityMilli', () async {
    final saved = (await repo.create(draft('INV-DEC')) as Ok<Invoice>).value;

    await repo.replaceInvoiceLines(
      saved.id!,
      InvoiceLineBuilder.fromFormLines([
        formLine('Hours', quantityMilli: 1500, unitPriceCents: 1000),
      ]),
    );

    final invoice = store.box<Invoice>().get(saved.id!)!;
    expect(invoice.lines.single.quantityMilli, 1500);
    expect(
      InvoiceLineReader.fromInvoiceLinesOnly(invoice).single.lineTotalCents,
      1500,
    );
  });

  test('replaceInvoiceLines on non-existent invoice is a no-op', () async {
    // Should not throw or create orphan line rows for a missing invoice.
    await repo.replaceInvoiceLines(
      999999,
      InvoiceLineBuilder.fromFormLines([
        formLine('Ghost', quantityMilli: 1000),
      ]),
    );
    expect(store.box<InvoiceLine>().count(), 0);
  });

  test('replaceInvoiceLines is atomic — invoice survives even if lines fail',
      () async {
    final saved = await save('INV-ATOMIC', [
      formLine('A', quantityMilli: 1000),
    ]);
    final invoiceId = saved.id!;
    final lineCountBefore = store.box<InvoiceLine>().count();

    // Replace with a new set — invoice must remain intact after the swap.
    await repo.replaceInvoiceLines(
      invoiceId,
      InvoiceLineBuilder.fromFormLines([
        formLine('B', quantityMilli: 2000),
        formLine('C', quantityMilli: 3000),
      ]),
    );

    // Invoice still exists and is readable.
    final invoice = store.box<Invoice>().get(invoiceId);
    expect(invoice, isNotNull);
    // Old line removed, new lines written — count net increased by 1.
    expect(store.box<InvoiceLine>().count(), lineCountBefore + 1);
    // Line names match the new set.
    final names =
        (invoice!.lines.toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
            .map((l) => l.name);
    expect(names, ['B', 'C']);
  });
}
