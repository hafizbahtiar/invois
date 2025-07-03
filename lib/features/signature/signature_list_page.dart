import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_type.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import 'package:invois/features/shared/widgets/simple_list.dart';
import 'signature_model.dart';

import 'signature_list_provider.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(signatureListProvider.notifier).init();
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
      case SignatureListFilter.active:
        await ref
            .read(signatureListProvider.notifier)
            .filter(query: _searchController.text, isActive: true);
        break;
      case SignatureListFilter.inactive:
        await ref
            .read(signatureListProvider.notifier)
            .filter(query: _searchController.text, isActive: false);
        break;
      case SignatureListFilter.defaultStatus:
        await ref
            .read(signatureListProvider.notifier)
            .filter(query: _searchController.text, isDefault: true);
        break;
      default:
        await ref
            .read(signatureListProvider.notifier)
            .filter(query: _searchController.text);
        break;
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(signatureListProvider.notifier).getSignatures();
  }

  Future<void> _onSearchChanged(String value) async {
    if (value.isEmpty) {
      await ref.read(signatureListProvider.notifier).getSignatures();
    } else {
      await ref
          .read(signatureListProvider.notifier)
          .searchSignaturesByName(value);
    }
  }

  void _onFilterSelected(SignatureListFilter filter) {
    setState(() => _selectedFilter = filter);
    _loadSignatures();
  }

  void _onResetFilters() {
    _searchController.clear();
    setState(() => _selectedFilter = SignatureListFilter.all);
    _loadSignatures();
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
    final state = ref.watch(signatureListProvider);

    return Column(
      children: [
        _buildBusinessListHeader(context),
        Expanded(
          child: SimpleList<Signature>(
            items: state.signatures,
            isLoading: state.isLoading,
            errorMessage: state.error,
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
