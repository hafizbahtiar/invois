import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tax_model.dart';
import 'tax_query_provider.dart';
import 'tax_repository.dart';

/// Reactive tax list (ADR-0003), parameterized by [TaxQuery].
///
/// - Tax list page: `ref.watch(taxListProvider(ref.watch(taxQueryProvider)))`.
/// - Invoice form: `ref.watch(taxListProvider(const TaxQuery(isActive: true)))`.
final taxListProvider = StreamProvider.autoDispose.family<List<Tax>, TaxQuery>((
  ref,
  query,
) {
  return ref.watch(taxRepositoryProvider).watchTaxes(query);
});
