import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter/search applied to the reactive term list (drives the term list page).
///
/// The invoice form watches `termListProvider(const TermQuery(isActive: true))`
/// directly for active terms.
class TermQuery {
  final String? search;
  final bool? isActive;
  final bool? isDefault;

  const TermQuery({this.search, this.isActive, this.isDefault});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TermQuery &&
          other.search == search &&
          other.isActive == isActive &&
          other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(search, isActive, isDefault);
}

class TermQueryNotifier extends Notifier<TermQuery> {
  @override
  TermQuery build() => const TermQuery();

  void setSearch(String? term) {
    final cleaned = (term == null || term.trim().isEmpty) ? null : term.trim();
    state = TermQuery(
      search: cleaned,
      isActive: state.isActive,
      isDefault: state.isDefault,
    );
  }

  /// Replace the active filter (preserves the current search term).
  void setFilter({bool? isActive, bool? isDefault}) {
    state = TermQuery(
      search: state.search,
      isActive: isActive,
      isDefault: isDefault,
    );
  }

  void reset() => state = const TermQuery();
}

final termQueryProvider = NotifierProvider<TermQueryNotifier, TermQuery>(
  TermQueryNotifier.new,
);
