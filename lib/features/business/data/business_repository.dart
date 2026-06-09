import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/core/utils/string_utils.dart';

import 'business_local_source.dart';
import 'business_model.dart';
import 'business_query.dart';

final businessLocalSourceProvider = Provider<BusinessLocalSource>(
  (ref) =>
      BusinessLocalSource.withDependencies(store: ref.watch(storeProvider)),
);

final businessRepositoryProvider = Provider<BusinessRepository>(
  (ref) => BusinessRepository(ref.watch(businessLocalSourceProvider)),
);

/// Single business repository (ADR-0002). Replaces BusinessListRepository +
/// BusinessFormRepository.
class BusinessRepository {
  final BusinessLocalSource _local;

  BusinessRepository(this._local);

  Stream<List<Business>> watchBusinesses(BusinessQuery query) => _local
      .watchBusinesses(query)
      .handleError((Object e) => throw mapException(e));

  Future<Business?> getBusinessById(int id) => _local.getBusinessById(id);

  /// The default business, or null if none is marked default.
  Future<Business?> getDefaultBusiness() async {
    final defaults = await _local.getDefaultBusiness();
    return defaults.isEmpty ? null : defaults.first;
  }

  Future<Result<Business>> create(Business business) async {
    try {
      final r = await _local.insertBusiness(_normalizeContact(business));
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to insert business'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<Business>> update(Business business) async {
    try {
      final r = await _local.updateBusiness(_normalizeContact(business));
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update business'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  /// Trim contact fields and store blanks as null, so callers that bypass the
  /// form can't persist empty/whitespace email/phone. (Contact fields are no
  /// longer unique — Step 3C.)
  Business _normalizeContact(Business business) {
    final email = StringUtils.nullIfBlank(business.email);
    final phone = StringUtils.nullIfBlank(business.phone);
    if (email == business.email && phone == business.phone) return business;
    return business.copyWith(
      email: email,
      phone: phone,
      clearEmail: email == null,
      clearPhone: phone == null,
    );
  }

  Future<Result<void>> delete(int id) async {
    try {
      await _local.deleteBusinessById(id);
      return const Ok(null);
    } catch (e) {
      return Err(mapException(e));
    }
  }
}
