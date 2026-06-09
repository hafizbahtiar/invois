@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/signature/data/signature_local_source.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_repository.dart';

/// Step 3A (P1-004): characterises the `@Unique` nullable email/phone behaviour
/// on [Signature]. Requires the native `libobjectbox` library — tagged
/// `objectbox` and skipped by default; run with:
///   flutter test --tags objectbox --run-skipped
///
/// These tests encode the *expected* business rule (multiple contactless
/// signatures allowed) and document the *current* GLOBAL uniqueness (which
/// Step 3B should revisit). If ObjectBox rejected duplicate nulls, the first
/// group would fail here — that is exactly the verification we want.
void main() {
  late Store store;
  late SignatureRepository repo;

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:sig-unique-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = SignatureRepository(
      SignatureLocalSource.withDependencies(store: store),
    );
  });

  tearDown(() => store.close());

  group('Signature @Unique nullable email/phone (P1-004)', () {
    test('two signatures with null email AND null phone are both allowed',
        () async {
      final a = await repo.create(Signature(name: 'Owner A'));
      final b = await repo.create(Signature(name: 'Owner B'));
      expect(a, isA<Ok<Signature>>());
      expect(
        b,
        isA<Ok<Signature>>(),
        reason: 'contactless signatures must not collide on null unique fields',
      );
    });

    test('multiple null-contact signatures under the same business are allowed',
        () async {
      final a = await repo.create(Signature(name: 'A', businessId: 1));
      final b = await repo.create(Signature(name: 'B', businessId: 1));
      expect(a, isA<Ok<Signature>>());
      expect(b, isA<Ok<Signature>>());
    });

    test('duplicate non-empty email is rejected (CURRENT global uniqueness)',
        () async {
      final a = await repo.create(Signature(name: 'A', email: 'same@x.com'));
      expect(a, isA<Ok<Signature>>());

      final b = await repo.create(Signature(name: 'B', email: 'same@x.com'));
      // Documents today's behaviour: email is GLOBALLY unique. Step 3B should
      // decide whether this should be per-business or dropped entirely.
      expect(b, isA<Err<Signature>>());
    });

    test('same email under DIFFERENT businesses is also rejected today '
        '(uniqueness is global, not per-business)', () async {
      final a = await repo.create(
        Signature(name: 'A', email: 'dup@x.com', businessId: 1),
      );
      expect(a, isA<Ok<Signature>>());

      final b = await repo.create(
        Signature(name: 'B', email: 'dup@x.com', businessId: 2),
      );
      // The likely real defect: contact info can't be reused across a user's
      // own businesses. Captured here for Step 3B.
      expect(b, isA<Err<Signature>>());
    });
  });
}
