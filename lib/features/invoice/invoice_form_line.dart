import 'package:invois/features/item/item_model.dart';

import 'data/invoice_line_model.dart';
import 'invoice_line_math.dart';

/// In-memory pairing of a form's legacy [Item] with its authoritative decimal
/// quantity (`quantityMilli`).
///
/// Step 4C-4D-2A: carried in form state ahead of the decimal UI. The visible
/// form, the write path, and the subtotal still use the legacy integer quantity
/// (`Item.stockQuantity`); this just preserves the precise quantity so a future
/// step can consume it without data loss.
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

  /// Resolve the form-line list for a loaded invoice — prefers `Invoice.lines`
  /// (authoritative `quantityMilli`, paired with [items] by `sortOrder`) and
  /// falls back to legacy [items]. Mirrors `InvoiceLineReader` but keeps the
  /// concrete [Item] the form needs.
  ///
  /// Lines are only preferred when their count matches [items] (dual-write keeps
  /// them in lockstep); otherwise we fall back to items for safety.
  static List<InvoiceFormLine> resolve({
    required List<Item> items,
    required List<InvoiceLine> lines,
  }) {
    if (lines.isNotEmpty && lines.length == items.length) {
      final sorted = [...lines]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return [
        for (var i = 0; i < items.length; i++)
          InvoiceFormLine.fromLine(items[i], sorted[i]),
      ];
    }
    return [for (final item in items) InvoiceFormLine.fromItem(item)];
  }
}
