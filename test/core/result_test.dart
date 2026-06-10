import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';

void main() {
  group('Result', () {
    test('Ok folds to the value branch', () {
      const result = Ok<int>(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
      expect(result.fold((v) => 'ok:$v', (f) => 'err'), 'ok:42');
      expect(result.orThrow(), 42);
    });

    test('Err folds to the failure branch', () {
      const failure = NotFoundFailure('missing');
      const result = Err<int>(failure);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
      expect(
        result.fold((v) => 'ok', (f) => 'err:${f.message}'),
        'err:missing',
      );
    });

    test('orThrow throws the AppFailure for Err', () {
      const result = Err<int>(DatabaseFailure('boom'));
      expect(result.orThrow, throwsA(isA<DatabaseFailure>()));
    });
  });

  group('AppFailure', () {
    test('UniqueViolation builds a readable message from the field', () {
      const f = UniqueViolation('email');
      expect(f.field, 'email');
      expect(f.message, contains('email'));
      expect(f, isA<DatabaseFailure>());
    });
  });
}
