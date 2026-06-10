import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_money_backfill.dart';

void main() {
  group('LegacyInvoiceMoneyBackfill', () {
    test(
      'converts legacy doubles to cents with the same rounding as Money',
      () {
        expect(LegacyInvoiceMoneyBackfill.centsFromDouble(0), 0);
        expect(LegacyInvoiceMoneyBackfill.centsFromDouble(1), 100);
        expect(LegacyInvoiceMoneyBackfill.centsFromDouble(1.23), 123);
        expect(LegacyInvoiceMoneyBackfill.centsFromDouble(10.235), 1024);
        expect(LegacyInvoiceMoneyBackfill.centsFromDouble(-12.345), -1235);
      },
    );
  });
}
