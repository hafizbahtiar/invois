import 'package:invois/core/money/money.dart';

/// One priced invoice line: a unit price in minor units and a quantity.
class ComposerLine {
  final int unitPriceCents;
  final int quantity;

  const ComposerLine({required this.unitPriceCents, required this.quantity});
}

/// Immutable result of composing an invoice's money fields. All amounts are in
/// integer minor units (cents) — the S3 money spine.
class InvoiceTotals {
  final int subtotalCents;
  final int discountAmountCents;
  final int taxAmountCents;
  final int totalCents;
  final int paidAmountCents;
  final int balanceDueCents;

  const InvoiceTotals({
    required this.subtotalCents,
    required this.discountAmountCents,
    required this.taxAmountCents,
    required this.totalCents,
    required this.paidAmountCents,
    required this.balanceDueCents,
  });
}

/// Pure invoice money composition — no Flutter / ObjectBox dependencies, so it
/// is trivially unit-testable and isolate-safe.
///
/// This centralises the rules that were previously inlined across
/// `invoice_form_page.dart` and `invoice_form_provider.dart`:
///   subtotal = Σ(unitPrice × qty)
///   discount = explicit amount, else subtotal × rate%
///   tax      = Σ over each rate of (subtotal − discount) × rate%
///   total    = subtotal − discount + tax
///   balance  = total − paid
class InvoiceComposer {
  const InvoiceComposer._();

  /// Σ of `unitPriceCents × quantity` across all lines (exact integer math).
  static int subtotalCents(Iterable<ComposerLine> lines) {
    return lines.fold(
      0,
      (sum, line) => sum + line.unitPriceCents * line.quantity,
    );
  }

  /// Discount amount (minor units) for a percentage [rate] of [subtotalCents].
  /// Rounds half-up at the minor unit, matching [Money.percent].
  static int discountFromRate({
    required int subtotalCents,
    required double rate,
    String currencyCode = 'MYR',
  }) {
    return Money(subtotalCents, currencyCode: currencyCode).percent(rate).minorUnits;
  }

  /// Inverse of [discountFromRate]: the percentage an explicit discount
  /// represents. Returns 0 when the subtotal is 0 (no division by zero).
  static double rateFromDiscount({
    required int subtotalCents,
    required int discountCents,
  }) {
    if (subtotalCents <= 0) return 0.0;
    return (discountCents / subtotalCents) * 100;
  }

  /// Total tax (minor units): each rate is applied to the taxable base
  /// independently and rounded at the minor unit, then summed — matching the
  /// prior per-tax accumulation in the form.
  static int taxOnTaxable({
    required int taxableCents,
    required Iterable<double> rates,
    String currencyCode = 'MYR',
  }) {
    final taxable = Money(taxableCents, currencyCode: currencyCode);
    var total = 0;
    for (final rate in rates) {
      total += taxable.percent(rate).minorUnits;
    }
    return total;
  }

  /// Compose the full set of invoice money fields.
  ///
  /// When [discountAmountCents] is provided it takes precedence over
  /// [discountRate] (the form lets the user type either; the typed amount wins).
  ///
  /// [subtotalCentsOverride] lets callers supply a subtotal computed elsewhere
  /// (Step 4C-4C: from `InvoiceLineReader`, so totals share the same line source
  /// as detail/PDF). When null, the subtotal is computed from [lines] as before.
  static InvoiceTotals compose({
    Iterable<ComposerLine> lines = const [],
    int? subtotalCentsOverride,
    int? discountAmountCents,
    double discountRate = 0.0,
    Iterable<double> taxRates = const [],
    int paidAmountCents = 0,
    String currencyCode = 'MYR',
  }) {
    final subtotal = subtotalCentsOverride ?? subtotalCents(lines);
    final discount = discountAmountCents ??
        discountFromRate(
          subtotalCents: subtotal,
          rate: discountRate,
          currencyCode: currencyCode,
        );
    final taxableCents = subtotal - discount;
    final tax = taxOnTaxable(
      taxableCents: taxableCents,
      rates: taxRates,
      currencyCode: currencyCode,
    );
    final total = subtotal - discount + tax;
    final balance = total - paidAmountCents;

    return InvoiceTotals(
      subtotalCents: subtotal,
      discountAmountCents: discount,
      taxAmountCents: tax,
      totalCents: total,
      paidAmountCents: paidAmountCents,
      balanceDueCents: balance,
    );
  }
}
