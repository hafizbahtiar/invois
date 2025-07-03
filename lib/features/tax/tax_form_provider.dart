import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'tax_list_provider.dart';
import 'tax_form_repository.dart';
import 'tax_form_state.dart';
import 'tax_model.dart';

class TaxFormNotifier extends StateNotifier<TaxFormState> {
  final TaxFormRepository _repository;
  final Ref _ref;

  TaxFormNotifier(this._repository, this._ref) : super(TaxFormState());

  //============================================
  // MARK: - Init
  //============================================

  Future<void> init(int? taxId, FormType type) async {
    if (taxId != null && taxId > 0) {
      await getTaxById(taxId);
    } else {
      setTax();
    }
  }

  // Set the tax to a new tax
  Future<void> setTax() async {
    state = state.copyWith(tax: Tax(name: ''));
  }

  // Get the tax by id
  Future<void> getTaxById(int id) async {
    final tax = await _repository.getTaxById(id);
    state = state.copyWith(tax: tax);
  }

  /// Set the business value
  Future<void> setBusiness(int businessId) async {
    final updatedTax = state.tax!.copyWith(businessId: businessId);
    state = state.copyWith(tax: updatedTax);
  }

  // Upsert tax
  Future<bool> onUpsert(Tax tax) async {
    state = state.copyWith(isLoading: true, error: null);
    // Update tax
    if (tax.id != null && tax.id! > 0) {
      final result = await _repository.updateTax(tax);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshTaxList();
      return result.success;
    } else {
      // Insert tax
      final result = await _repository.insertTax(tax);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshTaxList();
      return result.success;
    }
  }

  // Delete tax by id
  Future<bool> deleteTaxById(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteTax(id);
      state = state.copyWith(isLoading: false);

      // Refresh the tax list
      _refreshTaxList();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Refresh the tax list
  void _refreshTaxList() {
    _ref.read(taxListProvider.notifier).getTaxes();
  }
}

// Provider for TaxFormNotifier
final taxFormProvider = StateNotifierProvider<TaxFormNotifier, TaxFormState>(
  (ref) => TaxFormNotifier(TaxFormRepository(), ref),
);
