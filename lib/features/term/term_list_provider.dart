import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'term_list_repository.dart';
import 'term_list_state.dart';

class TermListNotifier extends StateNotifier<TermListState> {
  final TermListRepository _repository;

  TermListNotifier(this._repository) : super(TermListState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    await getTerms();
    state = state.copyWith(isLoading: false);
  }

  Future<void> filter({String? query, bool? isDefault, bool? isActive}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (query != null) {
      await searchTerms(query, isDefault: isDefault, isActive: isActive);
    } else {
      if (isDefault != null) {
        await getDefaultTerms();
      } else if (isActive == true) {
        await getActiveTerms();
      } else if (isActive == false) {
        await getInactiveTerms();
      } else {
        await getTerms();
      }
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> getTerms() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getTerms();
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(terms: result.data ?? []);
    }
  }

  Future<void> getActiveTerms() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getActiveTerms();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(terms: result.data ?? []);
    }
  }

  Future<void> getInactiveTerms() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInactiveTerms();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(terms: result.data ?? []);
    }
  }

  Future<void> getDefaultTerms() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getDefaultTerms();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(terms: result.data ?? []);
    }
  }

  Future<void> searchTaxesByName(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchTermsByName(query);
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(terms: result.data ?? []);
    }
  }

  Future<void> searchTerms(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchTerms(
      query,
      isDefault: isDefault,
      isActive: isActive,
    );
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(terms: result.data ?? []);
    }
  }
}

// Provider for TermListNotifier
final termListProvider = StateNotifierProvider<TermListNotifier, TermListState>(
  (ref) {
    return TermListNotifier(TermListRepository());
  },
);
