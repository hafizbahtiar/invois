import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_type.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/features/shared/widgets/simple_list.dart';
import '../../data/signature_model.dart';

import '../../providers/signature_providers.dart';
import '../../data/signature_query.dart';

enum SignatureListFilter { all, active, inactive, defaultStatus }

class SignatureListPage extends ConsumerStatefulWidget {
  final ListType listType;

  const SignatureListPage({super.key, this.listType = ListType.list});

  @override
  ConsumerState<SignatureListPage> createState() => _SignatureListPageState();
}

class _SignatureListPageState extends ConsumerState<SignatureListPage> {
  //============================================
  // MARK: - Properties
  //============================================

  SignatureListFilter _selectedFilter = SignatureListFilter.all;
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

  // Maps the selected chip to the signature query; the reactive list rebuilds.
  void _applyFilter() {
    final notifier = ref.read(signatureQueryProvider.notifier);
    switch (_selectedFilter) {
      case SignatureListFilter.active:
        notifier.setFilter(isActive: true);
        break;
      case SignatureListFilter.inactive:
        notifier.setFilter(isActive: false);
        break;
      case SignatureListFilter.defaultStatus:
        notifier.setFilter(isDefault: true);
        break;
      default:
        notifier.setFilter();
        break;
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(signatureListProvider);
  }

  Future<void> _onSearchChanged(String value) async {
    ref.read(signatureQueryProvider.notifier).setSearch(value);
  }

  void _onFilterSelected(SignatureListFilter filter) {
    setState(() => _selectedFilter = filter);
    _applyFilter();
  }

  void _onResetFilters() {
    _searchController.clear();
    setState(() => _selectedFilter = SignatureListFilter.all);
    ref.read(signatureQueryProvider.notifier).reset();
  }

  //============================================
  // MARK: - AppBar
  //============================================

  PreferredSize _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(title: const Text('Signatures'), centerTitle: false),
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

  Widget _buildTrailing(Signature signature) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (signature.isDefault)
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
    final query = ref.watch(signatureQueryProvider);
    final async = ref.watch(signatureListProvider(query));

    return Column(
      children: [
        _buildBusinessListHeader(context),
        Expanded(
          child: SimpleList<Signature>(
            items: async.valueOrNull ?? const [],
            isLoading: async.isLoading,
            errorMessage: async.hasError
                ? (async.error is AppFailure
                      ? (async.error as AppFailure).message
                      : 'Failed to load signatures')
                : null,
            onRefresh: () async => await _onRefresh(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            emptyWidget:
                _selectedFilter != SignatureListFilter.all ||
                    _searchController.text.isNotEmpty
                ? MyNoMatchingState(
                    icon: Icons.draw,
                    title: 'No signatures found',
                    buttonText: 'Add Signature',
                    onPressed: () {},
                  )
                : MyEmptyState(
                    icon: Icons.draw,
                    title: 'No signatures yet',
                    description: 'Start by adding your first signature.',
                  ),
            itemBuilder: (context, signature, index) {
              return MyTile(
                isRounded: true,
                showChevron: true,
                icon: Icons.draw,
                title: signature.name,
                subtitle: _getSubtitle(signature),
                trailing: _buildTrailing(signature),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RoutesName.signatureForm,
                    arguments: {
                      'type': FormType.view.name,
                      'signatureId': signature.id,
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
        RoutesName.signatureForm,
        arguments: {'type': FormType.add.name},
      ),
      tooltip: 'Add Signature',
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

  List<SignatureListFilter> get _filterOptions => [
    SignatureListFilter.all,
    SignatureListFilter.active,
    SignatureListFilter.inactive,
    SignatureListFilter.defaultStatus,
  ];

  String _filterLabel(SignatureListFilter filter) {
    switch (filter) {
      case SignatureListFilter.all:
        return 'All';
      case SignatureListFilter.active:
        return 'Active';
      case SignatureListFilter.inactive:
        return 'Inactive';
      case SignatureListFilter.defaultStatus:
        return 'Default Status';
    }
  }

  String _getSubtitle(Signature signature) {
    final parts = <String>[
      'ID: ${signature.id}',
      if (signature.businessId != null) 'Business: ${signature.businessId}',
      if (signature.isActive == true) 'Active' else 'Inactive',
      if (signature.isDefault == true) 'Default',
    ];
    return parts.join(' · ');
  }
}
