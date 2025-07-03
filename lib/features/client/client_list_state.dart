import 'client_model.dart';

class ClientListState {
  final List<Client> clients;
  final bool isLoading;
  final String? error;

  ClientListState({
    this.clients = const [],
    this.isLoading = false,
    this.error,
  });

  ClientListState copyWith({
    List<Client>? clients,
    bool? isLoading,
    String? error,
  }) {
    return ClientListState(
      clients: clients ?? this.clients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
