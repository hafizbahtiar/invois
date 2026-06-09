import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/core/utils/string_utils.dart';

import 'client_local_source.dart';
import 'client_model.dart';
import 'client_query.dart';

final clientLocalSourceProvider = Provider<ClientLocalSource>(
  (ref) => ClientLocalSource.withDependencies(store: ref.watch(storeProvider)),
);

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(ref.watch(clientLocalSourceProvider)),
);

/// Single client repository (ADR-0002). Replaces ClientListRepository +
/// ClientFormRepository.
class ClientRepository {
  final ClientLocalSource _local;

  ClientRepository(this._local);

  Stream<List<Client>> watchClients(ClientQuery query) => _local
      .watchClients(query)
      .handleError((Object e) => throw mapException(e));

  Future<Client?> getClientById(int id) => _local.getClientById(id);

  /// The default client for a business, or null if none.
  Future<Client?> getDefaultClientByBusinessId(int businessId) =>
      _local.getDefaultClientByBusinessId(businessId);

  Future<Result<Client>> create(Client client) async {
    try {
      final r = await _local.insertClient(_normalizeContact(client));
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to insert client'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  Future<Result<Client>> update(Client client) async {
    try {
      final r = await _local.updateClient(_normalizeContact(client));
      final data = r.data;
      return (r.success && data != null)
          ? Ok(data)
          : Err(DatabaseFailure(r.message ?? 'Failed to update client'));
    } catch (e) {
      return Err(mapException(e));
    }
  }

  /// Trim contact fields and store blanks as null, so callers that bypass the
  /// form can't persist empty/whitespace email/phone. (Contact fields are no
  /// longer unique — Step 3C.)
  Client _normalizeContact(Client client) {
    final email = StringUtils.nullIfBlank(client.email);
    final phone = StringUtils.nullIfBlank(client.phone);
    if (email == client.email && phone == client.phone) return client;
    return client.copyWith(
      email: email,
      phone: phone,
      clearEmail: email == null,
      clearPhone: phone == null,
    );
  }

  Future<Result<void>> delete(int id) async {
    try {
      await _local.deleteClientById(id);
      return const Ok(null);
    } catch (e) {
      return Err(mapException(e));
    }
  }
}
