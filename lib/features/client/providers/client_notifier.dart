import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';

import 'client_state.dart';
import '../data/client_model.dart';
import '../data/client_repository.dart';

class ClientFormNotifier extends StateNotifier<ClientFormState> {
  final ClientRepository _repository;

  ClientFormNotifier(this._repository) : super(ClientFormState());

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

  // Upsert client. List updates reactively (ADR-0003) — no manual refresh.
  Future<bool> onUpsert(Client client) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = (client.id != null && client.id! > 0)
        ? await _repository.update(client)
        : await _repository.create(client);
    return result.fold(
      (_) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
      },
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  // Delete client by id
  Future<bool> deleteClientById(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.delete(id);
    return result.fold(
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider for ClientFormNotifier
final clientFormProvider =
    StateNotifierProvider<ClientFormNotifier, ClientFormState>(
      (ref) => ClientFormNotifier(ref.watch(clientRepositoryProvider)),
    );
