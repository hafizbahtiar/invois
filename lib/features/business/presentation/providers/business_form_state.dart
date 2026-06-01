import '../../business_model.dart';

class BusinessFormState {
  final Business? business;
  final bool isLoading;
  final String? error;

  BusinessFormState({this.business, this.isLoading = false, this.error});

  BusinessFormState copyWith({
    Business? business,
    bool? isLoading,
    String? error,
    bool? isReadOnly,
  }) {
    return BusinessFormState(
      business: business ?? this.business,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
