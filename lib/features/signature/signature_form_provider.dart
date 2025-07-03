import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'signature_list_provider.dart';
import 'signature_form_repository.dart';
import 'signature_form_state.dart';
import 'signature_model.dart';

class SignatureFormNotifier extends StateNotifier<SignatureFormState> {
  final SignatureFormRepository _repository;
  final Ref _ref;

  SignatureFormNotifier(this._repository, this._ref)
    : super(SignatureFormState());

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

  // Set the business to a new business
  Future<void> setSignature() async {
    state = state.copyWith(signature: Signature(name: ''));
  }

  // Upsert business
  Future<bool> onUpsert(Signature signature) async {
    state = state.copyWith(isLoading: true, error: null);

    // Update business
    if (signature.id != null && signature.id! > 0) {
      final result = await _repository.updateSignature(signature);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshSignatureList();
      return result.success;
    } else {
      // Insert business
      final result = await _repository.insertSignature(signature);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshSignatureList();
      return result.success;
    }
  }

  // Delete signature by id
  Future<bool> deleteSignature(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteSignature(id);
      state = state.copyWith(isLoading: false);

      // Refresh the signature list
      _refreshSignatureList();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Refresh the signature list
  void _refreshSignatureList() {
    _ref.read(signatureListProvider.notifier).getSignatures();
  }
}

// Provider for BusinessFormNotifier
final signatureFormProvider =
    StateNotifierProvider<SignatureFormNotifier, SignatureFormState>((ref) {
      return SignatureFormNotifier(SignatureFormRepository(), ref);
    });
