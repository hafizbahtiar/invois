import 'data/invoice_model.dart';

/// Immutable result of reconciling an invoice's payment fields. All amounts are
/// in integer minor units (cents) — the S3 money spine.
class PaymentOutcome {
  final int paidAmountCents;
  final int balanceDueCents;
  final PaymentStatus paymentStatus;

  const PaymentOutcome({
    required this.paidAmountCents,
    required this.balanceDueCents,
    required this.paymentStatus,
  });
}

/// Pure, store-free reconciliation of invoice payment fields — no Flutter /
/// ObjectBox dependencies, so it is trivially unit-testable. Mirrors the
/// [InvoiceComposer] pattern and is the single source of truth for the
/// paid/partial/unpaid arithmetic the local source persists.
class InvoicePayment {
  const InvoicePayment._();

  /// Reconcile payment fields for a payment of [paidAmountCents] against
  /// [totalCents]. Defaults to a **full** payment (paid == total).
  ///
  /// A zero-or-negative remaining balance is treated as fully [PaymentStatus.paid]
  /// (overpayment yields a negative balance); a positive remaining balance is a
  /// [PaymentStatus.partiallyPaid].
  static PaymentOutcome pay({required int totalCents, int? paidAmountCents}) {
    final paid = paidAmountCents ?? totalCents;
    final balance = totalCents - paid;
    final status = balance <= 0
        ? PaymentStatus.paid
        : PaymentStatus.partiallyPaid;
    return PaymentOutcome(
      paidAmountCents: paid,
      balanceDueCents: balance,
      paymentStatus: status,
    );
  }

  /// Reconcile payment fields back to fully unpaid (paid 0, balance == total).
  static PaymentOutcome unpaid({required int totalCents}) {
    return PaymentOutcome(
      paidAmountCents: 0,
      balanceDueCents: totalCents,
      paymentStatus: PaymentStatus.unpaid,
    );
  }
}
