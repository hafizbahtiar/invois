import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter/search applied to the reactive signature list (drives the list page).
///
/// The invoice form watches
/// `signatureListProvider(const SignatureQuery(isActive: true))` for active
/// signatures.
class SignatureQuery {
  final String? search;
  final bool? isActive;
  final bool? isDefault;

  const SignatureQuery({this.search, this.isActive, this.isDefault});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignatureQuery &&
          other.search == search &&
          other.isActive == isActive &&
          other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(search, isActive, isDefault);
}

class SignatureQueryNotifier extends Notifier<SignatureQuery> {
  @override
  SignatureQuery build() => const SignatureQuery();

  void setSearch(String? term) {
    final cleaned = (term == null || term.trim().isEmpty) ? null : term.trim();
    state = SignatureQuery(
      search: cleaned,
      isActive: state.isActive,
      isDefault: state.isDefault,
    );
  }

  /// Replace the active filter (preserves the current search term).
  void setFilter({bool? isActive, bool? isDefault}) {
    state = SignatureQuery(
      search: state.search,
      isActive: isActive,
      isDefault: isDefault,
    );
  }

  void reset() => state = const SignatureQuery();
}

final signatureQueryProvider =
    NotifierProvider<SignatureQueryNotifier, SignatureQuery>(
      SignatureQueryNotifier.new,
    );
