@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/signature/data/signature_local_source.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_repository.dart';

/// Step 3B (P1-004): Signature email/phone are contact fields, no longer
/// DB-unique. Multiple signatures may share contact info (across or within
/// businesses), and contactless signatures are allowed. The repository also
/// normalises blank contact values to null.
///
/// Requires the native `libobjectbox` library — tagged `objectbox` and skipped
/// by default; run with:
///   flutter test --tags objectbox --run-skipped
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

  group('Signature contact fields are not unique (Step 3B)', () {
    test('two signatures with null email AND null phone are allowed', () async {
      expect(
        await repo.create(Signature(name: 'Owner A')),
        isA<Ok<Signature>>(),
      );
      expect(
        await repo.create(Signature(name: 'Owner B')),
        isA<Ok<Signature>>(),
      );
    });

    test('same email within the same business is allowed', () async {
      expect(
        await repo.create(
          Signature(name: 'A', email: 'x@x.com', businessId: 1),
        ),
        isA<Ok<Signature>>(),
      );
      expect(
        await repo.create(
          Signature(name: 'B', email: 'x@x.com', businessId: 1),
        ),
        isA<Ok<Signature>>(),
      );
    });

    test('same email across different businesses is allowed', () async {
      expect(
        await repo.create(
          Signature(name: 'A', email: 'dup@x.com', businessId: 1),
        ),
        isA<Ok<Signature>>(),
      );
      expect(
        await repo.create(
          Signature(name: 'B', email: 'dup@x.com', businessId: 2),
        ),
        isA<Ok<Signature>>(),
      );
    });

    test('same phone across different businesses is allowed', () async {
      expect(
        await repo.create(Signature(name: 'A', phone: '0123', businessId: 1)),
        isA<Ok<Signature>>(),
      );
      expect(
        await repo.create(Signature(name: 'B', phone: '0123', businessId: 2)),
        isA<Ok<Signature>>(),
      );
    });
  });

  group('Signature repository normalises contact fields (Step 3B)', () {
    test('blank email/phone are stored as null', () async {
      final created = await repo.create(
        Signature(name: 'A', email: '   ', phone: ''),
      );
      final saved = (created as Ok<Signature>).value;
      final fetched = await repo.getSignatureById(saved.id!);
      expect(fetched?.email, isNull);
      expect(fetched?.phone, isNull);
    });

    test('surrounding whitespace is trimmed', () async {
      final created = await repo.create(
        Signature(name: 'A', email: '  a@b.com  ', phone: '  0123  '),
      );
      final saved = (created as Ok<Signature>).value;
      final fetched = await repo.getSignatureById(saved.id!);
      expect(fetched?.email, 'a@b.com');
      expect(fetched?.phone, '0123');
    });
  });
}
