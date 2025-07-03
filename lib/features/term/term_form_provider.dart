import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/constants/form_type.dart';
import 'term_list_provider.dart';
import 'term_form_repository.dart';
import 'term_form_state.dart';
import 'term_model.dart';

class TermFormNotifier extends StateNotifier<TermFormState> {
  final TermFormRepository _repository;
  final Ref _ref;

  TermFormNotifier(this._repository, this._ref) : super(TermFormState());

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

  // Upsert term
  Future<bool> onUpsert(Term term) async {
    state = state.copyWith(isLoading: true, error: null);
    // Update term
    if (term.id != null && term.id! > 0) {
      final result = await _repository.updateTerm(term);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshTermList();
      return result.success;
    } else {
      // Insert term
      final result = await _repository.insertTerm(term);
      state = state.copyWith(isLoading: false, error: result.message);
      _refreshTermList();
      return result.success;
    }
  }

  // Delete term by id
  Future<bool> deleteTermById(int id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteTerm(id);
      state = state.copyWith(isLoading: false);

      // Refresh the term list
      _refreshTermList();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Refresh the term list
  void _refreshTermList() {
    _ref.read(termListProvider.notifier).getTerms();
  }
}

// Provider for TermFormNotifier
final termFormProvider = StateNotifierProvider<TermFormNotifier, TermFormState>(
  (ref) => TermFormNotifier(TermFormRepository(), ref),
);
