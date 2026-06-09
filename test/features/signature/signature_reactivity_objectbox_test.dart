@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/signature/data/signature_local_source.dart';
import 'package:invois/features/signature/data/signature_model.dart';
import 'package:invois/features/signature/data/signature_query.dart';
import 'package:invois/features/signature/data/signature_repository.dart';

/// Verifies `watchSignatures` (ObjectBox `query.watch`) emits a fresh list after
/// create / update / delete / set-default — the data-layer reactivity behind the
/// signature list auto-refresh.
///
/// Requires native `libobjectbox` — tagged `objectbox`, skipped by default:
///   flutter test --tags objectbox --run-skipped
void main() {
  late Store store;
  late SignatureRepository repo;

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:sig-reactivity-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = SignatureRepository(
      SignatureLocalSource.withDependencies(store: store),
    );
  });

  tearDown(() => store.close());

  test('watchSignatures emits after create, update, and delete', () async {
    final emissions = <List<Signature>>[];
    final sub = repo.watchSignatures(const SignatureQuery()).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final created =
        (await repo.create(Signature(name: 'Owner')) as Ok<Signature>).value;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last.any((s) => s.id == created.id), isTrue);

    await repo.update(created.copyWith(name: 'Owner v2'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      emissions.last.firstWhere((s) => s.id == created.id).name,
      'Owner v2',
    );

    await repo.delete(created.id!);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last.any((s) => s.id == created.id), isFalse);

    await sub.cancel();
  });

  test('watchSignatures reflects set-default (only one default remains)', () async {
    final emissions = <List<Signature>>[];
    final sub = repo
        .watchSignatures(const SignatureQuery())
        .listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final a =
        (await repo.create(Signature(name: 'A', isDefault: true)) as Ok<Signature>)
            .value;
    final b =
        (await repo.create(Signature(name: 'B')) as Ok<Signature>).value;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Promote B to default; local source unsets A's default.
    await repo.update(b.copyWith(isDefault: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final defaults = emissions.last.where((s) => s.isDefault).toList();
    expect(defaults.length, 1);
    expect(defaults.single.id, b.id);
    expect(emissions.last.firstWhere((s) => s.id == a.id).isDefault, isFalse);

    await sub.cancel();
  });
}
