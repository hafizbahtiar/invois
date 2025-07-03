import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/features/business/business_module.dart';

class MyFilterSection<T> extends ConsumerWidget {
  final String searchQuery;
  final String? hintText;
  final bool showBusinessFilter;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final T selectedFilter;
  final ValueChanged<T> onFilterSelected;
  final VoidCallback onResetFiltersChips;
  final VoidCallback onResetFiltersSearch;
  final int? selectedBusinessId;
  final VoidCallback? onBusinessIdCleared;
  final List<T> filterOptions;
  final String Function(T) filterLabelBuilder;
  final VoidCallback? showFilterDialog;

  // Private constructor for internal use
  const MyFilterSection._({
    super.key,
    required this.searchQuery,
    this.hintText,
    required this.showBusinessFilter,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onResetFiltersChips,
    required this.onResetFiltersSearch,
    this.selectedBusinessId,
    this.onBusinessIdCleared,
    required this.filterOptions,
    required this.filterLabelBuilder,
    this.showFilterDialog,
  });

  // Factory constructor for basic filter section without business filter
  factory MyFilterSection({
    Key? key,
    required String searchQuery,
    String? hintText,
    required TextEditingController searchController,
    required ValueChanged<String> onSearchChanged,
    required T selectedFilter,
    required ValueChanged<T> onFilterSelected,
    required VoidCallback onResetFiltersChips,
    required VoidCallback onResetFiltersSearch,
    required List<T> filterOptions,
    required String Function(T) filterLabelBuilder,
  }) {
    return MyFilterSection._(
      key: key,
      searchQuery: searchQuery,
      hintText: hintText,
      showBusinessFilter: false,
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      selectedFilter: selectedFilter,
      onFilterSelected: onFilterSelected,
      onResetFiltersChips: onResetFiltersChips,
      onResetFiltersSearch: onResetFiltersSearch,
      filterOptions: filterOptions,
      filterLabelBuilder: filterLabelBuilder,
    );
  }

  // Factory constructor for filter section with business filter
  factory MyFilterSection.withBusinessFilter({
    Key? key,
    required String searchQuery,
    String? hintText,
    required TextEditingController searchController,
    required ValueChanged<String> onSearchChanged,
    required T selectedFilter,
    required ValueChanged<T> onFilterSelected,
    required VoidCallback onResetFiltersChips,
    required VoidCallback onResetFiltersSearch,
    int? selectedBusinessId,
    VoidCallback? onBusinessIdCleared,
    required List<T> filterOptions,
    required String Function(T) filterLabelBuilder,
    required VoidCallback showFilterDialog,
  }) {
    return MyFilterSection._(
      key: key,
      searchQuery: searchQuery,
      hintText: hintText,
      showBusinessFilter: true,
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      selectedFilter: selectedFilter,
      onFilterSelected: onFilterSelected,
      onResetFiltersChips: onResetFiltersChips,
      onResetFiltersSearch: onResetFiltersSearch,
      selectedBusinessId: selectedBusinessId,
      onBusinessIdCleared: onBusinessIdCleared,
      filterOptions: filterOptions,
      filterLabelBuilder: filterLabelBuilder,
      showFilterDialog: showFilterDialog,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [_buildSearchBar(context), _buildFilterChips(context, ref)],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: hintText ?? 'Search',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onResetFiltersSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: onSearchChanged,
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref) {
    final state = ref.watch(businessListProvider);
    final businesses = state.businesses;

    // Find the selected business name
    String? selectedBusinessName;
    if (selectedBusinessId != null) {
      try {
        selectedBusinessName = businesses
            .firstWhere((business) => business.id == selectedBusinessId)
            .name;
      } catch (e) {
        selectedBusinessName = 'Unknown';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...filterOptions.map((filter) {
              final isSelected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filterLabelBuilder(filter)),
                  selected: isSelected,
                  onSelected: (selected) {
                    onFilterSelected(filter);
                  },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  checkmarkColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  showCheckmark: true,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
            if (showBusinessFilter &&
                selectedBusinessId != null &&
                selectedBusinessName != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(selectedBusinessName),
                  selected: true,
                  onSelected: (_) => onBusinessIdCleared?.call(),
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  checkmarkColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: onBusinessIdCleared,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (filterLabelBuilder(selectedFilter) != 'All')
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text('Reset Filters'),
                  onPressed: onResetFiltersChips,
                  avatar: const Icon(Icons.refresh, size: 18),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (showBusinessFilter && showFilterDialog != null)
              ActionChip(
                label: Text('More Filters'),
                onPressed: showFilterDialog,
                avatar: const Icon(Icons.filter_list, size: 18),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
