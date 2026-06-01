import '../data/client_model.dart';

class ClientFormState {
  final Client? client;
  final bool isLoading;
  final String? error;

  ClientFormState({this.client, this.isLoading = false, this.error});

  ClientFormState copyWith({Client? client, bool? isLoading, String? error}) {
    return ClientFormState(
      client: client ?? this.client,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
