import 'package:invois/features/item/item_model.dart';

import 'data/invoice_line_model.dart';
import 'invoice_line_math.dart';

/// In-memory pairing of a form's legacy [Item] with its authoritative decimal
/// quantity (`quantityMilli`).
///
/// Stage 4E-1: carried in form state while the UI still edits an Item-shaped
/// row. Persistence writes only [InvoiceLine] rows; legacy [Item] rows are
/// fallback input only for old invoices with no lines.
class InvoiceFormLine {
  final Item item;

  /// Quantity in thousandths (`1000 == 1.000`).
  final int quantityMilli;

  const InvoiceFormLine({required this.item, required this.quantityMilli});

  /// Whole-unit integer for the legacy [Item.stockQuantity] compat field:
  /// floor(quantity), clamped to a minimum of 1 so legacy code/validation that
  /// assumes a positive integer quantity still passes (e.g. a 0.25 line stores
  /// stockQuantity 1). Compatibility only — never drives totals/lines; the
  /// precise value is retained in [quantityMilli].
  static int legacyQuantityFor(int quantityMilli) {
    final whole = quantityMilli ~/ InvoiceLineMath.milliPerUnit;
    return whole < 1 ? 1 : whole;
  }

  int get legacyQuantity => legacyQuantityFor(quantityMilli);

  /// Line total in cents (`unitPrice × quantityMilli`, half-up at the cent).
  int get lineTotalCents => InvoiceLineMath.lineTotalCents(
    unitPriceCents: item.effectiveUnitPriceCents,
    quantityMilli: quantityMilli,
  );

  /// From a legacy item: quantity derived from `stockQuantity`
  /// (null/≤0 → one unit), mirroring [InvoiceLineMath.quantityMilliFromLegacy].
  factory InvoiceFormLine.fromItem(Item item) => InvoiceFormLine(
    item: item,
    quantityMilli: InvoiceLineMath.quantityMilliFromLegacy(item.stockQuantity),
  );

  /// Pairs a loaded legacy [item] with the authoritative [line] quantity.
  factory InvoiceFormLine.fromLine(Item item, InvoiceLine line) =>
      InvoiceFormLine(item: item, quantityMilli: line.quantityMilli);

  /// Rebuilds the temporary Item-shaped form carrier from an authoritative
  /// [InvoiceLine] snapshot. This does not create or persist an Item row.
  factory InvoiceFormLine.fromLineSnapshot(InvoiceLine line) => InvoiceFormLine(
    item: Item(
      // If this line came from a legacy Item, keep that provenance id. For
      // line-only rows, use a negative temporary id so form edits can target a
      // single row without writing a fake legacy sourceItemId later.
      id:
          line.sourceItemId ??
          (line.id != null && line.id! > 0 ? -line.id! : -(line.sortOrder + 1)),
      name: line.name,
      description: line.description,
      unit: line.unit,
      currency: line.currency,
      unitPrice: line.unitPriceCents / 100,
      unitPriceCents: line.unitPriceCents,
      taxRate: line.taxRateBasisPoints == null
          ? null
          : line.taxRateBasisPoints! / 100,
      stockQuantity: legacyQuantityFor(line.quantityMilli),
    ),
    quantityMilli: line.quantityMilli,
  );

  InvoiceFormLine copyWith({Item? item, int? quantityMilli}) => InvoiceFormLine(
    item: item ?? this.item,
    quantityMilli: quantityMilli ?? this.quantityMilli,
  );

  /// Subtotal (cents) = Σ of each form line's `unitPriceCents × quantityMilli`
  /// (half-up at the cent via [InvoiceLineMath.lineTotalCents]). The
  /// authoritative source for the form's live + stored subtotal (Step 4C-4D-2C).
  static int subtotalCents(List<InvoiceFormLine> lines) {
    var total = 0;
    for (final line in lines) {
      total += InvoiceLineMath.lineTotalCents(
        unitPriceCents: line.item.effectiveUnitPriceCents,
        quantityMilli: line.quantityMilli,
      );
    }
    return total;
  }

  /// Resolve the form-line list for a loaded invoice. Authoritative
  /// `Invoice.lines` always win when present; old legacy [items] are used only
  /// when an invoice has not been backfilled yet.
  static List<InvoiceFormLine> resolve({
    required List<Item> items,
    required List<InvoiceLine> lines,
  }) {
    if (lines.isNotEmpty) {
      final sorted = [...lines]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return [
        for (final line in sorted) InvoiceFormLine.fromLineSnapshot(line),
      ];
    }
    return [for (final item in items) InvoiceFormLine.fromItem(item)];
  }
}
