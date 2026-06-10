import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/invoice_composer.dart';

void main() {
  group('InvoiceComposer.subtotalCents', () {
    test('empty lines -> 0', () {
      expect(InvoiceComposer.subtotalCents(const []), 0);
    });

    test('sums unit price * quantity in minor units', () {
      final subtotal = InvoiceComposer.subtotalCents(const [
        ComposerLine(unitPriceCents: 1000, quantity: 2), // 2000
        ComposerLine(unitPriceCents: 250, quantity: 3), //  750
      ]);
      expect(subtotal, 2750);
    });
  });

  group('InvoiceComposer.discountFromRate', () {
    test('applies a percentage to the subtotal with banker-free rounding', () {
      // 10% of 2750 = 275
      expect(
        InvoiceComposer.discountFromRate(subtotalCents: 2750, rate: 10),
        275,
      );
    });

    test('rounds half-up at the minor unit', () {
      // 33.333% of 100 = 33.333 -> 33
      expect(
        InvoiceComposer.discountFromRate(subtotalCents: 100, rate: 33.333),
        33,
      );
      // 12.5% of 101 = 12.625 -> 13
      expect(
        InvoiceComposer.discountFromRate(subtotalCents: 101, rate: 12.5),
        13,
      );
    });
  });

  group('InvoiceComposer.rateFromDiscount', () {
    test('derives the rate from an explicit discount amount', () {
      expect(
        InvoiceComposer.rateFromDiscount(
          subtotalCents: 2000,
          discountCents: 500,
        ),
        25.0,
      );
    });

    test('returns 0 when subtotal is 0 (no division by zero)', () {
      expect(
        InvoiceComposer.rateFromDiscount(subtotalCents: 0, discountCents: 500),
        0.0,
      );
    });
  });

  group('InvoiceComposer.taxOnTaxable', () {
    test('no taxes -> 0', () {
      expect(
        InvoiceComposer.taxOnTaxable(taxableCents: 1000, rates: const []),
        0,
      );
    });

    test('sums multiple taxes each applied to the taxable base', () {
      // base 1000: 6% = 60, 10% = 100 -> 160
      expect(
        InvoiceComposer.taxOnTaxable(taxableCents: 1000, rates: const [6, 10]),
        160,
      );
    });

    test('rounds each tax line independently at the minor unit', () {
      // base 105: 6% = 6.3 -> 6, 8.25% = 8.6625 -> 9 -> total 15
      expect(
        InvoiceComposer.taxOnTaxable(taxableCents: 105, rates: const [6, 8.25]),
        15,
      );
    });
  });

  group('InvoiceComposer.compose', () {
    test(
      'full spine: subtotal -> discount -> multi-tax -> total -> balance',
      () {
        final totals = InvoiceComposer.compose(
          lines: const [
            ComposerLine(unitPriceCents: 10000, quantity: 1), // 10000
            ComposerLine(unitPriceCents: 5000, quantity: 2), //  10000
          ],
          discountRate: 10, // 10% of 20000 = 2000
          taxRates: const [6], // 6% of (20000-2000)=18000 -> 1080
          paidAmountCents: 5000,
        );

        expect(totals.subtotalCents, 20000);
        expect(totals.discountAmountCents, 2000);
        expect(totals.taxAmountCents, 1080);
        expect(totals.totalCents, 19080); // 20000 - 2000 + 1080
        expect(totals.paidAmountCents, 5000);
        expect(totals.balanceDueCents, 14080); // 19080 - 5000
      },
    );

    test('explicit discount amount takes precedence over rate', () {
      final totals = InvoiceComposer.compose(
        lines: const [ComposerLine(unitPriceCents: 10000, quantity: 1)],
        discountRate: 50, // would be 5000 if used
        discountAmountCents: 1500, // explicit wins
        taxRates: const [],
      );
      expect(totals.discountAmountCents, 1500);
      expect(totals.totalCents, 8500);
    });

    test('zero everything is well defined', () {
      final totals = InvoiceComposer.compose(lines: const []);
      expect(totals.subtotalCents, 0);
      expect(totals.discountAmountCents, 0);
      expect(totals.taxAmountCents, 0);
      expect(totals.totalCents, 0);
      expect(totals.balanceDueCents, 0);
    });

    test('tax is computed on the post-discount base, not the subtotal', () {
      final totals = InvoiceComposer.compose(
        lines: const [ComposerLine(unitPriceCents: 10000, quantity: 1)],
        discountAmountCents: 2000, // taxable base = 8000
        taxRates: const [10], // 10% of 8000 = 800 (not 1000)
      );
      expect(totals.taxAmountCents, 800);
      expect(totals.totalCents, 8800); // 10000 - 2000 + 800
    });

    test('overpayment yields a negative balance due', () {
      final totals = InvoiceComposer.compose(
        lines: const [ComposerLine(unitPriceCents: 5000, quantity: 1)],
        paidAmountCents: 6000,
      );
      expect(totals.balanceDueCents, -1000);
    });
  });
}
