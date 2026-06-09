/// Pure, store-free helpers for invoice line quantity (thousandths) and line
/// totals (cents). Mirrors the [InvoiceComposer]/[InvoicePayment] pattern so the
/// rules are unit-testable without Flutter/ObjectBox.
class InvoiceLineMath {
  const InvoiceLineMath._();

  /// Quantity unit scale: `1000 == 1.000` (0.001 precision).
  static const int milliPerUnit = 1000;

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
