import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';
import 'package:invois/features/invoice/invoice_payment.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/tax/data/tax_model.dart';
import 'package:invois/features/term/data/term_model.dart';

import 'invoice_model.dart';
import 'invoice_numbering.dart';
import 'invoice_query.dart';

class InvoiceLocalSource {
  final Store _store;
  late final Box<Invoice> _invoiceBox;

  static final InvoiceLocalSource _instance = InvoiceLocalSource._internal();
  factory InvoiceLocalSource() => _instance;

  InvoiceLocalSource._internal() : _store = ObjectBoxDatabase.instance {
    _invoiceBox = _store.box<Invoice>();
  }

  InvoiceLocalSource.withDependencies({required Store store}) : _store = store {
    _invoiceBox = _store.box<Invoice>();
  }

  // Get all invoices
  Future<List<Invoice>> getInvoices() async {
    return _invoiceBox.getAll();
  }

  /// Reactive, filtered invoice stream (ADR-0003).
  ///
  /// Emits immediately and again on every matching write. Search runs in-query
  /// (no `getAll().where()` full scan). The query/subscription is closed by
  /// ObjectBox when the stream subscription is cancelled (autoDispose handles
  /// this at the provider level).
  Stream<List<Invoice>> watchInvoices(InvoiceQuery q) {
    Condition<Invoice>? condition;

    final search = q.search;
    if (search != null && search.isNotEmpty) {
      final searchCondition = Invoice_.invoiceNumber
          .contains(search, caseSensitive: false)
          .or(Invoice_.reference.contains(search, caseSensitive: false))
          .or(Invoice_.notes.contains(search, caseSensitive: false));
      condition = searchCondition;
    }

    if (q.status != null) {
      final c = Invoice_.status.equals(q.status!.name);
      condition = condition == null ? c : condition.and(c);
    }
    if (q.paymentStatus != null) {
      final c = Invoice_.paymentStatus.equals(q.paymentStatus!.name);
      condition = condition == null ? c : condition.and(c);
    }

    final builder = condition == null
        ? _invoiceBox.query()
        : _invoiceBox.query(condition);
    builder.order(Invoice_.createdAt, flags: Order.descending);

    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }

  // Get invoice by ID
  Future<Invoice?> getInvoiceById(int id) async {
    return _invoiceBox.get(id);
  }

  // Insert invoice
  Future<ObjectBoxResponse<Invoice>> insertInvoice(Invoice invoice) async {
    try {
      final result = _invoiceBox.put(invoice);
      if (result > 0) {
        return ObjectBoxResponse.success(invoice);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to insert invoice');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Update invoice
  Future<ObjectBoxResponse<Invoice>> updateInvoice(Invoice invoice) async {
    try {
      final result = _invoiceBox.put(invoice);
      if (result > 0) {
        return ObjectBoxResponse.success(invoice);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to update invoice');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Delete invoice
  Future<bool> deleteInvoiceById(int id) async {
    return _invoiceBox.remove(id);
  }

  // Delete multiple invoices
  Future<int> deleteInvoices(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (_invoiceBox.remove(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  // Search invoices by invoice number
  Future<List<Invoice>> searchInvoicesByNumber(String query) async {
    final allInvoices = _invoiceBox.getAll();
    return allInvoices
        .where(
          (invoice) =>
              invoice.invoiceNumber.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Search invoices (combined search)
  Future<List<Invoice>> searchInvoices(
    String query, {
    InvoiceStatus? status,
    PaymentStatus? paymentStatus,
    InvoiceType? invoiceType,
  }) async {
    final allInvoices = _invoiceBox.getAll();
    return allInvoices.where((invoice) {
      bool matchesQuery =
          invoice.invoiceNumber.toLowerCase().contains(query.toLowerCase()) ||
          (invoice.reference?.toLowerCase().contains(query.toLowerCase()) ??
              false) ||
          (invoice.notes?.toLowerCase().contains(query.toLowerCase()) ?? false);

      if (status != null && invoice.status != status.name) return false;
      if (paymentStatus != null &&
          invoice.paymentStatus != paymentStatus.name) {
        return false;
      }
      if (invoiceType != null && invoice.invoiceType != invoiceType.name) {
        return false;
      }

      return matchesQuery;
    }).toList();
  }

  // Get invoices by business ID
  Future<List<Invoice>> getInvoicesByBusinessId(int businessId) async {
    final query = _invoiceBox.query(Invoice_.businessId.equals(businessId));
    return query.build().find();
  }

  Future<String> nextInvoiceNumber(int businessId) async {
    final invoices = await getInvoicesByBusinessId(businessId);
    return InvoiceNumbering.nextNumber(invoices);
  }

  Future<bool> isInvoiceNumberAvailable({
    required int businessId,
    required String invoiceNumber,
    int? excludingInvoiceId,
  }) async {
    final invoices = await getInvoicesByBusinessId(businessId);
    return InvoiceNumbering.isAvailable(
      invoices: invoices,
      invoiceNumber: invoiceNumber,
      excludingInvoiceId: excludingInvoiceId,
    );
  }

  // Get invoices by client ID
  Future<List<Invoice>> getInvoicesByClientId(int clientId) async {
    final allInvoices = _invoiceBox.getAll();
    return allInvoices
        .where((invoice) => invoice.clientId == clientId)
        .toList();
  }

  // Get invoices by status
  Future<List<Invoice>> getInvoicesByStatus(InvoiceStatus status) async {
    final allInvoices = _invoiceBox.getAll();
    return allInvoices
        .where((invoice) => invoice.status == status.name)
        .toList();
  }

  // Get invoices by payment status
  Future<List<Invoice>> getInvoicesByPaymentStatus(
    PaymentStatus paymentStatus,
  ) async {
    final allInvoices = _invoiceBox.getAll();
    return allInvoices
        .where((invoice) => invoice.paymentStatus == paymentStatus.name)
        .toList();
  }

  // Count total invoices
  Future<int> countInvoices() async {
    return _invoiceBox.count();
  }

  // Update invoice fields
  Future<bool> updateInvoiceFields(
    int id, {
    String? invoiceNumber,
    String? invoiceNumberPrefix,
    String? reference,
    String? invoiceType,
    String? status,
    String? paymentStatus,
    String? notes,
    DateTime? issueDate,
    DateTime? dueDate,
    DateTime? sentDate,
    DateTime? viewedDate,
    DateTime? paidDate,
    int? businessId,
    int? clientId,
    int? signatureId,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    double? taxAmount,
    double? total,
    double? paidAmount,
    double? balanceDue,
    int? subtotalCents,
    int? discountAmountCents,
    int? taxAmountCents,
    int? totalCents,
    int? paidAmountCents,
    int? balanceDueCents,
    String? currency,
    bool? isRecurring,
    String? recurringFrequency,
    int? recurringInterval,
    DateTime? recurringEndDate,
    DateTime? updatedAt,
  }) async {
    final invoice = _invoiceBox.get(id);
    if (invoice == null) return false;

    final updatedInvoice = invoice.copyWith(
      invoiceNumber: invoiceNumber,
      invoiceNumberPrefix: invoiceNumberPrefix,
      reference: reference,
      invoiceType: invoiceType,
      status: status,
      paymentStatus: paymentStatus,
      notes: notes,
      issueDate: issueDate,
      dueDate: dueDate,
      sentDate: sentDate,
      viewedDate: viewedDate,
      paidDate: paidDate,
      businessId: businessId,
      clientId: clientId,
      signatureId: signatureId,
      subtotal: subtotal,
      discountRate: discountRate,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      paidAmount: paidAmount,
      balanceDue: balanceDue,
      subtotalCents: subtotalCents,
      discountAmountCents: discountAmountCents,
      taxAmountCents: taxAmountCents,
      totalCents: totalCents,
      paidAmountCents: paidAmountCents,
      balanceDueCents: balanceDueCents,
      currency: currency,
      isRecurring: isRecurring,
      recurringFrequency: recurringFrequency,
      recurringInterval: recurringInterval,
      recurringEndDate: recurringEndDate,
      updatedAt: updatedAt ?? DateTime.now(),
    );

    final result = _invoiceBox.put(updatedInvoice);
    return result > 0;
  }

  // Update invoice status
  Future<bool> updateInvoiceStatus(int id, InvoiceStatus status) async {
    return updateInvoiceFields(id, status: status.name);
  }

  // Update payment status
  Future<bool> updatePaymentStatus(int id, PaymentStatus paymentStatus) async {
    return updateInvoiceFields(id, paymentStatus: paymentStatus.name);
  }

  // Mark invoice as sent
  Future<bool> markAsSent(int id) async {
    return updateInvoiceFields(
      id,
      status: InvoiceStatus.sent.name,
      sentDate: DateTime.now(),
    );
  }

  // Mark invoice as viewed
  Future<bool> markAsViewed(int id) async {
    return updateInvoiceFields(
      id,
      status: InvoiceStatus.viewed.name,
      viewedDate: DateTime.now(),
    );
  }

  // Mark invoice as paid (full by default; pass [paidAmount] for a partial
  // payment). Reconciles paid/balance/paymentStatus via the pure
  // [InvoicePayment] so the cents spine and legacy doubles stay consistent.
  Future<bool> markAsPaid(int id, {double? paidAmount}) async {
    final invoice = _invoiceBox.get(id);
    if (invoice == null) return false;

    final outcome = InvoicePayment.pay(
      totalCents: invoice.effectiveTotalCents,
      paidAmountCents: paidAmount == null ? null : (paidAmount * 100).round(),
    );

    return updateInvoiceFields(
      id,
      status: InvoiceStatus.paid.name,
      paymentStatus: outcome.paymentStatus.name,
      paidAmount: outcome.paidAmountCents / 100,
      balanceDue: outcome.balanceDueCents / 100,
      paidAmountCents: outcome.paidAmountCents,
      balanceDueCents: outcome.balanceDueCents,
      paidDate: DateTime.now(),
    );
  }

  // Update invoice amounts
  Future<bool> updateInvoiceAmounts(
    int id, {
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    double? taxAmount,
    double? total,
    int? subtotalCents,
    int? discountAmountCents,
    int? taxAmountCents,
    int? totalCents,
  }) async {
    return updateInvoiceFields(
      id,
      subtotal: subtotal,
      discountRate: discountRate,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      subtotalCents: subtotalCents,
      discountAmountCents: discountAmountCents,
      taxAmountCents: taxAmountCents,
      totalCents: totalCents,
    );
  }

  // ================================
  //    MARK: Tax
  // ================================

  Future<void> addTaxToInvoice(int invoiceId, Tax tax) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.addTax(tax);
    _invoiceBox.put(invoice);
  }

  Future<void> removeTaxFromInvoice(int invoiceId, Tax tax) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.removeTax(tax);
    _invoiceBox.put(invoice);
  }

  Future<void> clearTaxesFromInvoice(int invoiceId) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.clearTaxes();
    _invoiceBox.put(invoice);
  }

  // ================================
  //    MARK: Term
  // ================================

  Future<void> addTermToInvoice(int invoiceId, Term term) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.addTerm(term);
    _invoiceBox.put(invoice);
  }

  Future<void> removeTermFromInvoice(int invoiceId, Term term) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.removeTerm(term);
    _invoiceBox.put(invoice);
  }

  Future<void> clearTermsFromInvoice(int invoiceId) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.clearTerms();
    _invoiceBox.put(invoice);
  }

  // ================================
  //    MARK: Item
  // ================================

  Future<List<Item>> getInvoiceItems(int invoiceId) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return [];
    return invoice.items.toList();
  }

  Future<void> addItemToInvoice(int invoiceId, Item item) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.addItem(item);
    _invoiceBox.put(invoice);
  }

  Future<void> removeItemFromInvoice(int invoiceId, Item item) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.removeItem(item);
    _invoiceBox.put(invoice);
  }

  Future<void> clearItemsFromInvoice(int invoiceId) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;
    invoice.clearItems();
    _invoiceBox.put(invoice);
  }

  // Expose invoice box for repository advanced queries
  Box<Invoice> get invoiceBox => _invoiceBox;
}
