import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/tax/tax_module.dart';
import 'package:invois/features/term/term_module.dart';

import 'invoice_local_source.dart';
import 'invoice_model.dart';
import 'invoice_query_provider.dart';

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
/// - `create`/`update`/`updateStatus`/`delete` return [Result].
/// - Relation helpers (items/taxes/terms) are fire-and-forget mutations.
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
      invoice.items.toList();
      invoice.taxes.toList();
      invoice.terms.toList();
    }
    return invoice;
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
      final now = DateTime.now();
      final r = await _local.insertInvoice(
        invoice.copyWith(createdAt: now, updatedAt: now),
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
      final r = await _local.updateInvoice(
        invoice.copyWith(updatedAt: DateTime.now()),
      );
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update invoice'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<void>> updateStatus(int id, InvoiceStatus status) async {
    try {
      final ok = await _local.updateInvoiceStatus(id, status);
      return ok
          ? const Ok(null)
          : const Err(DatabaseFailure('Failed to update invoice status'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  // ---- Items ----
  Future<void> addItemToInvoice(int invoiceId, Item item) =>
      _local.addItemToInvoice(invoiceId, item);
  Future<void> clearItemsFromInvoice(int invoiceId) =>
      _local.clearItemsFromInvoice(invoiceId);

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
}
