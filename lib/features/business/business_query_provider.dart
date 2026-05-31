import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter/search applied to the reactive business list (drives the list page).
///
/// Selectors elsewhere (invoice/tax/term/client/signature forms, filter section)
/// watch `businessListProvider(const BusinessQuery(isActive: true))` directly.
class BusinessQuery {
  final String? search;
  final bool? isActive;
  final bool? isDefault;

  const BusinessQuery({this.search, this.isActive, this.isDefault});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessQuery &&
          other.search == search &&
          other.isActive == isActive &&
          other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(search, isActive, isDefault);
}

class BusinessQueryNotifier extends Notifier<BusinessQuery> {
  @override
  BusinessQuery build() => const BusinessQuery();

  void setSearch(String? term) {
    final cleaned = (term == null || term.trim().isEmpty) ? null : term.trim();
    state = BusinessQuery(
      search: cleaned,
      isActive: state.isActive,
      isDefault: state.isDefault,
    );
  }

  /// Replace the active filter (preserves the current search term).
  void setFilter({bool? isActive, bool? isDefault}) {
    state = BusinessQuery(
      search: state.search,
      isActive: isActive,
      isDefault: isDefault,
    );
  }

  void reset() => state = const BusinessQuery();
}

final businessQueryProvider =
    NotifierProvider<BusinessQueryNotifier, BusinessQuery>(
      BusinessQueryNotifier.new,
    );
