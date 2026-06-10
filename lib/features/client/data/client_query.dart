import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter/search applied to the reactive client list (drives the list page).
///
/// The invoice form watches `clientListProvider(const ClientQuery(isActive: true))`
/// for active clients.
class ClientQuery {
  final String? search;
  final bool? isActive;
  final bool? isDefault;

  const ClientQuery({this.search, this.isActive, this.isDefault});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientQuery &&
          other.search == search &&
          other.isActive == isActive &&
          other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(search, isActive, isDefault);
}

class ClientQueryNotifier extends Notifier<ClientQuery> {
  @override
  ClientQuery build() => const ClientQuery();

  void setSearch(String? term) {
    final cleaned = (term == null || term.trim().isEmpty) ? null : term.trim();
    state = ClientQuery(
      search: cleaned,
      isActive: state.isActive,
      isDefault: state.isDefault,
    );
  }

  /// Replace the active filter (preserves the current search term).
  void setFilter({bool? isActive, bool? isDefault}) {
    state = ClientQuery(
      search: state.search,
      isActive: isActive,
      isDefault: isDefault,
    );
  }

  void reset() => state = const ClientQuery();
}

final clientQueryProvider = NotifierProvider<ClientQueryNotifier, ClientQuery>(
  ClientQueryNotifier.new,
);
