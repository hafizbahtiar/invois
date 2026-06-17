@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_query.dart';
import 'package:invois/features/invoice/data/invoice_repository.dart';
import 'package:invois/features/signature/data/signature_local_source.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_repository.dart';
import 'package:invois/features/tax/data/tax_model.dart';
import 'package:invois/features/term/data/term_model.dart';

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

    test(
      'delete removes the invoice\'s InvoiceLine rows (no orphans)',
      () async {
        final saved =
            (await repo.create(draft('INV-005')) as Ok<Invoice>).value;
        await repo.replaceInvoiceLines(saved.id!, [
          InvoiceLine(name: 'A', unitPriceCents: 5000, quantityMilli: 1000),
          InvoiceLine(name: 'B', unitPriceCents: 5000, quantityMilli: 2000),
        ]);
        final lineBox = store.box<InvoiceLine>();
        expect(lineBox.count(), 2);

        final result = await repo.delete(saved.id!);
        expect(result, isA<Ok<void>>());
        expect(await repo.getCompleteInvoice(saved.id!), isNull);
        expect(
          lineBox.count(),
          0,
          reason: 'owned lines must die with the invoice',
        );
      },
    );

    test('delete only removes the deleted invoice\'s lines', () async {
      final keep = (await repo.create(draft('INV-KEEP')) as Ok<Invoice>).value;
      final gone = (await repo.create(draft('INV-GONE')) as Ok<Invoice>).value;
      await repo.replaceInvoiceLines(keep.id!, [
        InvoiceLine(name: 'Keep', unitPriceCents: 1000, quantityMilli: 1000),
      ]);
      await repo.replaceInvoiceLines(gone.id!, [
        InvoiceLine(name: 'Gone', unitPriceCents: 2000, quantityMilli: 1000),
      ]);

      await repo.delete(gone.id!);

      final lines = store.box<InvoiceLine>().getAll();
      expect(lines, hasLength(1));
      expect(lines.single.name, 'Keep');
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

  group('InvoiceRepository aggregate save', () {
    test(
      'upsertAggregate writes header, lines, taxes, and terms together',
      () async {
        final tax = Tax(name: 'SST', rate: 6);
        store.box<Tax>().put(tax);
        final term = Term(name: 'Net 30', content: 'Payment due in 30 days');
        store.box<Term>().put(term);

        final created = await repo.upsertAggregate(
          invoice: draft('INV-AGG'),
          lines: [
            InvoiceLine(
              name: 'Design',
              unitPriceCents: 12500,
              quantityMilli: 1500,
            ),
          ],
          taxes: [tax],
          terms: [term],
        );

        expect(created, isA<Ok<Invoice>>());
        final saved = (created as Ok<Invoice>).value;
        final fetched = (await repo.getCompleteInvoice(saved.id!))!;
        expect(fetched.lines.length, 1);
        expect(fetched.lines.single.quantityMilli, 1500);
        expect(fetched.taxes.length, 1);
        expect(fetched.terms.length, 1);

        final updated = await repo.upsertAggregate(
          invoice: fetched.copyWith(reference: 'cleared'),
          lines: [
            InvoiceLine(
              name: 'Build',
              unitPriceCents: 20000,
              quantityMilli: 1000,
            ),
          ],
          taxes: const [],
          terms: const [],
        );

        expect(updated, isA<Ok<Invoice>>());
        final refetched = (await repo.getCompleteInvoice(saved.id!))!;
        expect(refetched.reference, 'cleared');
        expect(refetched.lines.length, 1);
        expect(refetched.lines.single.name, 'Build');
        expect(store.box<InvoiceLine>().count(), 1);
        expect(refetched.taxes, isEmpty);
        expect(refetched.terms, isEmpty);
      },
    );
  });

  group('InvoiceRepository payment lifecycle (P1-002)', () {
    test('markAsSent sets status=sent and a sentDate', () async {
      final saved = (await repo.create(draft('INV-SENT')) as Ok<Invoice>).value;

      final result = await repo.markAsSent(saved.id!);
      expect(result, isA<Ok<void>>());

      final fetched = await repo.getCompleteInvoice(saved.id!);
      expect(fetched?.status, InvoiceStatus.sent.name);
      expect(fetched?.sentDate, isNotNull);
      // Payment state must be untouched by "mark as sent".
      expect(fetched?.effectivePaidAmountCents, 0);
    });

    test(
      'markAsPaid reconciles paid/balance/paymentStatus and status',
      () async {
        // total = 10000 cents from the draft() helper.
        final saved =
            (await repo.create(draft('INV-PAID')) as Ok<Invoice>).value;

        final result = await repo.markAsPaid(saved.id!);
        expect(result, isA<Ok<void>>());

        final fetched = (await repo.getCompleteInvoice(saved.id!))!;
        expect(fetched.status, InvoiceStatus.paid.name);
        expect(fetched.paymentStatus, PaymentStatus.paid.name);
        expect(fetched.effectivePaidAmountCents, 10000);
        expect(fetched.effectiveBalanceDueCents, 0);
        expect(fetched.isFullyPaid, isTrue);
        // Legacy double dual-write stays consistent with the cents spine.
        expect(fetched.paidAmount, 100.0);
        expect(fetched.balanceDue, 0.0);
        expect(fetched.paidDate, isNotNull);
      },
    );

    test('markAsPaid with a partial amount -> partiallyPaid', () async {
      final saved =
          (await repo.create(draft('INV-PARTIAL')) as Ok<Invoice>).value;

      await repo.markAsPaid(saved.id!, paidAmount: 40); // RM40 of RM100

      final fetched = (await repo.getCompleteInvoice(saved.id!))!;
      expect(fetched.paymentStatus, PaymentStatus.partiallyPaid.name);
      expect(fetched.effectivePaidAmountCents, 4000);
      expect(fetched.effectiveBalanceDueCents, 6000);
      expect(fetched.isFullyPaid, isFalse);
    });

    test(
      'markAsPaid preserves invoice lines (no relation loss on update)',
      () async {
        final saved =
            (await repo.create(draft('INV-LINES')) as Ok<Invoice>).value;
        await repo.replaceInvoiceLines(saved.id!, [
          InvoiceLine(
            name: 'Widget',
            unitPriceCents: 10000,
            quantityMilli: 1000,
          ),
        ]);

        await repo.markAsPaid(saved.id!);

        final fetched = (await repo.getCompleteInvoice(saved.id!))!;
        expect(fetched.lines.length, 1);
        expect(fetched.lines.first.name, 'Widget');
        expect(fetched.status, InvoiceStatus.paid.name);
      },
    );

    test(
      'paid -> sent reconciles payment fields back to unpaid (Step 2B)',
      () async {
        final saved =
            (await repo.create(draft('INV-REV1')) as Ok<Invoice>).value;
        await repo.markAsPaid(saved.id!); // now fully paid

        final result = await repo.markAsSent(saved.id!);
        expect(result, isA<Ok<void>>());

        final fetched = (await repo.getCompleteInvoice(saved.id!))!;
        expect(fetched.status, InvoiceStatus.sent.name);
        expect(fetched.paymentStatus, PaymentStatus.unpaid.name);
        expect(fetched.effectivePaidAmountCents, 0);
        expect(fetched.effectiveBalanceDueCents, 10000);
        expect(fetched.isFullyPaid, isFalse);
      },
    );

    test(
      'paid -> draft (markAsUnpaid) does not keep paid payment data (Step 2B)',
      () async {
        final saved =
            (await repo.create(draft('INV-REV2')) as Ok<Invoice>).value;
        await repo.markAsPaid(saved.id!);

        final result = await repo.markAsUnpaid(
          saved.id!,
          status: InvoiceStatus.draft,
        );
        expect(result, isA<Ok<void>>());

        final fetched = (await repo.getCompleteInvoice(saved.id!))!;
        expect(fetched.status, InvoiceStatus.draft.name);
        expect(fetched.paymentStatus, PaymentStatus.unpaid.name);
        expect(fetched.effectivePaidAmountCents, 0);
        expect(fetched.effectiveBalanceDueCents, 10000);
      },
    );

    test('markAsUnpaid preserves invoice lines (Step 2B)', () async {
      final saved = (await repo.create(draft('INV-REV3')) as Ok<Invoice>).value;
      await repo.replaceInvoiceLines(saved.id!, [
        InvoiceLine(
          name: 'Service',
          unitPriceCents: 10000,
          quantityMilli: 1000,
        ),
      ]);
      await repo.markAsPaid(saved.id!);

      await repo.markAsUnpaid(saved.id!, status: InvoiceStatus.draft);

      final fetched = (await repo.getCompleteInvoice(saved.id!))!;
      expect(fetched.lines.length, 1);
      expect(fetched.lines.first.name, 'Service');
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

    test('prefix scopes count independently within a business', () async {
      await repo.create(draft('INV-0001', businessId: 1));
      await repo.create(draft('INV-0002', businessId: 1));
      await repo.create(draft('QUO-0005', businessId: 1));

      // Non-empty prefix returns the sequence part only (the form composes
      // fullNumber = prefix + number).
      expect(
        (await repo.nextInvoiceNumber(1, prefix: 'INV-')).valueOrNull,
        '0003',
      );
      expect(
        (await repo.nextInvoiceNumber(1, prefix: 'QUO-')).valueOrNull,
        '0006',
      );
      expect(
        (await repo.nextInvoiceNumber(1, prefix: 'EST-')).valueOrNull,
        '0001',
      );
    });

    test('prefix scopes are independent across businesses', () async {
      await repo.create(draft('QUO-0009', businessId: 1));

      expect(
        (await repo.nextInvoiceNumber(2, prefix: 'QUO-')).valueOrNull,
        '0001',
      );
      expect(
        (await repo.nextInvoiceNumber(1, prefix: 'QUO-')).valueOrNull,
        '0010',
      );
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
