import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_type.dart';

/// Tests for the safe route-argument enum parsers.
///
/// `generate_route.dart` used to call `Enum.values.byName(type)` on route
/// arguments, which throws `ArgumentError` on null/empty/unknown values —
/// crashing the route generator. The `fromName` extensions fall back to a
/// safe default instead.
void main() {
  group('FormTypeExtension.fromName', () {
    test('parses all valid names', () {
      for (final value in FormType.values) {
        expect(FormTypeExtension.fromName(value.name), value);
      }
    });

    test('null falls back to add', () {
      expect(FormTypeExtension.fromName(null), FormType.add);
    });

    test('empty string falls back to add', () {
      expect(FormTypeExtension.fromName(''), FormType.add);
    });

    test('unknown / malformed value falls back to add', () {
      expect(FormTypeExtension.fromName('garbage'), FormType.add);
      expect(FormTypeExtension.fromName('ADD'), FormType.add);
      expect(FormTypeExtension.fromName('add '), FormType.add);
      expect(FormTypeExtension.fromName('delete'), FormType.add);
    });

    test('does not throw on any input', () {
      expect(() => FormTypeExtension.fromName(null), returnsNormally);
      expect(() => FormTypeExtension.fromName(''), returnsNormally);
      expect(() => FormTypeExtension.fromName('bogus'), returnsNormally);
    });
  });

  group('ListTypeExtension.fromName', () {
    test('parses all valid names', () {
      for (final value in ListType.values) {
        expect(ListTypeExtension.fromName(value.name), value);
      }
    });

    test('null falls back to list', () {
      expect(ListTypeExtension.fromName(null), ListType.list);
    });

    test('empty string falls back to list', () {
      expect(ListTypeExtension.fromName(''), ListType.list);
    });

    test('unknown / malformed value falls back to list', () {
      expect(ListTypeExtension.fromName('garbage'), ListType.list);
      expect(ListTypeExtension.fromName('LIST'), ListType.list);
      expect(ListTypeExtension.fromName('list '), ListType.list);
      expect(ListTypeExtension.fromName('grid'), ListType.list);
    });

    test('does not throw on any input', () {
      expect(() => ListTypeExtension.fromName(null), returnsNormally);
      expect(() => ListTypeExtension.fromName(''), returnsNormally);
      expect(() => ListTypeExtension.fromName('bogus'), returnsNormally);
    });
  });
}