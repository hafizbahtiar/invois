@Tags(['objectbox'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/term/data/term_local_source.dart';
import 'package:invois/features/term/data/term_model.dart';
import 'package:invois/features/term/data/term_query.dart';
import 'package:invois/features/term/data/term_repository.dart';

/// Verifies the data layer is reactive: `watchTerms` (ObjectBox `query.watch`)
/// must emit a fresh list after create / update / delete — this is what makes
/// the list page auto-refresh without pull-to-refresh.
///
/// Requires native `libobjectbox` — tagged `objectbox`, skipped by default:
///   flutter test --tags objectbox --run-skipped
void main() {
  late Store store;
  late TermRepository repo;

  setUp(() {
    store = Store(
      getObjectBoxModel(),
      directory: 'memory:term-reactivity-${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = TermRepository(TermLocalSource.withDependencies(store: store));
  });

  tearDown(() => store.close());

  test('watchTerms emits after create, update, and delete', () async {
    final emissions = <List<Term>>[];
    final sub = repo.watchTerms(const TermQuery()).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20)); // initial emit

    // create -> appears
    final created =
        (await repo.create(Term(name: 'Reactive', content: 'c')) as Ok<Term>)
            .value;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last.any((t) => t.id == created.id), isTrue);

    // update -> reflected
    await repo.update(created.copyWith(name: 'Reactive v2'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      emissions.last.firstWhere((t) => t.id == created.id).name,
      'Reactive v2',
    );

    // delete -> removed
    await repo.delete(created.id!);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last.any((t) => t.id == created.id), isFalse);

    await sub.cancel();
  });
}
