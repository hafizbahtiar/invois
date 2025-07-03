import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/features/client/client_model.dart';
import 'client_list_repository.dart';
import 'client_list_state.dart';

class ClientListNotifier extends StateNotifier<ClientListState> {
  final ClientListRepository _repository;

  ClientListNotifier(this._repository) : super(ClientListState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    await getClients();
    state = state.copyWith(isLoading: false);
  }

  Future<void> filter({String? query, bool? isDefault, bool? isActive}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (query != null) {
      await searchClients(query, isDefault: isDefault, isActive: isActive);
    } else {
      if (isDefault != null) {
        await getDefaultClients();
      } else if (isActive == true) {
        await getActiveClients();
      } else if (isActive == false) {
        await getInactiveClients();
      } else {
        await getClients();
      }
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> getClients() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getClients();
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(clients: result.data ?? []);
    }
  }

  Future<void> getActiveClients() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getActiveClients();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(clients: result.data ?? []);
    }
  }

  Future<void> getInactiveClients() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInactiveClients();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(clients: result.data ?? []);
    }
  }

  Future<void> getDefaultClients() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getDefaultClients();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(clients: result.data ?? []);
    }
  }

  Future<Client?> getDefaultClientByBusinessId(int businessId) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getDefaultClientByBusinessId(businessId);
    state = state.copyWith(isLoading: false, error: null);
    return result.data;
  }

  Future<void> searchClientsByName(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchClientsByName(query);
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(clients: result.data ?? []);
    }
  }

  Future<void> searchClients(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchClients(
      query,
      isDefault: isDefault,
      isActive: isActive,
    );
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(clients: result.data ?? []);
    }
  }
}

// Provider for ClientListNotifier
final clientListProvider =
    StateNotifierProvider<ClientListNotifier, ClientListState>(
      (ref) => ClientListNotifier(ClientListRepository()),
    );
