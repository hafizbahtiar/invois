import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/pdf/invoice_tax_breakdown.dart';
import 'package:invois/features/tax/data/tax_model.dart';

/// P2-003: the PDF tax rows must always sum to the invoice's stored tax
/// snapshot, even when a referenced Tax is edited or deleted afterwards.
void main() {
  group('InvoiceTaxBreakdown.compute', () {
    test('live rates that match the snapshot render per-tax rows', () {
      // taxable RM100.00, 6% + 4% => 600 + 400 = 1000 (stored snapshot).
      final rows = InvoiceTaxBreakdown.compute(
        taxes: [
          Tax(name: 'SST', rate: 6.0),
          Tax(name: 'Service', rate: 4.0),
        ],
        taxableCents: 10000,
        storedTaxAmountCents: 1000,
      );

      expect(rows, hasLength(2));
      expect(rows[0].label, 'SST (6.00%)');
      expect(rows[0].amountCents, 600);
      expect(rows[1].label, 'Service (4.00%)');
      expect(rows[1].amountCents, 400);
    });

    test('edited tax rate falls back to a single stored aggregate row', () {
      // Invoice was saved at 6% (600), then the tax was edited to 8%.
      final rows = InvoiceTaxBreakdown.compute(
        taxes: [Tax(name: 'SST', rate: 8.0)],
        taxableCents: 10000,
        storedTaxAmountCents: 600,
      );

      expect(rows, hasLength(1));
      expect(rows.single.label, 'Tax');
      expect(rows.single.amountCents, 600);
    });

    test('deleted tax (no live rows, snapshot > 0) renders the aggregate', () {
      final rows = InvoiceTaxBreakdown.compute(
        taxes: const [],
        taxableCents: 10000,
        storedTaxAmountCents: 600,
      );

      expect(rows, hasLength(1));
      expect(rows.single.label, 'Tax');
      expect(rows.single.amountCents, 600);
    });

    test('no taxes and zero snapshot renders nothing', () {
      final rows = InvoiceTaxBreakdown.compute(
        taxes: const [],
        taxableCents: 10000,
        storedTaxAmountCents: 0,
      );

      expect(rows, isEmpty);
    });

    test('rows always sum to the stored snapshot', () {
      for (final stored in [0, 599, 600, 601, 1000]) {
        final rows = InvoiceTaxBreakdown.compute(
          taxes: [Tax(name: 'SST', rate: 6.0)],
          taxableCents: 10000,
          storedTaxAmountCents: stored,
        );
        final sum = rows.fold<int>(0, (s, r) => s + r.amountCents);
        expect(sum, stored, reason: 'stored=$stored must equal row sum');
      }
    });

    test('rounding matches the composer (Money.percent half-up)', () {
      // taxable RM0.50 at 5% => 2.5 cents -> rounds to 3 (half-up), matching
      // InvoiceComposer.taxOnTaxable; a snapshot of 3 keeps per-tax rows.
      final rows = InvoiceTaxBreakdown.compute(
        taxes: [Tax(name: 'SST', rate: 5.0)],
        taxableCents: 50,
        storedTaxAmountCents: 3,
      );

      expect(rows, hasLength(1));
      expect(rows.single.label, 'SST (5.00%)');
      expect(rows.single.amountCents, 3);
    });
  });
}
