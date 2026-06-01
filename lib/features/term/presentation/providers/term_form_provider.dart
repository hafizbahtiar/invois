import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'term_form_state.dart';
import '../../term_model.dart';
import '../../term_repository.dart';

class TermFormNotifier extends StateNotifier<TermFormState> {
  final TermRepository _repository;

  TermFormNotifier(this._repository) : super(TermFormState());

  //============================================
  // MARK: - Init
  //============================================

  Future<void> init(int? termId, FormType type) async {
    if (termId != null && termId > 0) {
      await getTermById(termId);
    } else {
      setTerm();
    }
  }

  // Set the term to a new term
  Future<void> setTerm() async {
    state = state.copyWith(
      term: Term(name: '', content: ''),
    );
  }

  // Get the term by id
  Future<void> getTermById(int id) async {
    final term = await _repository.getTermById(id);
    state = state.copyWith(term: term);
  }

  /// Set the business value
  Future<void> setBusiness(int businessId) async {
    final updatedTerm = state.term!.copyWith(businessId: businessId);
    state = state.copyWith(term: updatedTerm);
  }

  // Upsert term. List updates reactively (ADR-0003) — no manual refresh.
  Future<bool> onUpsert(Term term) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = (term.id != null && term.id! > 0)
        ? await _repository.update(term)
        : await _repository.create(term);
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

  // Delete term by id
  Future<bool> deleteTermById(int id) async {
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

// Provider for TermFormNotifier
final termFormProvider = StateNotifierProvider<TermFormNotifier, TermFormState>(
  (ref) => TermFormNotifier(ref.watch(termRepositoryProvider)),
);
