import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/database/objectbox_response.dart';
import 'business_list_provider.dart';
import 'business_form_repository.dart';
import 'business_form_state.dart';
import 'business_model.dart';

class BusinessFormNotifier extends StateNotifier<BusinessFormState> {
  final BusinessFormRepository _repository;
  final Ref _ref;

  BusinessFormNotifier(this._repository, this._ref)
    : super(BusinessFormState());

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
    state = state.copyWith(
      business: Business(name: ''),
      isReadOnly: false,
    );
  }

  // Upsert business
  Future<bool> onUpsert(Business business) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      ObjectBoxResponse<Business> result;
      if (business.id != null && business.id! > 0) {
        // Update
        result = await _repository.updateBusiness(business);
      } else {
        // Insert
        result = await _repository.insertBusiness(business);
      }

      state = state.copyWith(
        isLoading: false,
        error: result.success ? null : result.message,
        business: result.data,
      );

      if (result.success) {
        _refreshBusinessList();
      }

      return result.success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Delete business by id
  Future<bool> deleteBusiness(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.deleteBusiness(id);
      state = state.copyWith(isLoading: false, error: result.message);

      // Refresh the business list
      _refreshBusinessList();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Refresh the business list
  void _refreshBusinessList() {
    _ref.read(businessListProvider.notifier).getBusinesses();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider for BusinessFormNotifier
final businessFormProvider =
    StateNotifierProvider<BusinessFormNotifier, BusinessFormState>((ref) {
      return BusinessFormNotifier(BusinessFormRepository(), ref);
    });
