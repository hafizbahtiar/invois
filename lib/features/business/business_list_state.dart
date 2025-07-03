import 'business_model.dart';

class BusinessListState {
  final List<Business> businesses;
  final bool isLoading;
  final String? error;

  BusinessListState({
    this.businesses = const [],
    this.isLoading = false,
    this.error,
  });

  BusinessListState copyWith({
    List<Business>? businesses,
    bool? isLoading,
    String? error,
  }) {
    return BusinessListState(
      businesses: businesses ?? this.businesses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
