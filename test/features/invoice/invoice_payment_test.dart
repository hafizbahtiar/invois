import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/domain/invoice_payment.dart';

/// Step 2 (P1-002): locks in the payment reconciliation rules that keep
/// paid/balance/paymentStatus consistent — the inconsistency the audit found
/// (status "Paid" while balanceDue == total) cannot arise from this path.
void main() {
  group('InvoicePayment.pay', () {
    test('full payment (default) -> paid, zero balance', () {
      final o = InvoicePayment.pay(totalCents: 10000);
      expect(o.paidAmountCents, 10000);
      expect(o.balanceDueCents, 0);
      expect(o.paymentStatus, PaymentStatus.paid);
    });

    test('partial payment -> partiallyPaid, remaining balance', () {
      final o = InvoicePayment.pay(totalCents: 10000, paidAmountCents: 4000);
      expect(o.paidAmountCents, 4000);
      expect(o.balanceDueCents, 6000);
      expect(o.paymentStatus, PaymentStatus.partiallyPaid);
    });

    test('overpayment -> paid, non-positive balance', () {
      final o = InvoicePayment.pay(totalCents: 10000, paidAmountCents: 12000);
      expect(o.paidAmountCents, 12000);
      expect(o.balanceDueCents, -2000);
      expect(o.paymentStatus, PaymentStatus.paid);
    });

    test('exact partial that clears the balance -> paid', () {
      final o = InvoicePayment.pay(totalCents: 5000, paidAmountCents: 5000);
      expect(o.balanceDueCents, 0);
      expect(o.paymentStatus, PaymentStatus.paid);
    });

    test('zero total -> paid, zero balance', () {
      final o = InvoicePayment.pay(totalCents: 0);
      expect(o.balanceDueCents, 0);
      expect(o.paymentStatus, PaymentStatus.paid);
    });
  });

  group('InvoicePayment.unpaid', () {
    test('resets to unpaid with full balance', () {
      final o = InvoicePayment.unpaid(totalCents: 10000);
      expect(o.paidAmountCents, 0);
      expect(o.balanceDueCents, 10000);
      expect(o.paymentStatus, PaymentStatus.unpaid);
    });
  });

  group('InvoicePayment.forManualSave (form save reconciliation)', () {
    test('status paid forces full payment even if typed amount is less', () {
      final o = InvoicePayment.forManualSave(
        status: InvoiceStatus.paid,
        totalCents: 10000,
        enteredPaidCents: 0,
      );
      expect(o.paidAmountCents, 10000);
      expect(o.balanceDueCents, 0);
      expect(o.paymentStatus, PaymentStatus.paid);
    });

    test('non-paid status with zero typed amount -> unpaid', () {
      final o = InvoicePayment.forManualSave(
        status: InvoiceStatus.sent,
        totalCents: 10000,
        enteredPaidCents: 0,
      );
      expect(o.paidAmountCents, 0);
      expect(o.balanceDueCents, 10000);
      expect(o.paymentStatus, PaymentStatus.unpaid);
    });

    test('non-paid status with partial typed amount -> partiallyPaid', () {
      final o = InvoicePayment.forManualSave(
        status: InvoiceStatus.sent,
        totalCents: 10000,
        enteredPaidCents: 2500,
      );
      expect(o.paidAmountCents, 2500);
      expect(o.balanceDueCents, 7500);
      expect(o.paymentStatus, PaymentStatus.partiallyPaid);
    });

    test('non-paid status with full typed amount -> paymentStatus paid', () {
      final o = InvoicePayment.forManualSave(
        status: InvoiceStatus.sent,
        totalCents: 10000,
        enteredPaidCents: 10000,
      );
      expect(o.balanceDueCents, 0);
      expect(o.paymentStatus, PaymentStatus.paid);
    });

    test('negative typed amount is treated as unpaid', () {
      final o = InvoicePayment.forManualSave(
        status: InvoiceStatus.draft,
        totalCents: 10000,
        enteredPaidCents: -500,
      );
      expect(o.paidAmountCents, 0);
      expect(o.paymentStatus, PaymentStatus.unpaid);
    });
  });

  group('InvoicePayment.forStatus (Step 2B invariant)', () {
    test('paid status -> fully paid fields', () {
      final o = InvoicePayment.forStatus(InvoiceStatus.paid, totalCents: 10000);
      expect(o.paidAmountCents, 10000);
      expect(o.balanceDueCents, 0);
      expect(o.paymentStatus, PaymentStatus.paid);
    });

    test('every non-paid status -> unpaid fields (no divergence)', () {
      for (final status in InvoiceStatus.values) {
        if (status == InvoiceStatus.paid) continue;
        final o = InvoicePayment.forStatus(status, totalCents: 10000);
        expect(
          o.paymentStatus,
          PaymentStatus.unpaid,
          reason: 'status=$status must map to unpaid',
        );
        expect(o.paidAmountCents, 0, reason: 'status=$status -> paid 0');
        expect(
          o.balanceDueCents,
          10000,
          reason: 'status=$status -> balance=total',
        );
      }
    });
  });
}
