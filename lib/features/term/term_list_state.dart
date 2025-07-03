import 'term_model.dart';

class TermListState {
  final List<Term> terms;
  final bool isLoading;
  final String? error;

  TermListState({
    this.terms = const [],
    this.isLoading = false,
    this.error,
  });

  TermListState copyWith({
    List<Term>? terms,
    bool? isLoading,
    String? error,
  }) {
    return TermListState(
      terms: terms ?? this.terms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
