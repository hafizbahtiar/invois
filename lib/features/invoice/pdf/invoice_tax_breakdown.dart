import 'package:invois/core/money/money.dart';
import 'package:invois/features/tax/data/tax_model.dart';

import '../data/invoice_model.dart';

/// One rendered tax row: label + amount in minor units.
class TaxBreakdownRow {
  final String label;
  final int amountCents;

  const TaxBreakdownRow(this.label, this.amountCents);
}

/// Pure tax-breakdown rows for the PDF totals box.
///
/// `Invoice.taxes` references *live* `Tax` entities, but the invoice's
/// `taxAmountCents` is a snapshot composed at save time. If a tax is edited or
/// deleted after the invoice was saved, recomputing rows from live rates would
/// disagree with the printed total (audit P2-003). The rule here guarantees the
/// rows always sum to the stored snapshot:
///   - live per-tax rows are used only when their sum equals the snapshot;
///   - otherwise a single aggregate "Tax" row carries the stored amount.
class InvoiceTaxBreakdown {
  const InvoiceTaxBreakdown._();

  static List<TaxBreakdownRow> fromInvoice(Invoice invoice) {
    return compute(
      taxes: invoice.taxes,
      taxableCents:
          invoice.effectiveSubtotalCents - invoice.effectiveDiscountAmountCents,
      storedTaxAmountCents: invoice.effectiveTaxAmountCents,
      currencyCode: invoice.currency ?? 'MYR',
    );
  }

  static List<TaxBreakdownRow> compute({
    required Iterable<Tax> taxes,
    required int taxableCents,
    required int storedTaxAmountCents,
    String currencyCode = 'MYR',
  }) {
    final taxable = Money(taxableCents, currencyCode: currencyCode);
    final liveRows = [
      for (final tax in taxes)
        TaxBreakdownRow(
          '${tax.name} (${tax.rate.toStringAsFixed(2)}%)',
          taxable.percent(tax.rate).minorUnits,
        ),
    ];
    final liveSum = liveRows.fold<int>(0, (sum, row) => sum + row.amountCents);

    if (liveSum == storedTaxAmountCents) return liveRows;
    if (storedTaxAmountCents == 0) return const [];
    return [TaxBreakdownRow('Tax', storedTaxAmountCents)];
  }
}
