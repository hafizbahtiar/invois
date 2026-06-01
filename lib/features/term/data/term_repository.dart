import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';

import 'term_local_source.dart';
import 'term_model.dart';
import 'term_query.dart';

final termLocalSourceProvider = Provider<TermLocalSource>(
  (ref) => TermLocalSource.withDependencies(store: ref.watch(storeProvider)),
);

final termRepositoryProvider = Provider<TermRepository>(
  (ref) => TermRepository(ref.watch(termLocalSourceProvider)),
);

/// Single term repository (ADR-0002). Replaces TermListRepository + TermFormRepository.
class TermRepository {
  final TermLocalSource _local;

  TermRepository(this._local);

  Stream<List<Term>> watchTerms(TermQuery query) =>
      _local.watchTerms(query).handleError((Object e) => throw mapException(e));

  Future<Term?> getTermById(int id) => _local.getTermById(id);

  Future<Result<Term>> create(Term term) async {
    try {
      final r = await _local.insertTerm(term);
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to insert term'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<Term>> update(Term term) async {
    try {
      final r = await _local.updateTerm(term);
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update term'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<void>> delete(int id) async {
    try {
      await _local.deleteTermById(id);
      return const Ok(null);
    } catch (e) {
      return Err(mapException(e));
    }
  }
}
