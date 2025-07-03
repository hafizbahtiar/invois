import 'package:invois/core/database/objectbox_response.dart';

import 'client_local_source.dart';
import 'client_model.dart';

class ClientFormRepository {
  final ClientLocalSource _localSource;

  // Singleton pattern
  static final ClientFormRepository _instance =
      ClientFormRepository._internal();
  factory ClientFormRepository() => _instance;

  ClientFormRepository._internal() : _localSource = ClientLocalSource();

  // Constructor for dependency injection (useful for testing)
  ClientFormRepository.withDependencies({
    required ClientLocalSource localService,
  }) : _localSource = localService;

  Future<List<Client>> getClients() async {
    return await _localSource.getClients();
  }

  Future<Client?> getClientById(int id) async {
    return await _localSource.getClientById(id);
  }

  Future<ObjectBoxResponse<Client>> insertClient(Client client) async {
    // Set creation timestamp
    final clientWithTimestamp = client.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _localSource.insertClient(clientWithTimestamp);
  }

  Future<ObjectBoxResponse<Client>> updateClient(Client client) async {
    // Set update timestamp
    final clientWithTimestamp = client.copyWith(updatedAt: DateTime.now());
    return await _localSource.updateClient(clientWithTimestamp);
  }

  Future<bool> deleteClientById(int id) async {
    return await _localSource.deleteClientById(id);
  }

  Future<int> deleteClients(List<int> ids) async {
    int deletedCount = 0;
    for (int id in ids) {
      if (await deleteClientById(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<List<Client>> searchClientsByName(String query) async {
    return await _localSource.searchClientsByName(query);
  }

  Future<List<Client>> getActiveClients() async {
    return await _localSource.getActiveClients();
  }

  Future<List<Client>> getInactiveClients() async {
    return await _localSource.getInactiveClients();
  }

  Future<int> countClients() async {
    return await _localSource.countClients();
  }

  Future<bool> updateClientFields(
    int id, {
    String? name,
    String? description,
    String? email,
    String? phone,
    String? company,
    String? website,
    int? businessId,
    bool? isActive,
    bool? isDefault,
    DateTime? updatedAt,
  }) async {
    return await _localSource.updateClientFields(
      id,
      name: name,
      description: description,
      email: email,
      phone: phone,
      company: company,
      website: website,
      businessId: businessId,
      isActive: isActive,
      isDefault: isDefault,
      updatedAt: updatedAt,
    );
  }
}
