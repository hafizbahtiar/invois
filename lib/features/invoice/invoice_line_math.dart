/// Pure, store-free helpers for invoice line quantity (thousandths) and line
/// totals (cents). Mirrors the [InvoiceComposer]/[InvoicePayment] pattern so the
/// rules are unit-testable without Flutter/ObjectBox. (Step 4B: only the backfill
/// and tests use these; the form/PDF/totals switch over in Step 4C.)
class InvoiceLineMath {
  const InvoiceLineMath._();

  /// Quantity unit scale: `1000 == 1.000` (0.001 precision).
  static const int milliPerUnit = 1000;

  /// Convert a legacy integer quantity (from `Item.stockQuantity`) to
  /// `quantityMilli`. Null / zero / negative legacy values fall back to one unit
  /// (`1000`) — matching the old `stockQuantity ?? 1` read.
  static int quantityMilliFromLegacy(int? legacyQuantity) {
    if (legacyQuantity == null || legacyQuantity <= 0) return milliPerUnit;
    return legacyQuantity * milliPerUnit;
  }

  /// Exact line total in cents = `unitPriceCents * (quantityMilli / 1000)`,
  /// rounded half-up at the cent using integer math (no doubles).
  static int lineTotalCents({
    required int unitPriceCents,
    required int quantityMilli,
  }) {
    final product = unitPriceCents * quantityMilli;
    return product < 0
        ? (product - milliPerUnit ~/ 2) ~/ milliPerUnit
        : (product + milliPerUnit ~/ 2) ~/ milliPerUnit;
  }

  /// Display a `quantityMilli` as a clean decimal: `1000 -> "1"`,
  /// `2500 -> "2.5"`, `1250 -> "1.25"`, `1 -> "0.001"`. (Quantities are
  /// non-negative.)
  static String formatQuantity(int quantityMilli) {
    final whole = quantityMilli ~/ milliPerUnit;
    final frac = quantityMilli % milliPerUnit;
    if (frac == 0) return '$whole';
    final fracStr = frac
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '$whole.$fracStr';
  }
}
