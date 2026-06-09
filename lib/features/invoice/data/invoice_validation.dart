import 'package:invois/features/item/item_model.dart';

import 'invoice_model.dart';
import 'invoice_numbering.dart';

class InvoiceValidation {
  const InvoiceValidation._();

  static String? validateForSave({
    required Invoice invoice,
    required List<Item> items,
    required bool hasBusiness,
    required bool hasClient,
  }) {
    if (!hasBusiness) return 'Please select a business before saving.';
    if (!hasClient) return 'Please select a client before saving.';

    if (InvoiceNumbering.fullNumber(invoice).trim().isEmpty) {
      return 'Invoice number is required.';
    }

    if (items.isEmpty) {
      return 'Please add at least one line item.';
    }

    for (final item in items) {
      if ((item.stockQuantity ?? 1) <= 0) {
        return 'Line item quantity must be greater than 0.';
      }
      if (item.effectiveUnitPriceCents < 0) {
        return 'Line item price cannot be negative.';
      }
    }

    if (invoice.effectiveDiscountAmountCents > invoice.effectiveSubtotalCents) {
      return 'Discount cannot exceed subtotal.';
    }

    if (invoice.dueDate.isBefore(invoice.issueDate)) {
      return 'Due date cannot be before issue date.';
    }

    if (invoice.effectivePaidAmountCents > invoice.effectiveTotalCents) {
      return 'Paid amount cannot exceed total.';
    }

    return null;
  }
}
