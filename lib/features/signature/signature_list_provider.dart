import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'signature_list_repository.dart';
import 'signature_list_state.dart';

class SignatureListNotifier extends StateNotifier<SignatureListState> {
  final SignatureListRepository _repository;

  SignatureListNotifier(this._repository) : super(SignatureListState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    await getSignatures();
    state = state.copyWith(isLoading: false);
  }

  Future<void> filter({String? query, bool? isDefault, bool? isActive}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (query != null) {
      await searchSignatures(query, isDefault: isDefault, isActive: isActive);
    } else {
      if (isDefault != null) {
        await getDefaultSignatures();
      } else if (isActive == true) {
        await getActiveSignatures();
      } else if (isActive == false) {
        await getInactiveSignatures();
      } else {
        await getSignatures();
      }
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> getSignatures() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getSignatures();
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(signatures: result.data ?? []);
    }
  }

  Future<void> getActiveSignatures() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getActiveSignatures();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(signatures: result.data ?? []);
    }
  }

  Future<void> getInactiveSignatures() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInactiveSignatures();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(signatures: result.data ?? []);
    }
  }

  Future<void> getDefaultSignatures() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getDefaultSignatures();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(signatures: result.data ?? []);
    }
  }

  Future<void> searchSignaturesByName(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchSignaturesByName(query);
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(signatures: result.data ?? []);
    }
  }

  Future<void> searchSignatures(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchSignatures(
      query,
      isDefault: isDefault,
      isActive: isActive,
    );
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(signatures: result.data ?? []);
    }
  }
}

// Provider for SignatureListNotifier
final signatureListProvider =
    StateNotifierProvider<SignatureListNotifier, SignatureListState>((ref) {
      return SignatureListNotifier(SignatureListRepository());
    });
