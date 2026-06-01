import '../data/term_model.dart';

class TermFormState {
  final Term? term;
  final bool isLoading;
  final String? error;

  TermFormState({
    this.term,
    this.isLoading = false,
    this.error,
  });

  TermFormState copyWith({
    Term? term,
    bool? isLoading,
    String? error,
  }) {
    return TermFormState(
      term: term ?? this.term,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
