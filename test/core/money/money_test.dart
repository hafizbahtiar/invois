import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/money/money.dart';

void main() {
  group('Money parsing', () {
    test('parses common MYR decimal strings into cents', () {
      expect(Money.fromDecimalString('0').minorUnits, 0);
      expect(Money.fromDecimalString('1').minorUnits, 100);
      expect(Money.fromDecimalString('1.2').minorUnits, 120);
      expect(Money.fromDecimalString('1.23').minorUnits, 123);
      expect(Money.fromDecimalString('1,234.56').minorUnits, 123456);
      expect(Money.fromDecimalString('RM1,234.56').minorUnits, 123456);
    });

    test('rounds extra fractional digits to the nearest cent', () {
      expect(Money.fromDecimalString('10.234').minorUnits, 1023);
      expect(Money.fromDecimalString('10.235').minorUnits, 1024);
    });

    test('supports negative amounts for credits and refunds', () {
      expect(Money.fromDecimalString('-12.34').minorUnits, -1234);
      expect(Money.fromDecimalString('-12.345').minorUnits, -1235);
    });

    test('returns null for invalid decimal strings', () {
      expect(Money.tryParseDecimalString(''), isNull);
      expect(Money.tryParseDecimalString('abc'), isNull);
      expect(Money.tryParseDecimalString('1.2.3'), isNull);
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts without floating-point drift', () {
      final tenCents = Money.fromDecimalString('0.10');
      final total = tenCents + tenCents + tenCents;
      expect(total.minorUnits, 30);
      expect((total - tenCents).minorUnits, 20);
    });

    test('multiplies by integer quantities', () {
      final unitPrice = Money.fromDecimalString('10.10');
      expect(unitPrice.multiplyInt(3).minorUnits, 3030);
    });

    test('rejects cross-currency arithmetic', () {
      const myr = Money(100, currencyCode: 'MYR');
      const usd = Money(100, currencyCode: 'USD');
      expect(() => myr + usd, throwsArgumentError);
    });
  });

  group('MoneyCalculator', () {
    test('calculates discount and tax amounts in cents', () {
      final subtotal = Money.fromDecimalString('100.00');
      final discount = MoneyCalculator.discountForRate(
        subtotal: subtotal,
        rate: 5,
      );
      final taxable = subtotal - discount;
      final tax = MoneyCalculator.taxForRate(taxableAmount: taxable, rate: 6);

      expect(discount.minorUnits, 500);
      expect(taxable.minorUnits, 9500);
      expect(tax.minorUnits, 570);
    });

    test('calculates invoice total and balance due deterministically', () {
      final lineA = MoneyCalculator.lineTotal(
        unitPrice: Money.fromDecimalString('10.10'),
        quantity: 3,
      );
      final lineB = MoneyCalculator.lineTotal(
        unitPrice: Money.fromDecimalString('0.10'),
        quantity: 3,
      );
      final subtotal = MoneyCalculator.sum([lineA, lineB]);
      final discount = Money.fromDecimalString('5.00');
      final tax = MoneyCalculator.taxForRate(
        taxableAmount: subtotal - discount,
        rate: 6,
      );
      final total = subtotal - discount + tax;
      final balanceDue = total - Money.fromDecimalString('10.00');

      expect(subtotal.minorUnits, 3060);
      expect(tax.minorUnits, 154);
      expect(total.minorUnits, 2714);
      expect(balanceDue.minorUnits, 1714);
    });
  });
}
