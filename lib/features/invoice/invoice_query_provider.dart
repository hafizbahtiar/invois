import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'invoice_model.dart';

/// The active filter/search applied to the reactive invoice list.
///
/// Changing this re-triggers [invoiceListProvider] (which watches it), which in
/// turn rebuilds the underlying ObjectBox query. There is no manual refresh.
class InvoiceQuery {
  final String? search;
  final InvoiceStatus? status;
  final PaymentStatus? paymentStatus;

  const InvoiceQuery({this.search, this.status, this.paymentStatus});

  InvoiceQuery copyWith({
    String? search,
    InvoiceStatus? status,
    PaymentStatus? paymentStatus,
  }) {
    return InvoiceQuery(
      search: search ?? this.search,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceQuery &&
          other.search == search &&
          other.status == status &&
          other.paymentStatus == paymentStatus;

  @override
  int get hashCode => Object.hash(search, status, paymentStatus);
}

class InvoiceQueryNotifier extends Notifier<InvoiceQuery> {
  @override
  InvoiceQuery build() => const InvoiceQuery();

  /// Set/clear the free-text search term (empty string clears it).
  void setSearch(String? term) {
    final cleaned = (term == null || term.trim().isEmpty) ? null : term.trim();
    state = InvoiceQuery(
      search: cleaned,
      status: state.status,
      paymentStatus: state.paymentStatus,
    );
  }

  /// Replace the active status filter (single active filter, matching the UI).
  void setStatus(InvoiceStatus? status) {
    state = InvoiceQuery(search: state.search, status: status);
  }

  /// Replace the active payment-status filter.
  void setPaymentStatus(PaymentStatus? paymentStatus) {
    state = InvoiceQuery(search: state.search, paymentStatus: paymentStatus);
  }

  void reset() => state = const InvoiceQuery();
}

final invoiceQueryProvider =
    NotifierProvider<InvoiceQueryNotifier, InvoiceQuery>(
      InvoiceQueryNotifier.new,
    );
