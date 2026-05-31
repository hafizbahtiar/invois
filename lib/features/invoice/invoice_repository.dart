import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/database/objectbox_response.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
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
/// - `delete` returns [Result] (S1 Result adoption).
/// - Write/compose methods still return `ObjectBoxResponse` — TRANSITIONAL for
///   S1; they converge on [Result] in S2 with the form `AsyncNotifier`.
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
  // Write/compose — TRANSITIONAL ObjectBoxResponse (migrates to Result in S2)
  // ============================================================

  Future<ObjectBoxResponse<Invoice>> createCompleteInvoice(Invoice invoice) {
    final now = DateTime.now();
    return _local.insertInvoice(
      invoice.copyWith(createdAt: now, updatedAt: now),
    );
  }

  Future<ObjectBoxResponse<Invoice>> updateCompleteInvoice(Invoice invoice) {
    return _local.updateInvoice(invoice.copyWith(updatedAt: DateTime.now()));
  }

  Future<ObjectBoxResponse<bool>> updateInvoiceStatus(
    int id,
    InvoiceStatus status,
  ) async {
    final ok = await _local.updateInvoiceStatus(id, status);
    return ok
        ? ObjectBoxResponse.success(true)
        : ObjectBoxResponse.failure(message: 'Failed to update invoice status');
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
