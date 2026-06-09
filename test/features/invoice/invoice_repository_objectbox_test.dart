@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_query.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/signature/data/signature_local_source.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_repository.dart';

/// Repository / local-source integration tests against a real (in-memory)
/// ObjectBox store. Tagged `objectbox` because they require the native
/// `libobjectbox` library on the host — see doc/testing.md. Excluded from the
/// default `flutter test` run; run with `flutter test --tags objectbox`.
void main() {
  late Store store;
  late InvoiceRepository repo;
  late SignatureRepository signatureRepo;

  Invoice draft(
    String number, {
    InvoiceStatus status = InvoiceStatus.draft,
    int? businessId,
  }) {
    return Invoice(
      invoiceNumber: number,
      status: status.name,
      businessId: businessId,
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
    signatureRepo = SignatureRepository(
      SignatureLocalSource.withDependencies(store: store),
    );
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
      final saved = (await repo.create(draft('INV-002')) as Ok<Invoice>).value;
      final fetched = await repo.getCompleteInvoice(saved.id!);
      expect(fetched?.totalCents, 10000);
      expect(fetched?.total, 100.0); // dual-written from cents
    });

    test('update mutates the stored row', () async {
      final saved = (await repo.create(draft('INV-003')) as Ok<Invoice>).value;
      final updated = await repo.update(
        saved.copyWith(status: InvoiceStatus.sent.name),
      );
      expect(updated, isA<Ok<Invoice>>());
      final fetched = await repo.getCompleteInvoice(saved.id!);
      expect(fetched?.status, InvoiceStatus.sent.name);
    });

    test('delete removes the row', () async {
      final saved = (await repo.create(draft('INV-004')) as Ok<Invoice>).value;
      final result = await repo.delete(saved.id!);
      expect(result, isA<Ok<void>>());
      expect(await repo.getCompleteInvoice(saved.id!), isNull);
    });

    test('updateStatus changes only the status', () async {
      final saved = (await repo.create(draft('INV-005')) as Ok<Invoice>).value;
      final result = await repo.updateStatus(saved.id!, InvoiceStatus.paid);
      expect(result, isA<Ok<void>>());
      expect(
        (await repo.getCompleteInvoice(saved.id!))?.status,
        InvoiceStatus.paid.name,
      );
    });

    test('create persists nullable signatureId when selected', () async {
      final signature =
          (await signatureRepo.create(Signature(name: 'Owner'))
                  as Ok<Signature>)
              .value;
      final saved =
          (await repo.create(
                    draft('INV-SIG').copyWith(signatureId: signature.id),
                  )
                  as Ok<Invoice>)
              .value;

      final fetched = await repo.getCompleteInvoice(saved.id!);

      expect(fetched?.signatureId, signature.id);
    });

    test('create supports invoices without a signatureId', () async {
      final saved =
          (await repo.create(draft('INV-NO-SIG')) as Ok<Invoice>).value;

      final fetched = await repo.getCompleteInvoice(saved.id!);

      expect(fetched?.signatureId, isNull);
    });
  });

  group('InvoiceRepository numbering', () {
    test('nextInvoiceNumber starts empty business at INV-0001', () async {
      final result = await repo.nextInvoiceNumber(1);

      expect(result.valueOrNull, 'INV-0001');
    });

    test('nextInvoiceNumber increments matching business sequence', () async {
      await repo.create(draft('INV-0001', businessId: 1));
      await repo.create(draft('INV-0002', businessId: 1));

      final result = await repo.nextInvoiceNumber(1);

      expect(result.valueOrNull, 'INV-0003');
    });

    test('nextInvoiceNumber ignores manual non-matching numbers', () async {
      await repo.create(draft('CUSTOM-9', businessId: 1));
      await repo.create(draft('INV-0002', businessId: 1));

      final result = await repo.nextInvoiceNumber(1);

      expect(result.valueOrNull, 'INV-0003');
    });

    test('duplicate number for same business is rejected', () async {
      await repo.create(draft('INV-0001', businessId: 1));

      final result = await repo.create(draft('INV-0001', businessId: 1));

      expect(result, isA<Err<Invoice>>());
    });

    test('same number in different businesses is allowed', () async {
      await repo.create(draft('INV-0001', businessId: 1));

      final result = await repo.create(draft('INV-0001', businessId: 2));

      expect(result, isA<Ok<Invoice>>());
    });

    test('edit invoice can keep its same number', () async {
      final saved =
          (await repo.create(draft('INV-0001', businessId: 1)) as Ok<Invoice>)
              .value;

      final result = await repo.update(saved.copyWith(reference: 'Updated'));

      expect(result, isA<Ok<Invoice>>());
    });
  });

  group('SignatureRepository defaults', () {
    test('loads active default signature scoped by business', () async {
      await signatureRepo.create(
        Signature(
          name: 'Inactive Default',
          businessId: 1,
          isDefault: true,
          isActive: false,
        ),
      );
      final activeDefault =
          (await signatureRepo.create(
                    Signature(
                      name: 'Active Default',
                      businessId: 1,
                      isDefault: true,
                    ),
                  )
                  as Ok<Signature>)
              .value;

      final result = await signatureRepo.getDefaultActiveSignatureByBusinessId(
        1,
      );

      expect(result?.id, activeDefault.id);
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

      final saved = (await repo.create(draft('INV-100')) as Ok<Invoice>).value;
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
