import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/tax/tax.dart';
import 'package:invois/features/term/term.dart';

import 'invoice_line_model.dart';

import 'invoice_local_source.dart';
import 'invoice_model.dart';
import 'invoice_numbering.dart';
import 'invoice_query.dart';

/// DI: one local source bound to the app-wide [storeProvider].
final invoiceLocalSourceProvider = Provider<InvoiceLocalSource>(
  (ref) => InvoiceLocalSource.withDependencies(store: ref.watch(storeProvider)),
);

/// DI: the single invoice repository (ADR-0002 — one per aggregate).
final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(ref.watch(invoiceLocalSourceProvider)),
);

/// The single invoice repository. Replaces the former `InvoiceListRepository`
/// and `InvoiceFormRepository`.
///
/// Boundary contract:
/// - Reactive reads return a [Stream] that throws [AppFailure] on error
///   (surfaced as `AsyncError` by `StreamProvider`).
/// - `create`/`update`/`markAs*`/`delete` return [Result].
/// - Relation helpers (taxes/terms/lines) are fire-and-forget mutations.
class InvoiceRepository {
  final InvoiceLocalSource _local;

  InvoiceRepository(this._local);

  // ============================================================
  // Reactive reads (ADR-0003)
  // ============================================================

  Stream<List<Invoice>> watchInvoices(InvoiceQuery query) => _local
      .watchInvoices(query)
      .handleError((Object e) => throw mapException(e));

  /// Loads an invoice and eagerly triggers its relations.
  Future<Invoice?> getCompleteInvoice(int id) async {
    final invoice = await _local.getInvoiceById(id);
    if (invoice != null) {
      invoice.lines.toList();
      invoice.taxes.toList();
      invoice.terms.toList();
    }
    return invoice;
  }

  Future<Result<String>> nextInvoiceNumber(
    int businessId, {
    String prefix = '',
  }) async {
    try {
      return Ok(await _local.nextInvoiceNumber(businessId, prefix: prefix));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<bool>> isInvoiceNumberAvailable({
    required int businessId,
    required String invoiceNumber,
    int? excludingInvoiceId,
  }) async {
    try {
      return Ok(
        await _local.isInvoiceNumberAvailable(
          businessId: businessId,
          invoiceNumber: invoiceNumber,
          excludingInvoiceId: excludingInvoiceId,
        ),
      );
    } catch (e) {
      return Err(mapException(e));
    }
  }

  // ============================================================
  // Imperative — Result (S1)
  // ============================================================

  Future<Result<void>> delete(int id) async {
    try {
      await _local.deleteInvoiceById(id);
      return const Ok(null);
    } catch (e) {
      return Err(mapException(e));
    }
  }

  // ============================================================
  // Write/compose — Result
  // ============================================================

  Future<Result<Invoice>> create(Invoice invoice) async {
    try {
      final validation = await _validateInvoiceNumber(invoice);
      if (validation != null) return Err(validation);

      final now = DateTime.now();
      final r = await _local.insertInvoice(
        _withDualWrittenMoney(invoice).copyWith(createdAt: now, updatedAt: now),
      );
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to insert invoice'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<Invoice>> update(Invoice invoice) async {
    try {
      final validation = await _validateInvoiceNumber(invoice);
      if (validation != null) return Err(validation);

      final r = await _local.updateInvoice(
        _withDualWrittenMoney(invoice).copyWith(updatedAt: DateTime.now()),
      );
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update invoice'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  /// Mark the invoice as sent (status + sentDate). Does not touch payment fields.
  Future<Result<void>> markAsSent(int id) async {
    try {
      final ok = await _local.markAsSent(id);
      return ok
          ? const Ok(null)
          : const Err(DatabaseFailure('Failed to mark invoice as sent'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  /// Mark the invoice as paid. Full payment by default; pass [paidAmount] for a
  /// partial payment. Reconciles paid/balance/paymentStatus together.
  Future<Result<void>> markAsPaid(int id, {double? paidAmount}) async {
    try {
      final ok = await _local.markAsPaid(id, paidAmount: paidAmount);
      return ok
          ? const Ok(null)
          : const Err(DatabaseFailure('Failed to mark invoice as paid'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  /// Move the invoice to a non-paid [status], reconciling the payment fields
  /// back to unpaid so status and payment can never diverge.
  Future<Result<void>> markAsUnpaid(
    int id, {
    required InvoiceStatus status,
  }) async {
    try {
      final ok = await _local.markAsUnpaid(id, status: status);
      return ok
          ? const Ok(null)
          : const Err(DatabaseFailure('Failed to update invoice status'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  // ---- Invoice lines ----
  /// Replace the invoice's [InvoiceLine] snapshots.
  Future<void> replaceInvoiceLines(int invoiceId, List<InvoiceLine> lines) =>
      _local.replaceInvoiceLines(invoiceId, lines);

  // ---- Taxes ----
  Future<void> addTaxToInvoice(int invoiceId, Tax tax) =>
      _local.addTaxToInvoice(invoiceId, tax);
  Future<void> clearTaxesFromInvoice(int invoiceId) =>
      _local.clearTaxesFromInvoice(invoiceId);

  // ---- Terms ----
  Future<void> addTermToInvoice(int invoiceId, Term term) =>
      _local.addTermToInvoice(invoiceId, term);
  Future<void> clearTermsFromInvoice(int invoiceId) =>
      _local.clearTermsFromInvoice(invoiceId);

  Invoice _withDualWrittenMoney(Invoice invoice) {
    return invoice.copyWith(
      subtotal: invoice.effectiveSubtotalCents / 100,
      discountAmount: invoice.effectiveDiscountAmountCents / 100,
      taxAmount: invoice.effectiveTaxAmountCents / 100,
      total: invoice.effectiveTotalCents / 100,
      paidAmount: invoice.effectivePaidAmountCents / 100,
      balanceDue: invoice.effectiveBalanceDueCents / 100,
      subtotalCents: invoice.effectiveSubtotalCents,
      discountAmountCents: invoice.effectiveDiscountAmountCents,
      taxAmountCents: invoice.effectiveTaxAmountCents,
      totalCents: invoice.effectiveTotalCents,
      paidAmountCents: invoice.effectivePaidAmountCents,
      balanceDueCents: invoice.effectiveBalanceDueCents,
    );
  }

  Future<AppFailure?> _validateInvoiceNumber(Invoice invoice) async {
    final businessId = invoice.businessId;
    if (businessId == null || businessId <= 0) return null;

    final number = InvoiceNumbering.fullNumber(invoice);
    if (number.trim().isEmpty) {
      return const ValidationFailure('Invoice number is required.');
    }

    final isAvailable = await _local.isInvoiceNumberAvailable(
      businessId: businessId,
      invoiceNumber: number,
      excludingInvoiceId: invoice.id,
    );

    return isAvailable
        ? null
        : const ValidationFailure(
            'Invoice number already exists for this business.',
          );
  }
}
