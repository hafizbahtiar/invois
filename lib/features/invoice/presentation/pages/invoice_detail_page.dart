import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/routing/routes_name.dart';
import 'package:invois/core/constants/form_type.dart';
import 'package:invois/core/utils/currency_utils.dart';
import 'package:invois/core/utils/date_utils.dart' as app_date;
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/domain/invoice_line_view.dart';
import 'package:invois/features/invoice/pdf/invoice_generator.dart';
import 'package:invois/features/invoice/providers/invoice_notifier.dart';
import 'package:invois/features/invoice/providers/invoice_providers.dart';
import 'package:invois/features/invoice/presentation/widgets/invoice_status_chip.dart';
import 'package:invois/core/widgets/my_empty_state.dart';
import 'package:invois/core/widgets/my_snackbar.dart';
import 'package:invois/core/widgets/my_tile.dart';

class InvoiceDetailPage extends ConsumerWidget {
  final int invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        centerTitle: false,
        title: const Text('Invoice Detail'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailError(
          message: 'Failed to load invoice',
          onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
        data: (data) => _InvoiceDetailBody(data: data),
      ),
    );
  }
}

class _InvoiceDetailBody extends ConsumerWidget {
  final InvoiceDetailData data;

  const _InvoiceDetailBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = data.invoice;

    return RefreshIndicator.adaptive(
      onRefresh: () async => ref.invalidate(invoiceDetailProvider(invoice.id!)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _HeaderCard(data: data),
          const SizedBox(height: 16),
          _ActionSection(data: data),
          const SizedBox(height: 16),
          _InfoSection(data: data),
          const SizedBox(height: 16),
          _SignatureSection(data: data),
          const SizedBox(height: 16),
          _LineItemsSection(data: data),
          const SizedBox(height: 16),
          _TotalsSection(data: data),
          if ((invoice.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _TextSection(
              icon: Icons.notes,
              title: 'Notes',
              body: invoice.notes!.trim(),
            ),
          ],
          if (data.terms.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TermsSection(data: data),
          ],
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final InvoiceDetailData data;

  const _HeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final invoice = data.invoice;
    final theme = Theme.of(context);
    final paymentStatus = invoice.paymentStatusDisplay;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayInvoiceNumber(invoice),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.client?.name ?? 'No client selected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (data.business != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.business!.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InvoiceStatusChip(statusName: invoice.status),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Total',
                  value: _formatMoney(invoice, invoice.effectiveTotalCents),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBlock(
                  label: 'Balance Due',
                  value: _formatMoney(
                    invoice,
                    invoice.effectiveBalanceDueCents,
                  ),
                  valueColor: invoice.effectiveBalanceDueCents > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text('Payment Status: $paymentStatus'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ActionSection extends ConsumerWidget {
  final InvoiceDetailData data;

  const _ActionSection({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = data.invoice;
    final status = InvoiceStatusExtension.fromName(invoice.status);
    final canSend =
        status == InvoiceStatus.draft &&
        InvoiceLineReader.fromInvoiceLinesOnly(invoice).isNotEmpty;
    final canMarkPaid = invoice.canMarkAsPaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.tune, title: 'Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
              onPressed: () => Navigator.of(context).pushNamed(
                RoutesName.invoiceForm,
                arguments: {
                  'type': FormType.edit.name,
                  'invoiceId': invoice.id,
                },
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.preview),
              label: const Text('Preview'),
              onPressed: () => Navigator.of(context).pushNamed(
                RoutesName.invoicePreview,
                arguments: {'invoiceId': invoice.id},
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share PDF'),
              onPressed: () => _sharePdf(context),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.payments),
              label: const Text('Mark as Paid'),
              onPressed: canMarkPaid ? () => _markPaid(context, ref) : null,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.mark_email_read),
              label: const Text('Mark as Sent'),
              onPressed: canSend ? () => _markSent(context, ref) : null,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _markSent(BuildContext context, WidgetRef ref) async {
    final id = data.invoice.id;
    if (id == null || id <= 0) return;

    final ok = await ref
        .read(invoiceFormProvider.notifier)
        .markInvoiceAsSent(id);
    if (!context.mounted) return;

    final error = ref.read(invoiceFormProvider).error;
    MySnackBar.show(
      context,
      message: ok
          ? 'Invoice marked as sent'
          : (error ?? 'Failed to mark as sent'),
      type: ok ? MySnackbarType.success : MySnackbarType.failed,
    );
    // Detail is a one-shot FutureProvider; refresh it so the new status shows.
    // The list/dashboard update reactively via the invoice stream.
    if (ok) ref.invalidate(invoiceDetailProvider(id));
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final id = data.invoice.id;
    if (id == null || id <= 0) return;

    final ok = await ref
        .read(invoiceFormProvider.notifier)
        .markInvoiceAsPaid(id);
    if (!context.mounted) return;

    final error = ref.read(invoiceFormProvider).error;
    MySnackBar.show(
      context,
      message: ok
          ? 'Invoice marked as paid'
          : (error ?? 'Failed to mark as paid'),
      type: ok ? MySnackbarType.success : MySnackbarType.failed,
    );
    if (ok) ref.invalidate(invoiceDetailProvider(id));
  }

  Future<void> _sharePdf(BuildContext context) async {
    if (data.business == null || data.client == null) {
      MySnackBar.show(
        context,
        message: 'Business and client are required before sharing.',
        type: MySnackbarType.warning,
      );
      return;
    }

    try {
      await InvoiceGenerator.shareInvoice(
        invoice: data.invoice,
        business: data.business!,
        client: data.client!,
        signature: data.signature,
      );
    } catch (e) {
      debugPrint('Failed to share invoice: $e');
      if (!context.mounted) return;
      MySnackBar.show(
        context,
        message: 'Failed to share invoice. Please try again.',
        type: MySnackbarType.failed,
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Delete Invoice'),
        content: const Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteInvoice(context, ref);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvoice(BuildContext context, WidgetRef ref) async {
    final id = data.invoice.id;
    if (id == null || id <= 0) return;

    final deleted = await ref
        .read(invoiceFormProvider.notifier)
        .deleteInvoiceById(id);

    if (!context.mounted) return;

    MySnackBar.show(
      context,
      message: deleted ? 'Invoice deleted' : 'Failed to delete invoice',
      type: deleted ? MySnackbarType.success : MySnackbarType.failed,
    );

    if (deleted) {
      ref.invalidate(invoiceListProvider);
      Navigator.of(context).pop();
    }
  }
}

class _InfoSection extends StatelessWidget {
  final InvoiceDetailData data;

  const _InfoSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final invoice = data.invoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.event, title: 'Invoice Info'),
        const SizedBox(height: 8),
        MyTile(
          icon: Icons.calendar_today,
          title: 'Issue Date',
          subtitle: app_date.DateUtils.formatReadable(invoice.issueDate),
          showChevron: false,
          isRounded: true,
        ),
        const SizedBox(height: 8),
        MyTile(
          icon: Icons.event_available,
          title: 'Due Date',
          subtitle: app_date.DateUtils.formatReadable(invoice.dueDate),
          showChevron: false,
          isRounded: true,
        ),
      ],
    );
  }
}

class _LineItemsSection extends StatelessWidget {
  final InvoiceDetailData data;

  const _LineItemsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final invoice = data.invoice;
    final lineViews = InvoiceLineReader.fromInvoiceLinesOnly(invoice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.list_alt, title: 'Line Items'),
        const SizedBox(height: 8),
        if (lineViews.isEmpty)
          const MyEmptyState(
            icon: Icons.list_alt,
            title: 'No line items',
            description: 'This invoice does not have any line items yet.',
          )
        else
          ...lineViews.map((view) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MyTile(
                icon: Icons.shopping_cart,
                title: view.name,
                subtitle:
                    '${view.displayQuantity} x ${_formatMoney(invoice, view.unitPriceCents)}',
                trailing: Text(
                  _formatMoney(invoice, view.lineTotalCents),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                showChevron: false,
                isRounded: true,
              ),
            );
          }),
      ],
    );
  }
}

class _SignatureSection extends StatelessWidget {
  final InvoiceDetailData data;

  const _SignatureSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final signature = data.signature;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.draw, title: 'Signature'),
        const SizedBox(height: 8),
        MyTile(
          icon: Icons.draw,
          title: signature == null ? 'No signature' : 'Signature attached',
          subtitle: signature == null
              ? 'This invoice has no selected signature.'
              : [
                  signature.name,
                  if ((signature.title ?? '').trim().isNotEmpty)
                    signature.title!,
                ].join(' · '),
          showChevron: false,
          isRounded: true,
        ),
      ],
    );
  }
}

class _TotalsSection extends StatelessWidget {
  final InvoiceDetailData data;

  const _TotalsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final invoice = data.invoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.calculate, title: 'Summary'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: 'Subtotal',
                value: _formatMoney(invoice, invoice.effectiveSubtotalCents),
              ),
              _SummaryRow(
                label: 'Discount',
                value:
                    '-${_formatMoney(invoice, invoice.effectiveDiscountAmountCents)}',
              ),
              _SummaryRow(
                label: 'Tax',
                value: _formatMoney(invoice, invoice.effectiveTaxAmountCents),
              ),
              const Divider(height: 24),
              _SummaryRow(
                label: 'Total',
                value: _formatMoney(invoice, invoice.effectiveTotalCents),
                isEmphasized: true,
              ),
              if (invoice.effectivePaidAmountCents > 0)
                _SummaryRow(
                  label: 'Paid',
                  value: _formatMoney(
                    invoice,
                    invoice.effectivePaidAmountCents,
                  ),
                ),
              _SummaryRow(
                label: 'Balance Due',
                value: _formatMoney(invoice, invoice.effectiveBalanceDueCents),
                isEmphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isEmphasized
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TextSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: icon, title: title),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(body),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  final InvoiceDetailData data;

  const _TermsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.description, title: 'Terms'),
        const SizedBox(height: 8),
        ...data.terms.map(
          (term) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MyTile(
              icon: Icons.description,
              title: term.name,
              subtitle: term.content,
              showChevron: false,
              isRounded: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MyEmptyState(
        icon: Icons.error_outline,
        title: message,
        description: 'Try refreshing the invoice detail.',
        buttonText: 'Retry',
        onPressed: onRetry,
      ),
    );
  }
}

String _displayInvoiceNumber(Invoice invoice) {
  return '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}';
}

String _formatMoney(Invoice invoice, int cents) {
  final code = invoice.currency ?? 'MYR';
  final symbol = CurrencyUtils.getSymbol(code);
  return '$symbol${(cents / 100).toStringAsFixed(2)}';
}
