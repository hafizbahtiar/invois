import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tax_model.dart';
import '../data/tax_query.dart';
import '../data/tax_repository.dart';

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
