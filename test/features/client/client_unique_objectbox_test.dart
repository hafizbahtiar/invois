@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/client/data/client_local_source.dart';
import 'package:invois/features/client/data/client_model.dart';
import 'package:invois/features/client/data/client_repository.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';

/// Step 3C (P1-004): Client email is a contact field, no longer DB-unique.
/// The repository normalises blank contact values to null.
///
/// Requires native `libobjectbox` — tagged `objectbox`, skipped by default:
///   flutter test --tags objectbox --run-skipped
void main() {
  late Store store;
  late ClientRepository repo;

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory:
          'memory:client-unique-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = ClientRepository(ClientLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  group('Client contact fields are not unique (Step 3C)', () {
    test('two clients with the same email are allowed', () async {
      expect(
        await repo.create(Client(name: 'A', email: 'same@x.com')),
        isA<Ok<Client>>(),
      );
      expect(
        await repo.create(Client(name: 'B', email: 'same@x.com')),
        isA<Ok<Client>>(),
      );
    });

    test('same email across different businesses is allowed', () async {
      expect(
        await repo.create(Client(name: 'A', email: 'dup@x.com', businessId: 1)),
        isA<Ok<Client>>(),
      );
      expect(
        await repo.create(Client(name: 'B', email: 'dup@x.com', businessId: 2)),
        isA<Ok<Client>>(),
      );
    });
  });

  group('Client repository normalises contact fields (Step 3C)', () {
    test('blank email/phone are stored as null', () async {
      final saved =
          (await repo.create(Client(name: 'A', email: '   ', phone: ''))
                  as Ok<Client>)
              .value;
      final fetched = await repo.getClientById(saved.id!);
      expect(fetched?.email, isNull);
      expect(fetched?.phone, isNull);
    });

    test('surrounding whitespace is trimmed', () async {
      final saved =
          (await repo.create(Client(name: 'A', email: '  c@d.com  '))
                  as Ok<Client>)
              .value;
      final fetched = await repo.getClientById(saved.id!);
      expect(fetched?.email, 'c@d.com');
    });
  });

  group('Client delete safety', () {
    test('delete is blocked while invoices reference the client', () async {
      final saved =
          (await repo.create(Client(name: 'Referenced Client')) as Ok<Client>)
              .value;
      store.box<Invoice>().put(
        Invoice(
          invoiceNumber: 'INV-CLIENT-REF',
          clientId: saved.id,
          issueDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 1, 31),
        ),
      );

      final result = await repo.delete(saved.id!);

      expect(result, isA<Err<void>>());
      expect(result.failureOrNull?.message, contains('existing invoices'));
      expect(await repo.getClientById(saved.id!), isNotNull);
    });
  });
}
