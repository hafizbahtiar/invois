import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/features/client/data/client_model.dart';

import '../data/client_query.dart';
import '../data/client_repository.dart';

/// Reactive client list (ADR-0003), parameterized by [ClientQuery].
///
/// - Client list page: `ref.watch(clientListProvider(ref.watch(clientQueryProvider)))`.
/// - Invoice form: `ref.watch(clientListProvider(const ClientQuery(isActive: true)))`.
final clientListProvider = StreamProvider.autoDispose
    .family<List<Client>, ClientQuery>((ref, query) {
      return ref.watch(clientRepositoryProvider).watchClients(query);
    });
