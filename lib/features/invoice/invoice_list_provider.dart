import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invoice_list_repository.dart';
import 'invoice_list_state.dart';
import 'invoice_model.dart';

class InvoiceListNotifier extends StateNotifier<InvoiceListState> {
  final InvoiceListRepository _repository;

  InvoiceListNotifier(this._repository) : super(InvoiceListState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    await getInvoices();
    state = state.copyWith(isLoading: false);
  }

  Future<void> filter({String? query}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (query != null) {
      await searchInvoices(query);
    } else {
      await getInvoices();
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> getInvoices() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInvoices();
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(invoices: result.data ?? []);
    }
  }

  Future<void> searchInvoices(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchInvoices(query);
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(invoices: result.data ?? []);
    }
  }

  Future<void> getInvoicesByPaymentStatus(PaymentStatus paymentStatus) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInvoicesByPaymentStatus(paymentStatus);
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(invoices: result.data ?? []);
    }
  }

  Future<void> getInvoicesByStatus(InvoiceStatus status) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInvoicesByStatus(status);
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(invoices: result.data ?? []);
    }
  }
}

// Provider for InvoiceListNotifier
final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, InvoiceListState>(
      (ref) => InvoiceListNotifier(InvoiceListRepository()),
    );
