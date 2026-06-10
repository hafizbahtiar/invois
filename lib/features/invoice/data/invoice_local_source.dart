import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/invoice_payment.dart';
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

  // Delete invoice and its owned InvoiceLine rows (no orphans). The lines
  // belong exclusively to the invoice, so they must go with it.
  Future<bool> deleteInvoiceById(int id) async {
    return _store.runInTransaction(TxMode.write, () {
      final invoice = _invoiceBox.get(id);
      if (invoice == null) return false;

      final lineIds = [
        for (final line in invoice.lines)
          if (line.id != null) line.id!,
      ];
      if (lineIds.isNotEmpty) {
        _store.box<InvoiceLine>().removeMany(lineIds);
      }
      return _invoiceBox.remove(id);
    });
  }

  // Get invoices by business ID
  Future<List<Invoice>> getInvoicesByBusinessId(int businessId) async {
    final query = _invoiceBox.query(Invoice_.businessId.equals(businessId));
    return query.build().find();
  }

  /// Suggest the next number for the form's *number field*, scoped to the
  /// business and the form's prefix-field text.
  ///
  /// With a non-empty [prefix] the suggestion is the sequence part only
  /// (the form composes `fullNumber = prefix + number`). With an empty
  /// [prefix] the legacy default applies: a full `INV-XXXX` suggestion
  /// carried in the number field itself.
  Future<String> nextInvoiceNumber(int businessId, {String prefix = ''}) async {
    final invoices = await getInvoicesByBusinessId(businessId);
    if (prefix.trim().isEmpty) {
      return InvoiceNumbering.nextNumber(invoices);
    }
    return InvoiceNumbering.nextSequence(invoices, prefix: prefix);
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

  // Set [status] and reconcile the payment fields so status and payment never
  // diverge (paid => fully paid, any other status => unpaid). Used by
  // markAsSent / markAsUnpaid; markAsPaid stays separate as it supports a
  // partial [paidAmount] and stamps paidDate.
  Future<bool> _applyStatusReconcilingPayment(
    int id,
    InvoiceStatus status, {
    DateTime? sentDate,
  }) async {
    final invoice = _invoiceBox.get(id);
    if (invoice == null) return false;

    final outcome = InvoicePayment.forStatus(
      status,
      totalCents: invoice.effectiveTotalCents,
    );

    return updateInvoiceFields(
      id,
      status: status.name,
      sentDate: sentDate,
      paymentStatus: outcome.paymentStatus.name,
      paidAmount: outcome.paidAmountCents / 100,
      balanceDue: outcome.balanceDueCents / 100,
      paidAmountCents: outcome.paidAmountCents,
      balanceDueCents: outcome.balanceDueCents,
    );
  }

  // Mark invoice as sent (status + sentDate). Reconciles payment to unpaid when
  // transitioning away from paid; a no-op on payment for already-unpaid rows.
  Future<bool> markAsSent(int id) {
    return _applyStatusReconcilingPayment(
      id,
      InvoiceStatus.sent,
      sentDate: DateTime.now(),
    );
  }

  // Move the invoice to a non-paid [status] and reconcile its payment fields
  // back to unpaid so a previously-paid invoice can't keep paid payment data.
  Future<bool> markAsUnpaid(int id, {required InvoiceStatus status}) {
    return _applyStatusReconcilingPayment(id, status);
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
  //    MARK: Invoice lines
  // ================================

  /// Replace the invoice's [InvoiceLine] snapshots with [lines].
  ///
  /// Deletes the existing owned line rows (no orphans) and writes the fresh set
  /// with their `invoice` relation set. Idempotent: re-running with the same
  /// input yields the same rows/count/order.
  Future<void> replaceInvoiceLines(
    int invoiceId,
    List<InvoiceLine> lines,
  ) async {
    final invoice = _invoiceBox.get(invoiceId);
    if (invoice == null) return;

    final lineBox = _store.box<InvoiceLine>();
    final existing = invoice.lines.toList();
    if (existing.isNotEmpty) {
      lineBox.removeMany([for (final l in existing) l.id!]);
    }
    if (lines.isEmpty) return;
    for (final line in lines) {
      line.invoice.target = invoice;
    }
    lineBox.putMany(lines);
  }

  // Expose invoice box for repository advanced queries
  Box<Invoice> get invoiceBox => _invoiceBox;
}
