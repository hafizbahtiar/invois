import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:invois/core/database/objectbox_response.dart';

import 'client_model.dart';
import 'client_query.dart';

class ClientLocalSource {
  final Store _store;
  late final Box<Client> _clientBox;

  static final ClientLocalSource _instance = ClientLocalSource._internal();
  factory ClientLocalSource() => _instance;

  ClientLocalSource._internal() : _store = ObjectBoxDatabase.instance {
    _clientBox = _store.box<Client>();
  }

  ClientLocalSource.withDependencies({required Store store}) : _store = store {
    _clientBox = _store.box<Client>();
  }

  // Get all clients
  Future<List<Client>> getClients() async {
    return _clientBox.getAll();
  }

  /// Reactive, filtered client stream (ADR-0003). Emits on every matching write.
  Stream<List<Client>> watchClients(ClientQuery q) {
    Condition<Client>? condition;
    final search = q.search;
    if (search != null && search.isNotEmpty) {
      condition = Client_.name.contains(search, caseSensitive: false);
    }
    if (q.isActive != null) {
      final c = Client_.isActive.equals(q.isActive!);
      condition = condition == null ? c : condition.and(c);
    }
    if (q.isDefault != null) {
      final c = Client_.isDefault.equals(q.isDefault!);
      condition = condition == null ? c : condition.and(c);
    }
    final builder = condition == null
        ? _clientBox.query()
        : _clientBox.query(condition);
    builder.order(Client_.name);
    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }

  // Get client by ID
  Future<Client?> getClientById(int id) async {
    return _clientBox.get(id);
  }

  // Helper to unset isDefault for all other clients with the same businessId (or null for general)
  Future<void> unsetDefaultClientsExcept({
    int? businessId,
    int? exceptId,
  }) async {
    final queryBuilder = _clientBox.query(
      Client_.isDefault.equals(true) &
          ((businessId == null)
              ? Client_.businessId.isNull()
              : Client_.businessId.equals(businessId)),
    );
    final defaults = queryBuilder.build().find();
    for (final client in defaults) {
      if (client.id != exceptId) {
        await updateClientFields(client.id!, isDefault: false);
      }
    }
  }

  // Insert client
  Future<ObjectBoxResponse<Client>> insertClient(Client client) async {
    try {
      if (client.isDefault) {
        await unsetDefaultClientsExcept(
          businessId: client.businessId,
          exceptId: null,
        );
      }
      final result = _clientBox.put(client);
      if (result > 0) {
        return ObjectBoxResponse.success(client);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to insert client');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Update client
  Future<ObjectBoxResponse<Client>> updateClient(Client client) async {
    try {
      if (client.isDefault) {
        await unsetDefaultClientsExcept(
          businessId: client.businessId,
          exceptId: client.id,
        );
      }
      final result = _clientBox.put(client);
      if (result > 0) {
        return ObjectBoxResponse.success(client);
      } else {
        return ObjectBoxResponse.failure(message: 'Failed to update client');
      }
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  // Delete client
  Future<bool> deleteClientById(int id) async {
    return _clientBox.remove(id);
  }

  // Delete client by businessId
  Future<void> deleteClientByBusinessId(int businessId) async {
    final queryBuilder = _clientBox.query(
      Client_.businessId.equals(businessId),
    );
    final clients = queryBuilder.build().find();
    for (final client in clients) {
      await deleteClientById(client.id!);
    }
  }

  // Delete multiple clients
  Future<int> deleteClients(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (_clientBox.remove(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  // Search clients by name
  Future<List<Client>> searchClientsByName(String query) async {
    final queryBuilder = _clientBox.query(
      Client_.name.contains(query, caseSensitive: false),
    );
    final result = queryBuilder.build().find();
    return result;
  }

  // Search clients (combined search)
  Future<List<Client>> searchClients(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    var condition = Client_.name.contains(query, caseSensitive: false);
    if (isDefault != null) {
      condition = condition & Client_.isDefault.equals(isDefault);
    }
    if (isActive != null) {
      condition = condition & Client_.isActive.equals(isActive);
    }
    final builder = _clientBox.query(condition);
    final result = builder.build().find();
    return result;
  }

  // Get active clients
  Future<List<Client>> getActiveClients() async {
    final queryBuilder = _clientBox.query(Client_.isActive.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get inactive clients
  Future<List<Client>> getInactiveClients() async {
    final queryBuilder = _clientBox.query(Client_.isActive.equals(false));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default clients
  Future<List<Client>> getDefaultClients() async {
    final queryBuilder = _clientBox.query(Client_.isDefault.equals(true));
    final result = queryBuilder.build().find();
    return result;
  }

  // Get default taxes by businessId (or general if null)
  Future<List<Client>> getDefaultClientsByBusinessId(int? businessId) async {
    final queryBuilder = _clientBox.query(
      Client_.isDefault.equals(true) &
          ((businessId == null)
              ? Client_.businessId.isNull()
              : Client_.businessId.equals(businessId)),
    );
    return queryBuilder.build().find();
  }

  // Get default client by businessId
  Future<Client?> getDefaultClientByBusinessId(int businessId) async {
    final queryBuilder = _clientBox.query(
      Client_.isDefault.equals(true) & Client_.businessId.equals(businessId),
    );
    return queryBuilder.build().findFirst();
  }

  // Count total clients
  Future<int> countClients() async {
    return _clientBox.count();
  }

  // Update client fields
  Future<bool> updateClientFields(
    int id, {
    String? name,
    String? description,
    String? email,
    String? phone,
    String? company,
    String? website,
    String? streetAddress1,
    String? streetAddress2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    int? businessId,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    final client = _clientBox.get(id);
    if (client == null) return false;

    final updatedClient = client.copyWith(
      name: name,
      description: description,
      email: email,
      phone: phone,
      company: company,
      website: website,
      streetAddress1: streetAddress1,
      streetAddress2: streetAddress2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      businessId: businessId,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );

    final result = _clientBox.put(updatedClient);
    return result > 0;
  }
}
