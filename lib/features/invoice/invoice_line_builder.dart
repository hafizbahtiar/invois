import 'package:invois/features/item/item_model.dart';

import 'data/invoice_line_model.dart';
import 'invoice_form_line.dart';

/// Builds [InvoiceLine] snapshots for the dual-write.
///
/// [fromFormLines] is the authoritative path (Step 4C-4D-2C): it preserves the
/// form's exact `quantityMilli`. [fromItems] (the legacy/backfill-equivalent
/// path, kept for compatibility) derives the quantity from `stockQuantity` and
/// delegates to [fromFormLines]. Pure — does not touch ObjectBox; the local
/// source sets each line's `invoice` relation when persisting.
class InvoiceLineBuilder {
  const InvoiceLineBuilder._();

  /// Authoritative: preserves each form line's `quantityMilli` exactly.
  static List<InvoiceLine> fromFormLines(List<InvoiceFormLine> formLines) => [
    for (var i = 0; i < formLines.length; i++) _fromFormLine(formLines[i], i),
  ];

  /// Legacy items path (quantity from `stockQuantity`); delegates to
  /// [fromFormLines] via [InvoiceFormLine.fromItem].
  static List<InvoiceLine> fromItems(List<Item> items) =>
      fromFormLines([for (final item in items) InvoiceFormLine.fromItem(item)]);

  static InvoiceLine _fromFormLine(InvoiceFormLine line, int sortOrder) {
    final item = line.item;
    return InvoiceLine(
      sourceItemId: (item.id != null && item.id! > 0) ? item.id : null,
      name: item.name,
      description: item.description,
      unit: item.unit,
      currency: item.currency,
      unitPriceCents: item.effectiveUnitPriceCents,
      quantityMilli:
          line.quantityMilli, // authoritative — not from stockQuantity
      taxRateBasisPoints: item.taxRate == null
          ? null
          : (item.taxRate! * 100).round(),
      sortOrder: sortOrder,
    );
  }
}
