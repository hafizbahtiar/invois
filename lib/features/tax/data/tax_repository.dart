import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';

import 'tax_local_source.dart';
import 'tax_model.dart';
import 'tax_query.dart';

final taxLocalSourceProvider = Provider<TaxLocalSource>(
  (ref) => TaxLocalSource.withDependencies(store: ref.watch(storeProvider)),
);

final taxRepositoryProvider = Provider<TaxRepository>(
  (ref) => TaxRepository(ref.watch(taxLocalSourceProvider)),
);

/// Single tax repository (ADR-0002). Replaces TaxListRepository + TaxFormRepository.
class TaxRepository {
  final TaxLocalSource _local;

  TaxRepository(this._local);

  // Reactive read (ADR-0003).
  Stream<List<Tax>> watchTaxes(TaxQuery query) =>
      _local.watchTaxes(query).handleError((Object e) => throw mapException(e));

  Future<Tax?> getTaxById(int id) => _local.getTaxById(id);

  Future<Result<Tax>> create(Tax tax) async {
    try {
      final r = await _local.insertTax(tax);
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to insert tax'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<Tax>> update(Tax tax) async {
    try {
      final r = await _local.updateTax(tax);
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update tax'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<void>> delete(int id) async {
    try {
      await _local.deleteTaxById(id);
      return const Ok(null);
    } catch (e) {
      return Err(mapException(e));
    }
  }
}
