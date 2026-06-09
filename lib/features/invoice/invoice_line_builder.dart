import 'package:invois/features/item/item_model.dart';

import 'data/invoice_line_model.dart';
import 'invoice_line_math.dart';

/// Builds [InvoiceLine] snapshots from submitted legacy [Item] rows (Step 4C-4B
/// dual-write). Pure — does not touch ObjectBox; the local source sets each
/// line's `invoice` relation when persisting.
///
/// Mirrors the Step 4B backfill mapping so dual-written lines and backfilled
/// lines are identical: `quantityMilli` from `stockQuantity`, `unitPriceCents`
/// from the effective cents, tax rate as basis points, order preserved.
class InvoiceLineBuilder {
  const InvoiceLineBuilder._();

  static List<InvoiceLine> fromItems(List<Item> items) => [
    for (var i = 0; i < items.length; i++) _fromItem(items[i], i),
  ];

  static InvoiceLine _fromItem(Item item, int sortOrder) => InvoiceLine(
    sourceItemId: (item.id != null && item.id! > 0) ? item.id : null,
    name: item.name,
    description: item.description,
    unit: item.unit,
    currency: item.currency,
    unitPriceCents: item.effectiveUnitPriceCents,
    quantityMilli: InvoiceLineMath.quantityMilliFromLegacy(item.stockQuantity),
    taxRateBasisPoints: item.taxRate == null
        ? null
        : (item.taxRate! * 100).round(),
    sortOrder: sortOrder,
  );
}
