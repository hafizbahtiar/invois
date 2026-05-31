import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'signature_form_state.dart';
import 'signature_model.dart';
import 'signature_repository.dart';

class SignatureFormNotifier extends StateNotifier<SignatureFormState> {
  final SignatureRepository _repository;

  SignatureFormNotifier(this._repository) : super(SignatureFormState());

  //============================================
  // MARK: - Init
  //============================================

  Future<void> init(int? signatureId, FormType type) async {
    if (signatureId != null && signatureId > 0) {
      await getSignatureById(signatureId);
    } else {
      setSignature();
    }
  }

  // Get signature by id
  Future<void> getSignatureById(int signatureId) async {
    final signature = await _repository.getSignatureById(signatureId);
    state = state.copyWith(signature: signature);
  }

  // Set the business to a new business
  Future<void> setBusiness(int businessId) async {
    final signature = state.signature!;
    state = state.copyWith(
      signature: signature.copyWith(businessId: businessId),
    );
  }

  // Set a new signature
  Future<void> setSignature() async {
    state = state.copyWith(signature: Signature(name: ''));
  }

  // Upsert signature. List updates reactively (ADR-0003) — no manual refresh.
  Future<bool> onUpsert(Signature signature) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = (signature.id != null && signature.id! > 0)
        ? await _repository.update(signature)
        : await _repository.create(signature);
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

  // Delete signature by id
  Future<bool> deleteSignature(int id) async {
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
}

// Provider for SignatureFormNotifier
final signatureFormProvider =
    StateNotifierProvider<SignatureFormNotifier, SignatureFormState>((ref) {
      return SignatureFormNotifier(ref.watch(signatureRepositoryProvider));
    });
