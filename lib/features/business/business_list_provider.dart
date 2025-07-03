import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/features/business/business_model.dart';
import 'business_list_repository.dart';
import 'business_list_state.dart';

class BusinessListNotifier extends StateNotifier<BusinessListState> {
  final BusinessListRepository _repository;

  BusinessListNotifier(this._repository) : super(BusinessListState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    await getBusinesses();
    state = state.copyWith(isLoading: false);
  }

  Future<void> filter({String? query, bool? isDefault, bool? isActive}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (query != null) {
      await searchBusinesses(query, isDefault: isDefault, isActive: isActive);
    } else {
      if (isDefault != null) {
        await getDefaultBusiness();
      } else if (isActive == true) {
        await getActiveBusinesses();
      } else if (isActive == false) {
        await getInactiveBusinesses();
      } else {
        await getBusinesses();
      }
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> getBusinesses() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getAllBusinesses();
    state = state.copyWith(isLoading: false, error: result.message);
    if (result.success) {
      state = state.copyWith(businesses: result.data ?? []);
    }
  }

  Future<void> getActiveBusinesses() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getActiveBusinesses();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(businesses: result.data ?? []);
    }
  }

  Future<void> getInactiveBusinesses() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getInactiveBusinesses();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(businesses: result.data ?? []);
    }
  }

  Future<Business?> getDefaultBusiness() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.getDefaultBusiness();
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(businesses: result.data ?? []);
    }
    return result.data?.firstOrNull;
  }

  Future<void> searchBusinessesByName(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchBusinessesByName(query);
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(businesses: result.data ?? []);
    }
  }

  Future<void> searchBusinesses(
    String query, {
    bool? isDefault,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.searchBusinesses(
      query,
      isDefault: isDefault,
      isActive: isActive,
    );
    state = state.copyWith(isLoading: false, error: null);
    if (result.success) {
      state = state.copyWith(businesses: result.data ?? []);
    }
  }
}

// Provider for BusinessFormNotifier
final businessListProvider =
    StateNotifierProvider<BusinessListNotifier, BusinessListState>((ref) {
      return BusinessListNotifier(BusinessListRepository());
    });
