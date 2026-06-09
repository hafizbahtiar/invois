import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/utils/string_utils.dart';

/// Step 3B: `nullIfBlank` is the contact-field normaliser used by the signature
/// repository (blank -> null, otherwise trimmed).
void main() {
  group('StringUtils.nullIfBlank', () {
    test('null stays null', () {
      expect(StringUtils.nullIfBlank(null), isNull);
    });

    test('blank email -> null', () {
      expect(StringUtils.nullIfBlank(''), isNull);
    });

    test('whitespace phone -> null', () {
      expect(StringUtils.nullIfBlank('   '), isNull);
    });

    test('trims surrounding whitespace on a real email', () {
      expect(StringUtils.nullIfBlank('  a@b.com  '), 'a@b.com');
    });

    test('trims surrounding whitespace on a real phone', () {
      expect(StringUtils.nullIfBlank('  0123456  '), '0123456');
    });

    test('leaves an already-clean value unchanged', () {
      expect(StringUtils.nullIfBlank('owner@x.com'), 'owner@x.com');
    });
  });
}
