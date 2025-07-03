import 'package:invois/core/database/objectbox_response.dart';

import 'client_local_source.dart';
import 'client_model.dart';

class ClientListRepository {
  final ClientLocalSource _localSource;

  // Singleton pattern
  static final ClientListRepository _instance =
      ClientListRepository._internal();
  factory ClientListRepository() => _instance;

  ClientListRepository._internal() : _localSource = ClientLocalSource();

  // Constructor for dependency injection (useful for testing)
  ClientListRepository.withDependencies({
    required ClientLocalSource localService,
  }) : _localSource = localService;

  Future<ObjectBoxResponse<List<Client>>> getClients() async {
    try {
      final result = await _localSource.getClients();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Client>>> searchClients(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    try {
      final result = await _localSource.searchClients(
        query,
        isDefault: isDefault,
        isActive: isActive,
      );
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Client>>> searchClientsByName(
    String query,
  ) async {
    try {
      final result = await _localSource.searchClientsByName(query);
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Client>>> getActiveClients() async {
    try {
      final result = await _localSource.getActiveClients();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Client>>> getInactiveClients() async {
    try {
      final result = await _localSource.getInactiveClients();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<List<Client>>> getDefaultClients() async {
    try {
      final result = await _localSource.getDefaultClients();
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<ObjectBoxResponse<Client?>> getDefaultClientByBusinessId(
    int businessId,
  ) async {
    try {
      final result = await _localSource.getDefaultClientByBusinessId(
        businessId,
      );
      return ObjectBoxResponse.success(result);
    } on Exception catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    } on Error catch (e) {
      return ObjectBoxResponse.failure(message: e.toString());
    }
  }

  Future<int> countClients() async {
    return await _localSource.countClients();
  }
}
