import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_filter_type.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/invoice/providers/invoice_notifier.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/presentation/widgets/invoice_overview.dart';
import 'package:invois/features/invoice/presentation/widgets/invoice_status_chip.dart';
import 'package:invois/features/invoice/providers/invoice_providers.dart';
import 'package:invois/features/invoice/data/invoice_query.dart';
import 'package:invois/features/shared/widgets/my_bottom_sheet.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  //============================================
  // MARK: - Properties
  //============================================

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  InvoiceListFilterType _selectedFilter = InvoiceListFilterType.all;

  static const List<InvoiceListFilterType> _filterOptions = [
    InvoiceListFilterType.all,
    InvoiceListFilterType.draft,
    InvoiceListFilterType.sent,
    InvoiceListFilterType.viewed,
    InvoiceListFilterType.paid,
    InvoiceListFilterType.overdue,
    InvoiceListFilterType.cancelled,
    InvoiceListFilterType.refunded,
  ];

  //============================================
  // MARK: - Init
  //============================================

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Pushes the selected status filter into invoiceQueryProvider; the reactive
  // list rebuilds automatically. Returns a Future so it can back the
  // pull-to-refresh gesture.
  Future<void> _loadInvoices() async {
    final notifier = ref.read(invoiceQueryProvider.notifier);
    if (_selectedFilter == InvoiceListFilterType.all) {
      notifier.setStatus(null);
    } else {
      notifier.setStatus(InvoiceStatus.values.byName(_selectedFilter.name));
    }
  }

  //============================================
  // MARK: - Actions
  //============================================

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(invoiceQueryProvider.notifier).setSearch(value);
    });
  }

  void _onFilterSelected(InvoiceListFilterType filter) {
    setState(() => _selectedFilter = filter);
    _loadInvoices();
  }

  void _onResetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _selectedFilter = InvoiceListFilterType.all);
    ref.read(invoiceQueryProvider.notifier).reset();
  }

  void _navigateToAddInvoice() {
    Navigator.pushNamed(
      context,
      RoutesName.invoiceForm,
      arguments: {'type': FormType.add.name},
    );
  }

  void _onDeleteInvoice(Invoice invoice) async {
    final result = await ref
        .read(invoiceFormProvider.notifier)
        .deleteInvoiceById(invoice.id!);
    if (!mounted) return;
    // Read the error AFTER the operation so the message reflects the actual
    // result, not a pre-delete snapshot.
    final error = ref.read(invoiceFormProvider).error;
    MySnackBar.show(
      context,
      message: result
          ? 'Invoice deleted'
          : (error ?? 'Failed to delete invoice'),
      type: result ? MySnackbarType.success : MySnackbarType.failed,
    );
  }

  //============================================
  // MARK: - Dialog
  //============================================

  void _showDeleteConfirmation(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteInvoice(invoice);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showChangeStatusDialog({Invoice? invoice}) {
    InvoiceStatus? selectedStatus = invoice?.status != null
        ? InvoiceStatusExtension.fromName(invoice!.status)
        : null;

    MyBottomSheetHelper.show(
      context: context,
      title: 'Change Invoice Status',
      subtitle: 'Update the status of this invoice',
      icon: Icons.change_circle,
      initialChildSize: 0.5,
      content: StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current status display
            if (invoice?.status != null) ...[
              Text(
                'Current Status',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: InvoiceStatusChip.colorForName(invoice!.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      InvoiceStatusExtension.fromName(
                        invoice.status,
                      ).displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            // New status selection
            Text(
              'New Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<InvoiceStatus>(
                initialValue: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Select Status',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                items: InvoiceStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: InvoiceStatusChip.colorFor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          status.displayName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedStatus = value);
                },
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      actions: [
        MyBottomSheetActions.cancelButton(
          onPressed: () => Navigator.pop(context),
        ),
        MyBottomSheetActions.primaryButton(
          onPressed: selectedStatus != null
              ? () async {
                  if (invoice != null &&
                      selectedStatus != null &&
                      invoice.id != null &&
                      invoice.id! > 0) {
                    await ref
                        .read(invoiceFormProvider.notifier)
                        .updateInvoiceStatus(invoice.id!, selectedStatus!);
                  }
                  if (mounted) Navigator.pop(context);
                }
              : () {},
          text: 'Update Status',
          isEnabled: selectedStatus != null,
        ),
      ],
    );
  }

  //============================================
  // MARK: - Widgets
  //============================================

  Widget _buildInvoiceTile(Invoice invoice) {
    return MyTile(
      key: ValueKey(invoice.id ?? invoice.invoiceNumber),
      isRounded: true,
      showChevron: true,
      icon: Icons.receipt_long,
      title: invoice.invoiceNumber,
      subtitle: _getSubtitle(invoice),
      trailing: _buildTrailing(invoice),
      onTap: () {
        Navigator.of(context).pushNamed(
          RoutesName.invoiceDetail,
          arguments: {'invoiceId': invoice.id},
        );
      },
    );
  }

  Widget _buildTrailing(Invoice invoice) {
    return Row(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (invoice.status != null)
          InvoiceStatusChip(statusName: invoice.status),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                spacing: 8,
                children: [const Icon(Icons.edit), Text('Edit')],
              ),
              onTap: () => Navigator.pushNamed(
                context,
                RoutesName.invoiceForm,
                arguments: {
                  'type': FormType.edit.name,
                  'invoiceId': invoice.id,
                },
              ),
            ),
            PopupMenuItem(
              child: Row(
                spacing: 8,
                children: [const Icon(Icons.preview), Text('Preview')],
              ),
              onTap: () => Navigator.pushNamed(
                context,
                RoutesName.invoicePreview,
                arguments: {'invoiceId': invoice.id},
              ),
            ),
            PopupMenuItem(
              child: Row(
                spacing: 8,
                children: [
                  const Icon(Icons.change_circle, color: Colors.blue),
                  Text('Change Status', style: TextStyle(color: Colors.blue)),
                ],
              ),
              onTap: () => _showChangeStatusDialog(invoice: invoice),
            ),
            PopupMenuItem(
              child: Row(
                spacing: 8,
                children: [
                  const Icon(Icons.delete, color: Colors.red),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () => _showDeleteConfirmation(invoice),
            ),
          ],
        ),
      ],
    );
  }

  //============================================
  // MARK: - AppBar
  //============================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Invois',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: IconButton(
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(RoutesName.settings),
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  Widget _buildBody(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceListProvider);
    final invoices = invoicesAsync.value ?? const <Invoice>[];
    // Only treat it as an error screen when there's nothing to show; a transient
    // error while data is already on screen shouldn't blank the list.
    final hasError = invoicesAsync.hasError && invoices.isEmpty;
    final isInitialLoading = invoicesAsync.isLoading && invoices.isEmpty;
    final hasActiveFilters =
        _selectedFilter != InvoiceListFilterType.all ||
        _searchController.text.trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator.adaptive(
        onRefresh: _loadInvoices,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: false,
              delegate: _SimpleInvoiceOverviewDelegate(),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _RedContainerHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchController.text,
                onSearchChanged: _onSearchChanged,
                selectedFilter: _selectedFilter,
                onFilterSelected: _onFilterSelected,
                onResetFiltersChips: _onResetFilters,
                onResetFiltersSearch: _onResetFilters,
                filterOptions: _filterOptions,
                filterLabelBuilder: _filterLabel,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
              sliver: isInitialLoading
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  : hasError
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: MyNoMatchingState(
                          icon: Icons.error_outline,
                          title: 'Couldn\'t load invoices',
                          buttonText: 'Retry',
                          onPressed: () => ref.invalidate(invoiceListProvider),
                        ),
                      ),
                    )
                  : invoices.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: hasActiveFilters
                            ? MyNoMatchingState(
                                buttonText: 'Reset Filters',
                                icon: Icons.receipt_long,
                                title: 'No invoices matching your filters',
                                onPressed: () => _onResetFilters(),
                              )
                            : MyEmptyState(
                                icon: Icons.receipt_long,
                                title: 'No Invoices',
                                description: 'You have no invoices yet',
                              ),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        return _buildInvoiceTile(invoices[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  //============================================
  // MARK: - Floating Action Button
  //============================================

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddInvoice,
      tooltip: 'Add Invoice',
      label: const Text('Add Invoice'),
      icon: const Icon(Icons.add),
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

  String _filterLabel(InvoiceListFilterType filter) {
    return filter.displayName;
  }

  String _getSubtitle(Invoice invoice) {
    final parts = <String>[];

    // Add total amount
    if (invoice.effectiveTotalCents > 0) {
      parts.add(
        '${CurrencyUtils.currencies[invoice.currency ?? 'MYR']?.symbol ?? ''}${(invoice.effectiveTotalCents / 100).toStringAsFixed(2)}',
      );
    }

    // Add issue date
    final date = invoice.issueDate;
    parts.add('${date.day}/${date.month}/${date.year}');

    return parts.join(' · ');
  }
}

//============================================
// MARK: - Sliver Persistent Header Delegate
//============================================

class _SimpleInvoiceOverviewDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const SimpleInvoiceOverview(),
    );
  }

  @override
  double get maxExtent => 110; // Adjust as needed
  @override
  double get minExtent => 110; // Adjust as needed

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _RedContainerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final InvoiceListFilterType selectedFilter;
  final ValueChanged<InvoiceListFilterType> onFilterSelected;
  final VoidCallback onResetFiltersChips;
  final VoidCallback onResetFiltersSearch;
  final List<InvoiceListFilterType> filterOptions;
  final String Function(InvoiceListFilterType) filterLabelBuilder;

  _RedContainerHeaderDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onResetFiltersChips,
    required this.onResetFiltersSearch,
    required this.filterOptions,
    required this.filterLabelBuilder,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return MyFilterSection(
      searchController: searchController,
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      selectedFilter: selectedFilter,
      onFilterSelected: onFilterSelected,
      onResetFiltersChips: onResetFiltersChips,
      onResetFiltersSearch: onResetFiltersSearch,
      filterOptions: filterOptions,
      filterLabelBuilder: filterLabelBuilder,
    );
  }

  @override
  double get maxExtent => 110; // Adjust as needed
  @override
  double get minExtent => 110; // Adjust as needed

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is! _RedContainerHeaderDelegate) return true;

    return oldDelegate.searchController != searchController ||
        oldDelegate.searchQuery != searchQuery ||
        oldDelegate.selectedFilter != selectedFilter ||
        oldDelegate.filterOptions != filterOptions;
  }
}
