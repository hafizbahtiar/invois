import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/data/invoice_validation.dart';
import 'package:invois/features/invoice/invoice_form_line.dart';

void main() {
  Invoice invoice({
    String invoiceNumber = 'INV-0001',
    int? businessId = 1,
    int? clientId = 1,
    DateTime? issueDate,
    DateTime? dueDate,
    int subtotalCents = 1000,
    int discountAmountCents = 0,
    int totalCents = 1000,
    int paidAmountCents = 0,
  }) {
    return Invoice(
      invoiceNumber: invoiceNumber,
      businessId: businessId,
      clientId: clientId,
      issueDate: issueDate ?? DateTime(2026, 1, 1),
      dueDate: dueDate ?? DateTime(2026, 1, 31),
      subtotalCents: subtotalCents,
      discountAmountCents: discountAmountCents,
      totalCents: totalCents,
      paidAmountCents: paidAmountCents,
    );
  }

  InvoiceFormLine line({int quantityMilli = 1000, int unitPriceCents = 1000}) {
    return InvoiceFormLine(
      name: 'Line item',
      quantityMilli: quantityMilli,
      unitPriceCents: unitPriceCents,
    );
  }

  String? validate({
    Invoice? invoiceOverride,
    List<InvoiceFormLine>? lines,
    bool hasBusiness = true,
    bool hasClient = true,
  }) {
    return InvoiceValidation.validateForSave(
      invoice: invoiceOverride ?? invoice(),
      lines: lines ?? [line()],
      hasBusiness: hasBusiness,
      hasClient: hasClient,
    );
  }

  test('rejects missing business', () {
    expect(
      validate(hasBusiness: false),
      'Please select a business before saving.',
    );
  });

  test('rejects missing client', () {
    expect(validate(hasClient: false), 'Please select a client before saving.');
  });

  test('rejects missing invoice number', () {
    expect(
      validate(invoiceOverride: invoice(invoiceNumber: '')),
      'Invoice number is required.',
    );
  });

  test('rejects no line items', () {
    expect(validate(lines: []), 'Please add at least one line item.');
  });

  test('rejects zero quantity', () {
    expect(
      validate(lines: [line(quantityMilli: 0)]),
      'Line item quantity must be greater than 0.',
    );
  });

  test('rejects negative unit price', () {
    expect(
      validate(lines: [line(unitPriceCents: -1)]),
      'Line item price cannot be negative.',
    );
  });

  test('rejects discount greater than subtotal', () {
    expect(
      validate(
        invoiceOverride: invoice(
          subtotalCents: 1000,
          discountAmountCents: 1001,
        ),
      ),
      'Discount cannot exceed subtotal.',
    );
  });

  test('rejects due date before issue date', () {
    expect(
      validate(
        invoiceOverride: invoice(
          issueDate: DateTime(2026, 2, 1),
          dueDate: DateTime(2026, 1, 31),
        ),
      ),
      'Due date cannot be before issue date.',
    );
  });

  test('rejects paid amount greater than total', () {
    expect(
      validate(
        invoiceOverride: invoice(totalCents: 1000, paidAmountCents: 1001),
      ),
      'Paid amount cannot exceed total.',
    );
  });
}
