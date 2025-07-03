import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';

import 'client_list_provider.dart';
import 'client_form_repository.dart';
import 'client_form_state.dart';
import 'client_model.dart';

class ClientFormNotifier extends StateNotifier<ClientFormState> {
  final ClientFormRepository _repository;
  final Ref _ref;

  ClientFormNotifier(this._repository, this._ref) : super(ClientFormState());

  //============================================
  // MARK: - Init
  //============================================

  Future<void> init(int? clientId, FormType type) async {
    if (clientId != null && clientId > 0) {
      await getClientById(clientId);
    } else {
      setClient();
    }
  }

  // Set the client to a new client
  Future<void> setClient() async {
    state = state.copyWith(client: Client(name: ''));
  }

  // Get the client by id
  Future<Client?> getClientById(int id) async {
    final client = await _repository.getClientById(id);
    state = state.copyWith(client: client);
    return client;
  }

  /// Set the business value
  Future<void> onSetBusiness(int businessId) async {
    final updatedClient = state.client!.copyWith(businessId: businessId);
    state = state.copyWith(client: updatedClient);
  }

  // Upsert tax
  Future<bool> onUpsert(Client client) async {
    state = state.copyWith(isLoading: true, error: null);
    // Update tax
    if (client.id != null && client.id! > 0) {
      final result = await _repository.updateClient(client);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshClientList();
      return result.success;
    } else {
      // Insert tax
      final result = await _repository.insertClient(client);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshClientList();
      return result.success;
    }
  }

  // Delete tax by id
  Future<bool> deleteClientById(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteClientById(id);
      state = state.copyWith(isLoading: false);

      // Refresh the client list
      _refreshClientList();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Refresh the client list
  void _refreshClientList() {
    _ref.read(clientListProvider.notifier).getClients();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider for ClientFormNotifier
final clientFormProvider =
    StateNotifierProvider<ClientFormNotifier, ClientFormState>(
      (ref) => ClientFormNotifier(ClientFormRepository(), ref),
    );
