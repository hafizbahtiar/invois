import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/constants/list_filter_type.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';
import 'package:invois/features/shared/widgets/my_filter_section.dart';
import 'package:invois/features/shared/widgets/my_tile.dart';

import 'invoice_list_provider.dart';
import 'invoice_model.dart';

List<Widget> buildInvoiceListSlivers(
  BuildContext context,
  WidgetRef ref, {
  required InvoiceListFilterType selectedFilter,
  required TextEditingController searchController,
  required void Function(InvoiceListFilterType) onFilterSelected,
  required void Function() onResetFilters,
  required Future<void> Function(String) onSearchChanged,
  required Future<void> Function() onRefresh,
  required void Function(Invoice) showDeleteConfirmation,
  required void Function({Invoice? invoice}) showChangeStatusDialog,
  required String Function(InvoiceListFilterType) filterLabel,
  required List<InvoiceListFilterType> filterOptions,
  required String Function(Invoice) getSubtitle,
  required Widget Function(Invoice) buildTrailing,
}) {
  final async = ref.watch(invoiceListProvider);
  final invoices = async.valueOrNull ?? const <Invoice>[];
  final isLoading = async.isLoading;
  final slivers = <Widget>[];

  slivers.add(
    SliverToBoxAdapter(
      child: MyFilterSection(
        searchController: searchController,
        searchQuery: searchController.text,
        onSearchChanged: onSearchChanged,
        selectedFilter: selectedFilter,
        onFilterSelected: onFilterSelected,
        onResetFiltersChips: onResetFilters,
        onResetFiltersSearch: onResetFilters,
        filterOptions: filterOptions,
        filterLabelBuilder: filterLabel,
      ),
    ),
  );

  if (isLoading) {
    slivers.add(
      SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
    );
  } else if (invoices.isEmpty) {
    slivers.add(
      SliverFillRemaining(
        child:
            selectedFilter != InvoiceListFilterType.all ||
                searchController.text.isNotEmpty
            ? MyNoMatchingState(
                icon: Icons.receipt_long,
                title: 'No invoices matching your search',
                buttonText: 'Reset Filters',
                onPressed: onResetFilters,
              )
            : MyEmptyState(
                icon: Icons.receipt_long,
                title: 'No invoices yet',
                description: 'Start by adding your first invoice.',
              ),
      ),
    );
  } else {
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final invoice = invoices[index];
          return MyTile(
            isRounded: true,
            showChevron: true,
            icon: Icons.receipt_long,
            title: invoice.invoiceNumber,
            subtitle: getSubtitle(invoice),
            trailing: buildTrailing(invoice),
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
        }, childCount: invoices.length),
      ),
    );
  }

  return slivers;
}

// Helper functions for HomePage to use
Color getStatusColor(String status) {
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
