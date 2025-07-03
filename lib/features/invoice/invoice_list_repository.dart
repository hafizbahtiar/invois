import 'package:invois/core/database/objectbox_response.dart';

import 'invoice_local_source.dart';
import 'invoice_model.dart';

class InvoiceListRepository {
  final InvoiceLocalSource _localSource;

  // Singleton pattern
  static final InvoiceListRepository _instance =
      InvoiceListRepository._internal();
  factory InvoiceListRepository() => _instance;

  InvoiceListRepository._internal() : _localSource = InvoiceLocalSource();

  // Constructor for dependency injection (useful for testing)
  InvoiceListRepository.withDependencies({
    required InvoiceLocalSource localService,
  }) : _localSource = localService;

  Future<ObjectBoxResponse<List<Invoice>>> getInvoices() async {
    try {
      final result = await _localSource.getInvoices();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Invoice>>> searchInvoices(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    try {
      final result = await _localSource.searchInvoices(query);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Invoice>>> getInvoicesByPaymentStatus(
    PaymentStatus paymentStatus,
  ) async {
    try {
      final result = await _localSource.getInvoicesByPaymentStatus(
        paymentStatus,
      );
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Invoice>>> getInvoicesByStatus(
    InvoiceStatus status,
  ) async {
    try {
      final result = await _localSource.getInvoicesByStatus(status);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<int> countInvoices() async {
    return await _localSource.countInvoices();
  }
}
