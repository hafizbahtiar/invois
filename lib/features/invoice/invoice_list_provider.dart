import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'invoice_model.dart';
import 'invoice_query_provider.dart';
import 'invoice_repository.dart';

/// Reactive invoice list (ADR-0003).
///
/// Backed by an ObjectBox `query.watch()` stream, so it re-emits automatically
/// on any matching write — no manual refresh. It rebuilds whenever the active
/// [invoiceQueryProvider] (search/status filter) changes.
///
/// Consumers read this as an `AsyncValue<List<Invoice>>`
/// (`.valueOrNull`, `.isLoading`, `.hasError`).
final invoiceListProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  final repo = ref.watch(invoiceRepositoryProvider);
  final query = ref.watch(invoiceQueryProvider);
  return repo.watchInvoices(query);
});
