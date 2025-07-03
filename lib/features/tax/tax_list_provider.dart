import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tax_list_repository.dart';
import 'tax_list_state.dart';

class TaxListNotifier extends StateNotifier<TaxListState> {
  final TaxListRepository _repository;

  TaxListNotifier(this._repository) : super(TaxListState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    await getTaxes();
    state = state.copyWith(isLoading: false);
  }

  Future<void> filter({String? query, bool? isDefault, bool? isActive}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (query != null) {
      await searchTaxes(query, isDefault: isDefault, isActive: isActive);
    } else {
      if (isDefault != null) {
        await getDefaultTaxes();
      } else if (isActive == true) {
        await getActiveTaxes();
      } else if (isActive == false) {
        await getInactiveTaxes();
      } else {
        await getTaxes();
      }
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> getTaxes() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getTaxes();
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(taxes: result.data ?? []);
    }
  }

  Future<void> getActiveTaxes() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getActiveTaxes();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(taxes: result.data ?? []);
    }
  }

  Future<void> getInactiveTaxes() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInactiveTaxes();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(taxes: result.data ?? []);
    }
  }

  Future<void> getDefaultTaxes() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getDefaultTaxes();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(taxes: result.data ?? []);
    }
  }

  Future<void> searchTaxesByName(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchTaxesByName(query);
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(taxes: result.data ?? []);
    }
  }

  Future<void> searchTaxes(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchTaxes(
      query,
      isDefault: isDefault,
      isActive: isActive,
    );
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(taxes: result.data ?? []);
    }
  }
}

// Provider for TaxListNotifier
final taxListProvider = StateNotifierProvider<TaxListNotifier, TaxListState>(
  (ref) => TaxListNotifier(TaxListRepository()),
);
