import '../data/signature_model.dart';

class SignatureFormState {
  final Signature? signature;
  final bool isLoading;
  final String? error;

  SignatureFormState({this.signature, this.isLoading = false, this.error});

  SignatureFormState copyWith({
    Signature? signature,
    bool? isLoading,
    String? error,
  }) {
    return SignatureFormState(
      signature: signature ?? this.signature,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
