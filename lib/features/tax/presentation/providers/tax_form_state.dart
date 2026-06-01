import '../../tax_model.dart';

class TaxFormState {
  final Tax? tax;
  final bool isLoading;
  final String? error;

  TaxFormState({this.tax, this.isLoading = false, this.error});

  TaxFormState copyWith({Tax? tax, bool? isLoading, String? error}) {
    return TaxFormState(
      tax: tax ?? this.tax,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
