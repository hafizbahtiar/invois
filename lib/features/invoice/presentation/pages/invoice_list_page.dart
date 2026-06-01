import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_filter_type.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/shared/widgets/my_bottom_sheet.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';
import 'package:invois/features/shared/widgets/simple_list.dart';

import '../../providers/invoice_notifier.dart';
import '../../providers/invoice_providers.dart';
import '../../data/invoice_model.dart';
import '../../data/invoice_query.dart';

class InvoiceListPage extends ConsumerStatefulWidget {
  const InvoiceListPage({super.key});

  @override
  ConsumerState<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends ConsumerState<InvoiceListPage> {
  //============================================
  // MARK: - Properties
  //============================================

  InvoiceListFilterType _selectedFilter = InvoiceListFilterType.all;
  final _searchController = TextEditingController();

  /// Debounce so a query (and ObjectBox watch rebuild) fires once the user
  /// pauses typing, not on every keystroke.
  static const _searchDebounceDuration = Duration(milliseconds: 300);
  Timer? _searchDebounce;

  //============================================
  // MARK: - Init
  //============================================

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  //============================================
  // MARK: - Actions
  //============================================

  // Pushes the selected status filter into invoiceQueryProvider; the reactive
  // list rebuilds automatically.
  void _applyFilter() {
    final notifier = ref.read(invoiceQueryProvider.notifier);
    if (_selectedFilter == InvoiceListFilterType.all) {
      notifier.setStatus(null);
    } else {
      notifier.setStatus(InvoiceStatus.values.byName(_selectedFilter.name));
    }
  }

  Future<void> _onRefresh() async {
    // List is reactive; re-subscribe to satisfy the pull-to-refresh gesture.
    ref.invalidate(invoiceListProvider);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      ref.read(invoiceQueryProvider.notifier).setSearch(value);
    });
  }

  void _onFilterSelected(InvoiceListFilterType filter) {
    setState(() => _selectedFilter = filter);
    _applyFilter();
  }

  void _onResetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _selectedFilter = InvoiceListFilterType.all);
    ref.read(invoiceQueryProvider.notifier).reset();
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

  //============================================
  // MARK: - AppBar
  //============================================

  PreferredSize _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(title: const Text('Invoices'), centerTitle: false),
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

  Widget _buildBody(BuildContext context) {
    final async = ref.watch(invoiceListProvider);

    return Column(
      children: [
        _buildBusinessListHeader(context),
        Expanded(
          child: SimpleList<Invoice>(
            items: async.valueOrNull ?? const [],
            isLoading: async.isLoading,
            errorMessage: async.hasError
                ? (async.error is AppFailure
                      ? (async.error as AppFailure).message
                      : 'Failed to load invoices')
                : null,
            onRefresh: () async => await _onRefresh(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            emptyWidget:
                _selectedFilter != InvoiceListFilterType.all ||
                    _searchController.text.isNotEmpty
                ? MyNoMatchingState(
                    icon: Icons.receipt_long,
                    title: 'No invoices matching your search',
                    buttonText: 'Reset Filters',
                    onPressed: _onResetFilters,
                  )
                : MyEmptyState(
                    icon: Icons.receipt_long,
                    title: 'No invoices yet',
                    description: 'Start by adding your first invoice.',
                  ),
            itemBuilder: (context, invoice, index) {
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
    );
  }

  //============================================
  // MARK: - Floating Action Button
  //============================================

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => Navigator.pushNamed(
        context,
        RoutesName.invoiceForm,
        arguments: {'type': FormType.add.name},
      ),
      tooltip: 'Add Invoice',
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

  String _filterLabel(InvoiceListFilterType filter) {
    return filter.displayName;
  }

  String _getSubtitle(Invoice invoice) {
    final parts = <String>[];

    // Add total amount
    if (invoice.effectiveTotalCents > 0) {
      parts.add(
        '${CurrencyUtils.getSymbol(invoice.currency ?? 'MYR')}${(invoice.effectiveTotalCents / 100).toStringAsFixed(2)}',
      );
    }

    // Add issue date
    final date = invoice.issueDate;
    parts.add('${date.day}/${date.month}/${date.year}');

    return parts.join(' · ');
  }
}
