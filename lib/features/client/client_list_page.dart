import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_filter_type.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import 'package:invois/features/shared/widgets/simple_list.dart';

import 'client_list_provider.dart';
import 'client_model.dart';

class ClientListPage extends ConsumerStatefulWidget {
  const ClientListPage({super.key});

  @override
  ConsumerState<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends ConsumerState<ClientListPage> {
  //============================================
  // MARK: - Properties
  //============================================

  ListFilterType _selectedFilter = ListFilterType.all;
  final _searchController = TextEditingController();

  //============================================
  // MARK: - Init
  //============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientListProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //============================================
  // MARK: - Actions
  //============================================

  Future<void> _loadSignatures() async {
    switch (_selectedFilter) {
      case ListFilterType.active:
        await ref
            .read(clientListProvider.notifier)
            .filter(query: _searchController.text, isActive: true);
        break;
      case ListFilterType.inactive:
        await ref
            .read(clientListProvider.notifier)
            .filter(query: _searchController.text, isActive: false);
        break;
      case ListFilterType.defaultStatus:
        await ref
            .read(clientListProvider.notifier)
            .filter(query: _searchController.text, isDefault: true);
        break;
      default:
        await ref
            .read(clientListProvider.notifier)
            .filter(query: _searchController.text);
        break;
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(clientListProvider.notifier).getClients();
  }

  Future<void> _onSearchChanged(String value) async {
    if (value.isEmpty) {
      await ref.read(clientListProvider.notifier).getClients();
    } else {
      await ref.read(clientListProvider.notifier).searchClientsByName(value);
    }
  }

  void _onFilterSelected(ListFilterType filter) {
    setState(() => _selectedFilter = filter);
    _loadSignatures();
  }

  void _onResetFilters() {
    _searchController.clear();
    setState(() => _selectedFilter = ListFilterType.all);
    _loadSignatures();
  }

  //============================================
  // MARK: - AppBar
  //============================================

  PreferredSize _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(title: const Text('Clients'), centerTitle: false),
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  Widget _buildBusinessListHeader(BuildContext context) {
    return MyFilterSection(
      searchController: _searchController,
      searchQuery: _searchController.text,
      onSearchChanged: (value) => _onSearchChanged(value),
      selectedFilter: _selectedFilter,
      onFilterSelected: (filter) => _onFilterSelected(filter),
      onResetFiltersChips: () => _onResetFilters(),
      onResetFiltersSearch: () => _onResetFilters(),
      filterOptions: _filterOptions,
      filterLabelBuilder: (filter) => _filterLabel(filter),
    );
  }

  Widget _buildTrailing(Client client) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (client.isDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Default',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = ref.watch(clientListProvider);

    return Column(
      children: [
        _buildBusinessListHeader(context),
        Expanded(
          child: SimpleList<Client>(
            items: state.clients,
            isLoading: state.isLoading,
            errorMessage: state.error,
            onRefresh: () async => await _onRefresh(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            emptyWidget:
                _selectedFilter != ListFilterType.all ||
                    _searchController.text.isNotEmpty
                ? MyNoMatchingState(
                    icon: Icons.group,
                    title: 'No clients matching your search',
                    buttonText: 'Reset Filters',
                    onPressed: _onResetFilters,
                  )
                : MyEmptyState(
                    icon: Icons.group,
                    title: 'No clients yet',
                    description: 'Start by adding your first client.',
                  ),
            itemBuilder: (context, client, index) {
              return MyTile(
                isRounded: true,
                showChevron: true,
                icon: Icons.person,
                title: client.name,
                subtitle: _getSubtitle(client),
                trailing: _buildTrailing(client),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RoutesName.clientForm,
                    arguments: {
                      'type': FormType.view.name,
                      'clientId': client.id,
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  //============================================
  // MARK: - Floating Action Button
  //============================================

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => Navigator.pushNamed(
        context,
        RoutesName.clientForm,
        arguments: {'type': FormType.add.name},
      ),
      tooltip: 'Add Client',
      child: const Icon(Icons.add),
    );
  }

  //============================================
  // MARK: - Build
  //============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  //============================================
  // MARK: - Helpers
  //============================================

  List<ListFilterType> get _filterOptions => [
    ListFilterType.all,
    ListFilterType.active,
    ListFilterType.inactive,
    ListFilterType.defaultStatus,
  ];

  String _filterLabel(ListFilterType filter) {
    switch (filter) {
      case ListFilterType.all:
        return 'All';
      case ListFilterType.active:
        return 'Active';
      case ListFilterType.inactive:
        return 'Inactive';
      case ListFilterType.defaultStatus:
        return 'Default Status';
    }
  }

  String _getSubtitle(Client client) {
    final parts = <String>[
      'ID: ${client.id}',
      if (client.businessId != null) 'Business: ${client.businessId}',
      if (client.isActive == true) 'Active' else 'Inactive',
      if (client.isDefault == true) 'Default',
    ];
    return parts.join(' · ');
  }
}
