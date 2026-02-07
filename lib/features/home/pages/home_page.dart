import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_filter_type.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/invoice/invoice_form_provider.dart';
import 'package:invois/features/invoice/invoice_model.dart';
import 'package:invois/features/invoice/invoice_overview.dart';
import 'package:invois/features/invoice/invoice_list_provider.dart';
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

  InvoiceListFilterType _selectedFilter = InvoiceListFilterType.all;

  //============================================
  // MARK: - Init
  //============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(invoiceListProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    if (_selectedFilter == InvoiceListFilterType.all) {
      await ref.read(invoiceListProvider.notifier).getInvoices();
    } else {
      await ref
          .read(invoiceListProvider.notifier)
          .getInvoicesByStatus(
            InvoiceStatus.values.byName(_selectedFilter.name),
          );
    }
  }

  //============================================
  // MARK: - Actions
  //============================================

  Future<void> _onSearchChanged(String value) async {
    if (value.isEmpty) {
      await ref.read(invoiceListProvider.notifier).getInvoices();
    } else {
      await ref.read(invoiceListProvider.notifier).searchInvoices(value);
    }
  }

  void _onFilterSelected(InvoiceListFilterType filter) {
    setState(() => _selectedFilter = filter);
    _loadInvoices();
  }

  void _onResetFilters() {
    _searchController.clear();
    setState(() => _selectedFilter = InvoiceListFilterType.all);
    _loadInvoices();
  }

  void _onDeleteInvoice(invoice) async {
    final state = ref.watch(invoiceFormProvider);
    final result = await ref
        .read(invoiceFormProvider.notifier)
        .deleteInvoiceById(invoice.id!);
    if (mounted) {
      MySnackBar.show(
        context,
        message: state.error ?? 'Invoice deleted',
        type: result ? MySnackbarType.success : MySnackbarType.failed,
      );
    }
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
        ? InvoiceStatus.values.byName(invoice!.status!)
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
                        color: _getStatusColor(invoice!.status!),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      InvoiceStatus.values.byName(invoice.status!).displayName,
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
                            color: _getStatusColor(status.name),
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

  Widget _buildTrailing(Invoice invoice) {
    return Row(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (invoice.status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(invoice.status!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              InvoiceStatus.values.byName(invoice.status!).displayName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
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
    final state = ref.watch(invoiceListProvider);
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: state.invoices.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child:
                            _selectedFilter.name !=
                                InvoiceListFilterType.all.name
                            ? MyNoMatchingState(
                                buttonText: 'Reset Filters',
                                icon: Icons.receipt_long,
                                title: 'No Invoices',
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
                      itemCount: state.invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = state.invoices[index];
                        return MyTile(
                          isRounded: true,
                          showChevron: true,
                          icon: Icons.receipt_long,
                          title: invoice.invoiceNumber,
                          subtitle: _getSubtitle(invoice),
                          trailing: _buildTrailing(invoice),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              RoutesName.invoiceForm,
                              arguments: {
                                'type': FormType.view.name,
                                'invoiceId': invoice.id,
                              },
                            );
                          },
                        );
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
      onPressed: () => Navigator.pushNamed(
        context,
        RoutesName.invoiceForm,
        arguments: {'type': FormType.add.name},
      ),
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

  List<InvoiceListFilterType> get _filterOptions => [
    InvoiceListFilterType.all,
    InvoiceListFilterType.draft,
    InvoiceListFilterType.sent,
    InvoiceListFilterType.viewed,
    InvoiceListFilterType.paid,
    InvoiceListFilterType.overdue,
    InvoiceListFilterType.cancelled,
    InvoiceListFilterType.refunded,
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'viewed':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.red.shade700;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _filterLabel(InvoiceListFilterType filter) {
    return filter.displayName;
  }

  String _getSubtitle(Invoice invoice) {
    final parts = <String>[];

    // Add total amount
    if (invoice.total > 0) {
      parts.add(
        '${CurrencyUtils.currencies[invoice.currency ?? 'MYR']?.symbol ?? ''}${invoice.total.toStringAsFixed(2)}',
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
