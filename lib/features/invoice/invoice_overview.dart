import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/features/setting/presentation/providers/settings_provider.dart';
import 'invoice_list_provider.dart';
import 'invoice_model.dart';

// ===============================
//    MARK: Simple
// ===============================

class SimpleInvoiceOverview extends ConsumerWidget {
  const SimpleInvoiceOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices =
        ref.watch(invoiceListProvider).valueOrNull ?? const <Invoice>[];
    final settingState = ref.watch(settingsProvider);
    final defaultCurrency = settingState.currencyCode;
    final filteredInvoices = invoices
        .where((inv) => inv.currency == defaultCurrency)
        .toList();

    double totalPaid = 0;
    double totalOutstanding = 0;
    double totalAmount = 0;
    int paidCount = 0;
    int outstandingCount = 0;

    for (final invoice in filteredInvoices) {
      totalPaid += invoice.paidAmount;
      totalOutstanding += invoice.balanceDue;
      totalAmount += invoice.total;
      if (invoice.isFullyPaid) {
        paidCount++;
      } else {
        outstandingCount++;
      }
    }

    final paymentRate = totalAmount > 0 ? (totalPaid / totalAmount) * 100 : 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _OverviewItem(
              label: 'Paid',
              value: paidCount.toString(),
              subValue:
                  '${CurrencyUtils.getSymbol(settingState.currencyCode)} ${totalPaid.toStringAsFixed(2)}',
              color: Colors.green,
            ),
          ),
          Expanded(
            child: _OverviewItem(
              label: 'Outstanding',
              value: outstandingCount.toString(),
              subValue:
                  '${CurrencyUtils.getSymbol(settingState.currencyCode)} ${totalOutstanding.toStringAsFixed(2)}',
              color: Colors.orange,
            ),
          ),
          Expanded(
            child: _OverviewItem(
              label: 'Rate',
              value: '${paymentRate.toStringAsFixed(1)}%',
              subValue: 'of total paid',
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;
  final Color color;

  const _OverviewItem({
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subValue,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
