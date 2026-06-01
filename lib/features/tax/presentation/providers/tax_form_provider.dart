import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'tax_form_state.dart';
import '../../tax_model.dart';
import '../../tax_repository.dart';

class TaxFormNotifier extends StateNotifier<TaxFormState> {
  final TaxRepository _repository;

  TaxFormNotifier(this._repository) : super(TaxFormState());

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

  // Upsert tax. List updates reactively (ADR-0003) — no manual refresh.
  Future<bool> onUpsert(Tax tax) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = (tax.id != null && tax.id! > 0)
        ? await _repository.update(tax)
        : await _repository.create(tax);
    return result.fold(
      (_) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
      },
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  // Delete tax by id
  Future<bool> deleteTaxById(int id) async {
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

// Provider for TaxFormNotifier
final taxFormProvider = StateNotifierProvider<TaxFormNotifier, TaxFormState>(
  (ref) => TaxFormNotifier(ref.watch(taxRepositoryProvider)),
);
