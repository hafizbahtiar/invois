import 'signature_model.dart';

class SignatureListState {
  final List<Signature> signatures;
  final bool isLoading;
  final String? error;

  SignatureListState({
    this.signatures = const [],
    this.isLoading = false,
    this.error,
  });

  SignatureListState copyWith({
    List<Signature>? signatures,
    bool? isLoading,
    String? error,
  }) {
    return SignatureListState(
      signatures: signatures ?? this.signatures,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
