@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_query.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';

/// Repository / local-source integration tests against a real (in-memory)
/// ObjectBox store. Tagged `objectbox` because they require the native
/// `libobjectbox` library on the host — see doc/testing.md. Excluded from the
/// default `flutter test` run; run with `flutter test --tags objectbox`.
void main() {
  late Store store;
  late InvoiceRepository repo;

  Invoice draft(String number, {InvoiceStatus status = InvoiceStatus.draft}) {
    return Invoice(
      invoiceNumber: number,
      status: status.name,
      issueDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 31),
      subtotalCents: 10000,
      totalCents: 10000,
    );
  }

  setUp(() {
    // Unique in-memory store per test for isolation.
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:invoice-repo-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = InvoiceRepository(InvoiceLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  group('InvoiceRepository CRUD', () {
    test('create persists and returns Ok with a non-zero id', () async {
      final result = await repo.create(draft('INV-001'));
      expect(result, isA<Ok<Invoice>>());
      final saved = (result as Ok<Invoice>).value;
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final fetched = await repo.getCompleteInvoice(saved.id!);
      expect(fetched?.invoiceNumber, 'INV-001');
    });

    test('create dual-writes the legacy double from cents', () async {
      final saved =
          (await repo.create(draft('INV-002')) as Ok<Invoice>).value;
      final fetched = await repo.getCompleteInvoice(saved.id!);
      expect(fetched?.totalCents, 10000);
      expect(fetched?.total, 100.0); // dual-written from cents
    });

    test('update mutates the stored row', () async {
      final saved =
          (await repo.create(draft('INV-003')) as Ok<Invoice>).value;
      final updated = await repo.update(
        saved.copyWith(status: InvoiceStatus.sent.name),
      );
      expect(updated, isA<Ok<Invoice>>());
      final fetched = await repo.getCompleteInvoice(saved.id!);
      expect(fetched?.status, InvoiceStatus.sent.name);
    });

    test('delete removes the row', () async {
      final saved =
          (await repo.create(draft('INV-004')) as Ok<Invoice>).value;
      final result = await repo.delete(saved.id!);
      expect(result, isA<Ok<void>>());
      expect(await repo.getCompleteInvoice(saved.id!), isNull);
    });

    test('updateStatus changes only the status', () async {
      final saved =
          (await repo.create(draft('INV-005')) as Ok<Invoice>).value;
      final result = await repo.updateStatus(saved.id!, InvoiceStatus.paid);
      expect(result, isA<Ok<void>>());
      expect(
        (await repo.getCompleteInvoice(saved.id!))?.status,
        InvoiceStatus.paid.name,
      );
    });
  });

  group('InvoiceRepository reactive watch', () {
    test('emits immediately, then re-emits on put and on remove', () async {
      final emissions = <int>[];
      final sub = repo
          .watchInvoices(const InvoiceQuery())
          .listen((list) => emissions.add(list.length));

      // initial empty emission
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, 0);

      final saved =
          (await repo.create(draft('INV-100')) as Ok<Invoice>).value;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, 1, reason: 'put should trigger a re-emit');

      await repo.delete(saved.id!);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emissions.last, 0, reason: 'remove should trigger a re-emit');

      await sub.cancel();
    });

    test('filters by status in-query', () async {
      await repo.create(draft('INV-200', status: InvoiceStatus.draft));
      await repo.create(draft('INV-201', status: InvoiceStatus.paid));

      final paid = await repo
          .watchInvoices(const InvoiceQuery(status: InvoiceStatus.paid))
          .first;
      expect(paid, hasLength(1));
      expect(paid.single.invoiceNumber, 'INV-201');
    });

    test('searches invoice number / reference / notes', () async {
      await repo.create(draft('ACME-1'));
      await repo.create(draft('OTHER-1'));

      final hits = await repo
          .watchInvoices(const InvoiceQuery(search: 'ACME'))
          .first;
      expect(hits, hasLength(1));
      expect(hits.single.invoiceNumber, 'ACME-1');
    });
  });
}
