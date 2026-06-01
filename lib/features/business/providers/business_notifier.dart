import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'business_state.dart';
import '../data/business_model.dart';
import '../data/business_repository.dart';

class BusinessFormNotifier extends StateNotifier<BusinessFormState> {
  final BusinessRepository _repository;

  BusinessFormNotifier(this._repository) : super(BusinessFormState());

  //============================================
  // MARK: - Init
  //============================================

  Future<void> init(int? businessId, FormType type) async {
    if (type == FormType.view) {
      state = state.copyWith(isReadOnly: true);
    } else {
      state = state.copyWith(isReadOnly: false);
    }
    if (businessId != null && businessId > 0) {
      await getBusinessById(businessId);
    } else {
      setBusiness();
    }
  }

  // Get the business by id
  Future<Business?> getBusinessById(int id) async {
    final business = await _repository.getBusinessById(id);
    state = state.copyWith(business: business);
    return business;
  }

  // Set the business to a new business
  Future<void> setBusiness() async {
    state = state.copyWith(business: Business(name: ''), isReadOnly: false);
  }

  // Upsert business. List updates reactively (ADR-0003) — no manual refresh.
  Future<bool> onUpsert(Business business) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = (business.id != null && business.id! > 0)
        ? await _repository.update(business)
        : await _repository.create(business);
    return result.fold(
      (saved) {
        state = state.copyWith(isLoading: false, error: null, business: saved);
        return true;
      },
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  // Delete business by id
  Future<bool> deleteBusiness(int id) async {
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

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider for BusinessFormNotifier
final businessFormProvider =
    StateNotifierProvider<BusinessFormNotifier, BusinessFormState>((ref) {
      return BusinessFormNotifier(ref.watch(businessRepositoryProvider));
    });
