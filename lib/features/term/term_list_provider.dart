import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'term_model.dart';
import 'term_query_provider.dart';
import 'term_repository.dart';

/// Reactive term list (ADR-0003), parameterized by [TermQuery].
///
/// - Term list page: `ref.watch(termListProvider(ref.watch(termQueryProvider)))`.
/// - Invoice form: `ref.watch(termListProvider(const TermQuery(isActive: true)))`.
final termListProvider = StreamProvider.autoDispose
    .family<List<Term>, TermQuery>((ref, query) {
      return ref.watch(termRepositoryProvider).watchTerms(query);
    });
