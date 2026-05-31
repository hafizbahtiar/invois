import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/features/business/business_model.dart';

import 'business_query_provider.dart';
import 'business_repository.dart';

/// Reactive business list (ADR-0003), parameterized by [BusinessQuery].
///
/// - Business list page: `ref.watch(businessListProvider(ref.watch(businessQueryProvider)))`.
/// - Selectors (invoice/tax/term/client/signature forms, filter section):
///   `ref.watch(businessListProvider(const BusinessQuery(isActive: true)))`.
final businessListProvider = StreamProvider.autoDispose
    .family<List<Business>, BusinessQuery>((ref, query) {
      return ref.watch(businessRepositoryProvider).watchBusinesses(query);
    });
