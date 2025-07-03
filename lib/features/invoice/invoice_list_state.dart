import 'invoice_model.dart';

class InvoiceListState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;

  InvoiceListState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
  });

  InvoiceListState copyWith({
    List<Invoice>? invoices,
    bool? isLoading,
    String? error,
  }) {
    return InvoiceListState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
