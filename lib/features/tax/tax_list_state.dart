import 'tax_model.dart';

class TaxListState {
  final List<Tax> taxes;
  final bool isLoading;
  final String? error;

  TaxListState({
    this.taxes = const [],
    this.isLoading = false,
    this.error,
  });

  TaxListState copyWith({
    List<Tax>? taxes,
    bool? isLoading,
    String? error,
  }) {
    return TaxListState(
      taxes: taxes ?? this.taxes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
