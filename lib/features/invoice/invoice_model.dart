import 'package:equatable/equatable.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/core/utils/safe_parse.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/tax/tax_module.dart';
import 'package:invois/features/term/term_model.dart';
import 'package:objectbox/objectbox.dart';

/// Enum to define the invoice status
enum InvoiceStatus { draft, sent, viewed, paid, overdue, cancelled, refunded }

extension InvoiceStatusExtension on InvoiceStatus {
  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Enum to define the payment status
enum PaymentStatus { unpaid, partiallyPaid, paid, refunded }

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Enum to define the invoice type
enum InvoiceType { invoice, estimate, creditNote, debitNote, receipt }

extension InvoiceTypeExtension on InvoiceType {
  String get displayName {
    switch (this) {
      case InvoiceType.invoice:
        return 'Invoice';
      case InvoiceType.estimate:
        return 'Estimate';
      case InvoiceType.creditNote:
        return 'Credit Note';
      case InvoiceType.debitNote:
        return 'Debit Note';
      case InvoiceType.receipt:
        return 'Receipt';
    }
  }
}

/// Enum to define the recurring frequency
enum RecurringFrequency { daily, weekly, monthly, yearly }

extension RecurringFrequencyExtension on RecurringFrequency {
  String get displayName {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }
}

/// Main Invoice model
@Entity()
// ignore: must_be_immutable
class Invoice extends Equatable {
  @Id()
  int? id;

  // Basic Information

  final String invoiceNumber;
  final String? invoiceNumberPrefix;
  final String? reference;

  // Enum getters/setters
  final String? invoiceType;
  final String? status;
  final String? paymentStatus;

  final String? notes;

  // Dates
  @Property(type: PropertyType.date)
  final DateTime issueDate;

  @Property(type: PropertyType.date)
  final DateTime dueDate;

  @Property(type: PropertyType.date)
  final DateTime? sentDate;

  @Property(type: PropertyType.date)
  final DateTime? viewedDate;

  @Property(type: PropertyType.date)
  final DateTime? paidDate;

  // Relationships
  final int? businessId;
  final int? clientId;

  // Pricing
  final double subtotal;
  final double discountRate;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final double paidAmount;
  final double balanceDue;
  final String? currency;

  // Stage A S3: additive integer minor-unit fields. These remain nullable
  // until the migration backfills existing rows and read paths switch over.
  int? subtotalCents;
  int? discountAmountCents;
  int? taxAmountCents;
  int? totalCents;
  int? paidAmountCents;
  int? balanceDueCents;

  // Additional Information
  final bool isRecurring;
  final String? recurringFrequency; // daily, weekly, monthly, yearly
  final int? recurringInterval;

  @Property(type: PropertyType.date)
  final DateTime? recurringEndDate;

  // Timestamps
  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  // Relationships with ObjectBox
  final ToMany<Item> items = ToMany<Item>();

  // One-to-many relationship with Tax
  final ToMany<Tax> taxes = ToMany<Tax>();

  // One-to-many relationship with Term
  final ToMany<Term> terms = ToMany<Term>();

  Invoice({
    this.id = 0,
    required this.invoiceNumber,
    this.invoiceNumberPrefix,
    this.reference,
    this.invoiceType,
    this.status,
    this.paymentStatus,
    this.notes,
    required this.issueDate,
    required this.dueDate,
    this.sentDate,
    this.viewedDate,
    this.paidDate,
    this.businessId,
    this.clientId,
    this.subtotal = 0.0,
    this.discountRate = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    this.paidAmount = 0.0,
    this.balanceDue = 0.0,
    this.currency,
    this.subtotalCents,
    this.discountAmountCents,
    this.taxAmountCents,
    this.totalCents,
    this.paidAmountCents,
    this.balanceDueCents,
    this.isRecurring = false,
    this.recurringFrequency,
    this.recurringInterval,
    this.recurringEndDate,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    reference,
    invoiceType,
    status,
    paymentStatus,
    notes,
    terms,
    issueDate,
    dueDate,
    sentDate,
    viewedDate,
    paidDate,
    businessId,
    clientId,
    subtotal,
    discountRate,
    discountAmount,
    taxAmount,
    total,
    paidAmount,
    balanceDue,
    currency,
    subtotalCents,
    discountAmountCents,
    taxAmountCents,
    totalCents,
    paidAmountCents,
    balanceDueCents,
    isRecurring,
    recurringFrequency,
    recurringInterval,
    recurringEndDate,
    createdAt,
    updatedAt,
  ];

  Invoice copyWith({
    int? id,
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
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    double? taxAmount,
    double? total,
    double? paidAmount,
    double? balanceDue,
    String? currency,
    int? subtotalCents,
    int? discountAmountCents,
    int? taxAmountCents,
    int? totalCents,
    int? paidAmountCents,
    int? balanceDueCents,
    bool? isRecurring,
    String? recurringFrequency,
    int? recurringInterval,
    DateTime? recurringEndDate,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceNumberPrefix: invoiceNumberPrefix ?? this.invoiceNumberPrefix,
      reference: reference ?? this.reference,
      invoiceType: invoiceType ?? this.invoiceType,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      sentDate: sentDate ?? this.sentDate,
      viewedDate: viewedDate ?? this.viewedDate,
      paidDate: paidDate ?? this.paidDate,
      businessId: businessId ?? this.businessId,
      clientId: clientId ?? this.clientId,
      subtotal: subtotal ?? this.subtotal,
      discountRate: discountRate ?? this.discountRate,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      currency: currency ?? this.currency,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      discountAmountCents: discountAmountCents ?? this.discountAmountCents,
      taxAmountCents: taxAmountCents ?? this.taxAmountCents,
      totalCents: totalCents ?? this.totalCents,
      paidAmountCents: paidAmountCents ?? this.paidAmountCents,
      balanceDueCents: balanceDueCents ?? this.balanceDueCents,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'invoiceNumberPrefix': invoiceNumberPrefix,
      'reference': reference,
      'invoiceType': invoiceType,
      'status': status,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'terms': terms,
      'issueDate': issueDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'sentDate': sentDate?.toIso8601String(),
      'viewedDate': viewedDate?.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'businessId': businessId,
      'clientId': clientId,
      'subtotal': subtotal,
      'discountRate': discountRate,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'total': total,
      'paidAmount': paidAmount,
      'balanceDue': balanceDue,
      'currency': currency,
      'subtotalCents': subtotalCents,
      'discountAmountCents': discountAmountCents,
      'taxAmountCents': taxAmountCents,
      'totalCents': totalCents,
      'paidAmountCents': paidAmountCents,
      'balanceDueCents': balanceDueCents,
      'isRecurring': isRecurring,
      'recurringFrequency': recurringFrequency,
      'recurringInterval': recurringInterval,
      'recurringEndDate': recurringEndDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: SafeParse.integer(map['id']),
      invoiceNumber: SafeParse.string(map['invoiceNumber']),
      invoiceNumberPrefix: SafeParse.string(map['invoiceNumberPrefix']),
      reference: SafeParse.string(map['reference']),
      invoiceType: SafeParse.string(map['invoiceType']),
      status: SafeParse.string(map['status']),
      paymentStatus: SafeParse.string(map['paymentStatus']),
      notes: SafeParse.string(map['notes']),
      issueDate: SafeParse.dateTime(map['issueDate']) ?? DateTime.now(),
      dueDate: SafeParse.dateTime(map['dueDate']) ?? DateTime.now(),
      sentDate: SafeParse.dateTime(map['sentDate']),
      viewedDate: SafeParse.dateTime(map['viewedDate']),
      paidDate: SafeParse.dateTime(map['paidDate']),
      businessId: SafeParse.integer(map['businessId']),
      clientId: SafeParse.integer(map['clientId']),
      subtotal: SafeParse.decimal(map['subtotal'], fallback: 0.0),
      discountRate: SafeParse.decimal(map['discountRate'], fallback: 0.0),
      discountAmount: SafeParse.decimal(map['discountAmount'], fallback: 0.0),
      taxAmount: SafeParse.decimal(map['taxAmount'], fallback: 0.0),
      total: SafeParse.decimal(map['total'], fallback: 0.0),
      paidAmount: SafeParse.decimal(map['paidAmount'], fallback: 0.0),
      balanceDue: SafeParse.decimal(map['balanceDue'], fallback: 0.0),
      currency: SafeParse.string(map['currency']),
      subtotalCents: SafeParse.integer(map['subtotalCents']),
      discountAmountCents: SafeParse.integer(map['discountAmountCents']),
      taxAmountCents: SafeParse.integer(map['taxAmountCents']),
      totalCents: SafeParse.integer(map['totalCents']),
      paidAmountCents: SafeParse.integer(map['paidAmountCents']),
      balanceDueCents: SafeParse.integer(map['balanceDueCents']),
      isRecurring: SafeParse.boolean(map['isRecurring'], fallback: false),
      recurringFrequency: SafeParse.string(map['recurringFrequency']),
      recurringInterval: SafeParse.integer(map['recurringInterval']),
      recurringEndDate: SafeParse.dateTime(map['recurringEndDate']),
      createdAt: SafeParse.dateTime(map['createdAt']),
      updatedAt: SafeParse.dateTime(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Invoice(id: $id, invoiceNumber: $invoiceNumber, invoiceNumberPrefix: $invoiceNumberPrefix, status: $status, total: $total, balanceDue: $balanceDue)';
  }

  // ================================
  //    MARK: Item
  // ================================

  /// Add an item to the invoice
  void addItem(Item item) {
    items.add(item);
  }

  /// Remove an item from the invoice
  void removeItem(Item item) {
    items.remove(item);
  }

  /// Clear all items from the invoice
  void clearItems() {
    items.clear();
  }

  /// Get sorted items by sort order
  List<Item> get sortedItems {
    final sorted = items.toList();
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  /// Check if invoice is overdue
  bool get isOverdue {
    return InvoiceStatus.values.byName(status ?? '') != InvoiceStatus.paid &&
        InvoiceStatus.values.byName(status ?? '') != InvoiceStatus.cancelled &&
        dueDate.isBefore(DateTime.now());
  }

  /// Check if invoice is fully paid
  bool get isFullyPaid {
    return balanceDue <= 0;
  }

  /// Get days overdue
  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(dueDate).inDays;
  }

  /// Get days until due
  int get daysUntilDue {
    if (isOverdue) return 0;
    return dueDate.difference(DateTime.now()).inDays;
  }

  /// Get formatted currency
  String get formattedCurrency {
    return currency ?? '\$';
  }

  String get moneyCurrencyCode => currency ?? 'MYR';

  int get effectiveSubtotalCents =>
      subtotalCents ?? Money.fromDouble(subtotal).minorUnits;
  int get effectiveDiscountAmountCents =>
      discountAmountCents ?? Money.fromDouble(discountAmount).minorUnits;
  int get effectiveTaxAmountCents =>
      taxAmountCents ?? Money.fromDouble(taxAmount).minorUnits;
  int get effectiveTotalCents =>
      totalCents ?? Money.fromDouble(total).minorUnits;
  int get effectivePaidAmountCents =>
      paidAmountCents ?? Money.fromDouble(paidAmount).minorUnits;
  int get effectiveBalanceDueCents =>
      balanceDueCents ?? Money.fromDouble(balanceDue).minorUnits;

  /// Get formatted total
  String get formattedTotal {
    return '$formattedCurrency${total.toStringAsFixed(2)}';
  }

  /// Get formatted balance due
  String get formattedBalanceDue {
    return '$formattedCurrency${balanceDue.toStringAsFixed(2)}';
  }

  /// Get formatted paid amount
  String get formattedPaidAmount {
    return '$formattedCurrency${paidAmount.toStringAsFixed(2)}';
  }

  /// Get invoice type display name
  String get invoiceTypeDisplay {
    switch (InvoiceType.values.byName(invoiceType ?? '')) {
      case InvoiceType.invoice:
        return 'Invoice';
      case InvoiceType.estimate:
        return 'Estimate';
      case InvoiceType.creditNote:
        return 'Credit Note';
      case InvoiceType.debitNote:
        return 'Debit Note';
      case InvoiceType.receipt:
        return 'Receipt';
    }
  }

  /// Get status display name
  String get statusDisplay {
    switch (InvoiceStatus.values.byName(status ?? '')) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }

  /// Get payment status display name
  String get paymentStatusDisplay {
    switch (PaymentStatus.values.byName(paymentStatus ?? '')) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  /// Check if invoice can be edited
  bool get canEdit {
    return InvoiceStatus.values.byName(status ?? '') == InvoiceStatus.draft;
  }

  /// Check if invoice can be sent
  bool get canSend {
    return InvoiceStatus.values.byName(status ?? '') == InvoiceStatus.draft &&
        items.isNotEmpty;
  }

  /// Check if invoice can be marked as paid
  bool get canMarkAsPaid {
    return InvoiceStatus.values.byName(status ?? '') !=
            InvoiceStatus.cancelled &&
        InvoiceStatus.values.byName(status ?? '') != InvoiceStatus.refunded &&
        !isFullyPaid;
  }

  /// Check if invoice can be cancelled
  bool get canCancel {
    return InvoiceStatus.values.byName(status ?? '') != InvoiceStatus.paid &&
        InvoiceStatus.values.byName(status ?? '') != InvoiceStatus.cancelled &&
        InvoiceStatus.values.byName(status ?? '') != InvoiceStatus.refunded;
  }

  /// Get payment percentage
  double get paymentPercentage {
    if (total == 0) return 0.0;
    return (paidAmount / total) * 100;
  }

  /// Get overdue status text
  String get overdueStatus {
    if (!isOverdue) return '';
    if (daysOverdue == 1) return '1 day overdue';
    return '$daysOverdue days overdue';
  }

  /// Get due status text
  String get dueStatus {
    if (isOverdue) return overdueStatus;
    if (daysUntilDue == 0) return 'Due today';
    if (daysUntilDue == 1) return 'Due tomorrow';
    if (daysUntilDue <= 7) return 'Due in $daysUntilDue days';
    return 'Due ${dueDate.toString().split(' ')[0]}';
  }

  // ================================
  //    MARK: Tax
  // ================================

  /// Add a tax to the invoice
  void addTax(Tax tax) {
    taxes.add(tax);
  }

  /// Remove a tax from the invoice
  void removeTax(Tax tax) {
    taxes.remove(tax);
  }

  /// Clear all taxes from the invoice
  void clearTaxes() {
    taxes.clear();
  }

  // ================================
  //    MARK: Term
  // ================================

  /// Add a term to the invoice
  void addTerm(Term term) {
    terms.add(term);
  }

  /// Remove a term from the invoice
  void removeTerm(Term term) {
    terms.remove(term);
  }

  /// Clear all terms from the invoice
  void clearTerms() {
    terms.clear();
  }
}
