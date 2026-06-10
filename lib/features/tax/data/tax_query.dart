import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter/search applied to the reactive tax list (drives the tax list page).
///
/// The invoice form does not use this notifier — it watches
/// `taxListProvider(const TaxQuery(isActive: true))` directly for active taxes.
class TaxQuery {
  final String? search;
  final bool? isActive;
  final bool? isDefault;

  const TaxQuery({this.search, this.isActive, this.isDefault});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxQuery &&
          other.search == search &&
          other.isActive == isActive &&
          other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(search, isActive, isDefault);
}

class TaxQueryNotifier extends Notifier<TaxQuery> {
  @override
  TaxQuery build() => const TaxQuery();

  void setSearch(String? term) {
    final cleaned = (term == null || term.trim().isEmpty) ? null : term.trim();
    state = TaxQuery(
      search: cleaned,
      isActive: state.isActive,
      isDefault: state.isDefault,
    );
  }

  /// Replace the active filter (preserves the current search term).
  void setFilter({bool? isActive, bool? isDefault}) {
    state = TaxQuery(
      search: state.search,
      isActive: isActive,
      isDefault: isDefault,
    );
  }

  void reset() => state = const TaxQuery();
}

final taxQueryProvider = NotifierProvider<TaxQueryNotifier, TaxQuery>(
  TaxQueryNotifier.new,
);
