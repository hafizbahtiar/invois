@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/business/data/business_local_source.dart';
import 'package:invois/features/business/data/business_model.dart';
import 'package:invois/features/business/data/business_repository.dart';

/// Step 3C (P1-004): Business email/phone are contact fields, no longer
/// DB-unique. Business `name` remains unique (identity). The repository
/// normalises blank contact values to null.
///
/// Requires native `libobjectbox` — tagged `objectbox`, skipped by default:
///   flutter test --tags objectbox --run-skipped
void main() {
  late Store store;
  late BusinessRepository repo;

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:biz-unique-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = BusinessRepository(
      BusinessLocalSource.withDependencies(store: store),
    );
  });

  tearDown(() => store.close());

  group('Business contact fields are not unique (Step 3C)', () {
    test('two businesses with the same email are allowed', () async {
      expect(
        await repo.create(Business(name: 'Biz A', email: 'same@x.com')),
        isA<Ok<Business>>(),
      );
      expect(
        await repo.create(Business(name: 'Biz B', email: 'same@x.com')),
        isA<Ok<Business>>(),
      );
    });

    test('two businesses with the same phone are allowed', () async {
      expect(
        await repo.create(Business(name: 'Biz C', phone: '0123')),
        isA<Ok<Business>>(),
      );
      expect(
        await repo.create(Business(name: 'Biz D', phone: '0123')),
        isA<Ok<Business>>(),
      );
    });

    test('business name stays unique (identity rule unchanged)', () async {
      expect(
        await repo.create(Business(name: 'Dup Name')),
        isA<Ok<Business>>(),
      );
      expect(
        await repo.create(Business(name: 'Dup Name')),
        isA<Err<Business>>(),
      );
    });
  });

  group('Business repository normalises contact fields (Step 3C)', () {
    test('blank email/phone are stored as null', () async {
      final saved =
          (await repo.create(Business(name: 'Biz N', email: '  ', phone: ''))
                  as Ok<Business>)
              .value;
      final fetched = await repo.getBusinessById(saved.id!);
      expect(fetched?.email, isNull);
      expect(fetched?.phone, isNull);
    });

    test('surrounding whitespace is trimmed', () async {
      final saved =
          (await repo.create(
                    Business(
                      name: 'Biz T',
                      email: '  a@b.com  ',
                      phone: '  0123  ',
                    ),
                  )
                  as Ok<Business>)
              .value;
      final fetched = await repo.getBusinessById(saved.id!);
      expect(fetched?.email, 'a@b.com');
      expect(fetched?.phone, '0123');
    });
  });
}
