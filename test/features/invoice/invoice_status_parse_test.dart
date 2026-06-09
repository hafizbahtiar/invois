import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';

/// Stage 1: the model getters used to call `Enum.values.byName(status ?? '')`,
/// which THROWS on null / empty / legacy strings. These tests lock in the safe
/// `fromName` parsers and prove the getters no longer crash.
void main() {
  group('InvoiceStatusExtension.fromName', () {
    test('parses valid names', () {
      expect(InvoiceStatusExtension.fromName('paid'), InvoiceStatus.paid);
      expect(InvoiceStatusExtension.fromName('overdue'), InvoiceStatus.overdue);
    });

    test('null / empty / unknown fall back to draft', () {
      expect(InvoiceStatusExtension.fromName(null), InvoiceStatus.draft);
      expect(InvoiceStatusExtension.fromName(''), InvoiceStatus.draft);
      expect(InvoiceStatusExtension.fromName('garbage'), InvoiceStatus.draft);
    });
  });

  group('InvoiceTypeExtension.fromName', () {
    test('parses valid names', () {
      expect(InvoiceTypeExtension.fromName('estimate'), InvoiceType.estimate);
    });

    test('null / empty / unknown fall back to invoice', () {
      expect(InvoiceTypeExtension.fromName(null), InvoiceType.invoice);
      expect(InvoiceTypeExtension.fromName('nope'), InvoiceType.invoice);
    });
  });

  group('PaymentStatusExtension.fromName', () {
    test('parses valid names', () {
      expect(
        PaymentStatusExtension.fromName('partiallyPaid'),
        PaymentStatus.partiallyPaid,
      );
    });

    test('null / empty / unknown fall back to unpaid', () {
      expect(PaymentStatusExtension.fromName(null), PaymentStatus.unpaid);
      expect(PaymentStatusExtension.fromName('???'), PaymentStatus.unpaid);
    });
  });

  group('RecurringFrequencyExtension.fromName', () {
    test('parses valid names', () {
      expect(
        RecurringFrequencyExtension.fromName('weekly'),
        RecurringFrequency.weekly,
      );
      expect(
        RecurringFrequencyExtension.fromName('yearly'),
        RecurringFrequency.yearly,
      );
    });

    test('null / empty / unknown fall back to monthly', () {
      expect(
        RecurringFrequencyExtension.fromName(null),
        RecurringFrequency.monthly,
      );
      expect(
        RecurringFrequencyExtension.fromName(''),
        RecurringFrequency.monthly,
      );
      expect(
        RecurringFrequencyExtension.fromName('biweekly'),
        RecurringFrequency.monthly,
      );
    });
  });

  group('Invoice getters do not throw on null/legacy status', () {
    Invoice invoiceWith({String? status, String? type, String? payment}) {
      return Invoice(
        invoiceNumber: 'INV-1',
        issueDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 15),
        status: status,
        invoiceType: type,
        paymentStatus: payment,
      );
    }

    test('null status', () {
      final invoice = invoiceWith();
      expect(() => invoice.statusDisplay, returnsNormally);
      expect(() => invoice.isOverdue, returnsNormally);
      expect(() => invoice.canEdit, returnsNormally);
      expect(() => invoice.canSend, returnsNormally);
      expect(() => invoice.canCancel, returnsNormally);
      expect(invoice.statusDisplay, 'Draft');
    });

    test('legacy/garbage status', () {
      final invoice = invoiceWith(
        status: 'archived_v1',
        type: 'proforma',
        payment: 'pending',
      );
      expect(invoice.statusDisplay, 'Draft');
      expect(invoice.invoiceTypeDisplay, 'Invoice');
      expect(invoice.paymentStatusDisplay, 'Unpaid');
    });
  });

  group('Invoice signatureId compatibility', () {
    test('fromMap accepts old invoices without a signatureId', () {
      final invoice = Invoice.fromMap({
        'invoiceNumber': 'INV-OLD',
        'issueDate': DateTime(2026, 1, 1).toIso8601String(),
        'dueDate': DateTime(2026, 1, 15).toIso8601String(),
      });

      expect(invoice.signatureId, isNull);
      expect(() => invoice.statusDisplay, returnsNormally);
    });

    test('toMap/fromMap preserves selected signatureId', () {
      final invoice = Invoice(
        invoiceNumber: 'INV-SIGNED',
        issueDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 15),
        signatureId: 42,
      );

      final restored = Invoice.fromMap(invoice.toMap());

      expect(restored.signatureId, 42);
    });
  });
}
