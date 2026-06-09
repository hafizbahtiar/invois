import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_filter_type.dart';
import 'package:invois/core/constants/list_type.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/features/shared/widgets/simple_list.dart';
import '../../data/term_model.dart';

import '../../providers/term_providers.dart';
import '../../data/term_query.dart';

class TermListPage extends ConsumerStatefulWidget {
  final ListType listType;

  const TermListPage({super.key, this.listType = ListType.list});

  @override
  ConsumerState<TermListPage> createState() => _TermListPageState();
}

class _TermListPageState extends ConsumerState<TermListPage> {
  //============================================
  // MARK: - Properties
  //============================================

  ListFilterType _selectedFilter = ListFilterType.all;
  final _searchController = TextEditingController();

  //============================================
  // MARK: - Init
  //============================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //============================================
  // MARK: - Actions
  //============================================

  // Maps the selected chip to the term query; the reactive list rebuilds.
  void _applyFilter() {
    final notifier = ref.read(termQueryProvider.notifier);
    switch (_selectedFilter) {
      case ListFilterType.active:
        notifier.setFilter(isActive: true);
        break;
      case ListFilterType.inactive:
        notifier.setFilter(isActive: false);
        break;
      case ListFilterType.defaultStatus:
        notifier.setFilter(isDefault: true);
        break;
      default:
        notifier.setFilter();
        break;
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(termListProvider);
  }

  Future<void> _onSearchChanged(String value) async {
    ref.read(termQueryProvider.notifier).setSearch(value);
  }

  void _onFilterSelected(ListFilterType filter) {
    setState(() => _selectedFilter = filter);
    _applyFilter();
  }

  void _onResetFilters() {
    _searchController.clear();
    setState(() => _selectedFilter = ListFilterType.all);
    ref.read(termQueryProvider.notifier).reset();
  }

  //============================================
  // MARK: - AppBar
  //============================================

  PreferredSize _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(title: const Text('Terms'), centerTitle: false),
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

  Widget _buildTrailing(Term term) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (term.isDefault)
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
    final query = ref.watch(termQueryProvider);
    final async = ref.watch(termListProvider(query));

    return Column(
      children: [
        _buildBusinessListHeader(context),
        Expanded(
          child: SimpleList<Term>(
            items: async.value ?? const [],
            isLoading: async.isLoading,
            errorMessage: async.hasError
                ? (async.error is AppFailure
                      ? (async.error as AppFailure).message
                      : 'Failed to load terms')
                : null,
            onRefresh: () async => await _onRefresh(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            emptyWidget:
                _selectedFilter != ListFilterType.all ||
                    _searchController.text.isNotEmpty
                ? MyNoMatchingState(
                    icon: Icons.description,
                    title: 'No terms & conditions matching your search',
                    buttonText: 'Reset Filters',
                    onPressed: _onResetFilters,
                  )
                : MyEmptyState(
                    icon: Icons.description,
                    title: 'No terms & conditions yet',
                    description: 'Start by adding your first term & condition.',
                  ),
            itemBuilder: (context, term, index) {
              return MyTile(
                isRounded: true,
                showChevron: true,
                icon: Icons.description,
                title: term.name,
                subtitle: _getSubtitle(term),
                trailing: _buildTrailing(term),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RoutesName.termForm,
                    arguments: {'type': FormType.view.name, 'termId': term.id},
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
        RoutesName.termForm,
        arguments: {'type': FormType.add.name},
      ),
      tooltip: 'Add Term',
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

  String _getSubtitle(Term term) {
    final parts = <String>[
      'ID: ${term.id}',
      if (term.businessId != null) 'Business: ${term.businessId}',
      if (term.isActive == true) 'Active' else 'Inactive',
      if (term.isDefault == true) 'Default',
    ];
    return parts.join(' · ');
  }
}
