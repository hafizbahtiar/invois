import 'package:invois/core/database/objectbox_response.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/tax/tax_module.dart';
import 'package:invois/features/term/term_module.dart';

import 'invoice_local_source.dart';
import 'invoice_model.dart';

class InvoiceFormRepository {
  final InvoiceLocalSource _localSource;

  // Singleton pattern
  static final InvoiceFormRepository _instance =
      InvoiceFormRepository._internal();
  factory InvoiceFormRepository() => _instance;

  InvoiceFormRepository._internal() : _localSource = InvoiceLocalSource();

  // Constructor for dependency injection (useful for testing)
  InvoiceFormRepository.withDependencies({
    required InvoiceLocalSource localService,
  }) : _localSource = localService;

  Future<List<Invoice>> getInvoices() async {
    return await _localSource.getInvoices();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    return await _localSource.getInvoiceById(id);
  }

  Future<ObjectBoxResponse<Invoice>> insertInvoice(Invoice invoice) async {
    // Set creation timestamp
    final invoiceWithTimestamp = invoice.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _localSource.insertInvoice(invoiceWithTimestamp);
  }

  Future<ObjectBoxResponse<Invoice>> updateInvoice(Invoice invoice) async {
    // Set update timestamp
    final invoiceWithTimestamp = invoice.copyWith(updatedAt: DateTime.now());
    return await _localSource.updateInvoice(invoiceWithTimestamp);
  }

  Future<ObjectBoxResponse<bool>> deleteInvoice(int id) async {
    // Remove the invoice (related relations are handled in the local source).
    final result = await _localSource.deleteInvoiceById(id);
    if (result) {
      return ObjectBoxResponse.success(true);
    } else {
      return ObjectBoxResponse.failure(message: 'Failed to delete invoice');
    }
  }

  Future<int> deleteInvoices(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      final result = await deleteInvoice(id);
      if (result.success) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<List<Invoice>> searchInvoicesByNumber(String query) async {
    return await _localSource.searchInvoicesByNumber(query);
  }

  Future<int> countInvoices() async {
    return await _localSource.countInvoices();
  }

  Future<ObjectBoxResponse<bool>> updateInvoiceStatus(
    int id,
    InvoiceStatus status,
  ) async {
    final result = await _localSource.updateInvoiceStatus(id, status);
    if (result) {
      return ObjectBoxResponse.success(true);
    } else {
      return ObjectBoxResponse.failure(
        message: 'Failed to update invoice status',
      );
    }
  }

  Future<bool> updateInvoiceFields(
    int id, {
    String? invoiceNumber,
    String? invoiceNumberPrefix,
    String? reference,
    InvoiceType? invoiceType,
    InvoiceStatus? status,
    PaymentStatus? paymentStatus,
    String? notes,
    DateTime? issueDate,
    DateTime? dueDate,
    DateTime? sentDate,
    DateTime? viewedDate,
    DateTime? paidDate,
    int? businessId,
    int? clientId,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    double? taxAmount,
    double? total,
    double? paidAmount,
    double? balanceDue,
    String? currency,
    bool? isRecurring,
    String? recurringFrequency,
    int? recurringInterval,
    DateTime? recurringEndDate,
    DateTime? updatedAt,
  }) async {
    return await _localSource.updateInvoiceFields(
      id,
      invoiceNumber: invoiceNumber,
      invoiceNumberPrefix: invoiceNumberPrefix,
      reference: reference,
      invoiceType: invoiceType?.name,
      status: status?.name,
      paymentStatus: paymentStatus?.name,
      notes: notes,
      issueDate: issueDate,
      dueDate: dueDate,
      sentDate: sentDate,
      viewedDate: viewedDate,
      paidDate: paidDate,
      businessId: businessId,
      clientId: clientId,
      subtotal: subtotal,
      discountRate: discountRate,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      paidAmount: paidAmount,
      balanceDue: balanceDue,
      currency: currency,
      isRecurring: isRecurring,
      recurringFrequency: recurringFrequency,
      recurringInterval: recurringInterval,
      recurringEndDate: recurringEndDate,
      updatedAt: updatedAt,
    );
  }

  // ================================
  //    MARK: Address
  // ================================

  /// Add an item to an invoice
  Future<void> addItemToInvoice(int invoiceId, Item item) async {
    await _localSource.addItemToInvoice(invoiceId, item);
  }

  /// Remove an item from an invoice
  Future<void> removeItemFromInvoice(int invoiceId, Item item) async {
    await _localSource.removeItemFromInvoice(invoiceId, item);
  }

  /// Get all items for an invoice
  Future<List<Item>> getInvoiceItems(int invoiceId) async {
    return await _localSource.getInvoiceItems(invoiceId);
  }

  /// Clear all items from an invoice
  Future<void> clearItemsFromInvoice(int invoiceId) async {
    await _localSource.clearItemsFromInvoice(invoiceId);
  }

  // ================================
  //    MARK: Tax
  // ================================

  /// Add a tax to an invoice
  Future<void> addTaxToInvoice(int invoiceId, Tax tax) async {
    await _localSource.addTaxToInvoice(invoiceId, tax);
  }

  /// Remove a tax from an invoice
  Future<void> removeTaxFromInvoice(int invoiceId, Tax tax) async {
    await _localSource.removeTaxFromInvoice(invoiceId, tax);
  }

  /// Clear all taxes from an invoice
  Future<void> clearTaxesFromInvoice(int invoiceId) async {
    await _localSource.clearTaxesFromInvoice(invoiceId);
  }

  // ================================
  //    MARK: Term
  // ================================

  /// Add a term to an invoice
  Future<void> addTermToInvoice(int invoiceId, Term term) async {
    await _localSource.addTermToInvoice(invoiceId, term);
  }

  /// Remove a term from an invoice
  Future<void> removeTermFromInvoice(int invoiceId, Term term) async {
    await _localSource.removeTermFromInvoice(invoiceId, term);
  }

  /// Clear all terms from an invoice
  Future<void> clearTermsFromInvoice(int invoiceId) async {
    await _localSource.clearTermsFromInvoice(invoiceId);
  }

  /// Create a business with addresses in a single operation
  Future<ObjectBoxResponse<Invoice>> createCompleteInvoice(
    Invoice invoice,
  ) async {
    try {
      return await insertInvoice(invoice);
    } catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  /// Update a business and its addresses
  Future<ObjectBoxResponse<Invoice>> updateCompleteInvoice(
    Invoice invoice,
  ) async {
    try {
      return await updateInvoice(invoice);
    } catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  /// Get invoice with all its items
  Future<Invoice?> getInvoiceWithItems(int invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null) {
      // Access items to trigger ObjectBox loading
      invoice.items.toList();
    }
    return invoice;
  }

  /// Get invoice with all its taxes
  Future<Invoice?> getInvoiceWithTaxes(int invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null) {
      // Access taxes to trigger ObjectBox loading
      invoice.taxes.toList();
    }
    return invoice;
  }

  /// Get invoice with all its terms
  Future<Invoice?> getInvoiceWithTerms(int invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null) {
      // Access terms to trigger ObjectBox loading
      invoice.terms.toList();
    }
    return invoice;
  }

  /// Get invoice with all its items, taxes, and terms
  Future<Invoice?> getCompleteInvoice(int invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null) {
      // Access items, taxes, and terms to trigger ObjectBox loading
      invoice.items.toList();
      invoice.taxes.toList();
      invoice.terms.toList();
    }
    return invoice;
  }
}
