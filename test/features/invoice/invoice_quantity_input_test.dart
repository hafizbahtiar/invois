import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/domain/invoice_quantity_input.dart';

/// Step 4C-4D-1: pure quantity parser/formatter.
void main() {
  int? parse(String s) => InvoiceQuantityInput.parse(s).quantityMilli;

  group('parse — valid', () {
    test('whole "1" -> 1000', () => expect(parse('1'), 1000));
    test('"1.0" -> 1000', () => expect(parse('1.0'), 1000));
    test('"1.5" -> 1500', () => expect(parse('1.5'), 1500));
    test('"1.50" -> 1500', () => expect(parse('1.50'), 1500));
    test('"0.25" -> 250', () => expect(parse('0.25'), 250));
    test('leading dot ".5" -> 500', () => expect(parse('.5'), 500));
    test('"001.500" -> 1500', () => expect(parse('001.500'), 1500));
    test('whitespace " 2.25 " -> 2250', () => expect(parse(' 2.25 '), 2250));
    test('min "0.001" -> 1', () => expect(parse('0.001'), 1));
  });

  group('parse — invalid (returns failure, no throw)', () {
    void expectInvalid(String s) {
      final r = InvoiceQuantityInput.parse(s);
      expect(r.isValid, isFalse, reason: 'expected "$s" invalid');
      expect(r.quantityMilli, isNull);
      expect(r.error, isNotNull);
    }

    test('empty', () => expectInvalid(''));
    test('whitespace only', () => expectInvalid('   '));
    test('zero', () => expectInvalid('0'));
    test('zero decimals', () => expectInvalid('0.000'));
    test('negative', () => expectInvalid('-1'));
    test('text', () => expectInvalid('abc'));
    test('too many decimals', () => expectInvalid('1.2345'));
    test('comma decimal rejected', () => expectInvalid('1,5'));
    test('bare dot', () => expectInvalid('.'));
    test('double dot', () => expectInvalid('..'));
    test('trailing dot "1." rejected', () => expectInvalid('1.'));
  });

  group('failure messages are specific', () {
    test('empty -> "Enter a quantity"', () {
      expect(InvoiceQuantityInput.parse('').error, 'Enter a quantity');
    });
    test('comma -> dot hint', () {
      expect(
        InvoiceQuantityInput.parse('1,5').error,
        'Use a dot (.) for decimals',
      );
    });
    test('too many decimals -> 3-places hint', () {
      expect(
        InvoiceQuantityInput.parse('1.2345').error,
        'Use at most 3 decimal places',
      );
    });
    test('zero -> greater-than-0', () {
      expect(
        InvoiceQuantityInput.parse('0').error,
        'Quantity must be greater than 0',
      );
    });
  });

  group('format', () {
    test('1000 -> "1"', () => expect(InvoiceQuantityInput.format(1000), '1'));
    test(
      '1500 -> "1.5"',
      () => expect(InvoiceQuantityInput.format(1500), '1.5'),
    );
    test(
      '1250 -> "1.25"',
      () => expect(InvoiceQuantityInput.format(1250), '1.25'),
    );
    test(
      '250 -> "0.25"',
      () => expect(InvoiceQuantityInput.format(250), '0.25'),
    );
    test('1 -> "0.001"', () => expect(InvoiceQuantityInput.format(1), '0.001'));
  });

  test('parse then format round-trips for a clean value', () {
    final q = InvoiceQuantityInput.parse('2.5').quantityMilli!;
    expect(InvoiceQuantityInput.format(q), '2.5');
  });
}
