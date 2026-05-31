import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/invoice_money_backfill.dart';

void main() {
  group('S3MoneyBackfill', () {
    test(
      'converts legacy doubles to cents with the same rounding as Money',
      () {
        expect(S3MoneyBackfill.centsFromDouble(0), 0);
        expect(S3MoneyBackfill.centsFromDouble(1), 100);
        expect(S3MoneyBackfill.centsFromDouble(1.23), 123);
        expect(S3MoneyBackfill.centsFromDouble(10.235), 1024);
        expect(S3MoneyBackfill.centsFromDouble(-12.345), -1235);
      },
    );
  });
}
