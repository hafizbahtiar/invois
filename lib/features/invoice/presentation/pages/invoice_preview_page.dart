import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:invois/features/invoice/pdf/invoice_generator.dart';
import 'package:invois/core/widgets/my_action_button.dart';
import 'package:invois/core/widgets/my_snackbar.dart';

import '../../providers/invoice_providers.dart';

/// A page to preview and interact with a generated invoice.
///
/// Reads through its own autoDispose [invoiceDetailProvider] family (P2-006):
/// loading a preview no longer mutates the shared invoice form state, and the
/// data is released when the page is popped.
class InvoicePreviewPage extends ConsumerWidget {
  final int invoiceId;

  const InvoicePreviewPage({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(invoiceDetailProvider(invoiceId));
    final data = detail.value;
    final canPreview =
        data != null && data.business != null && data.client != null;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text('Invoice ${data?.invoice.invoiceNumber ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Invoice',
            onPressed: canPreview ? () => _printInvoice(context, data) : null,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Invoice',
            onPressed: canPreview ? () => _shareInvoice(context, data) : null,
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save Invoice',
            onPressed: canPreview ? () => _saveInvoice(context, data) : null,
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading invoice data...'),
            ],
          ),
        ),
        error: (error, _) => _PreviewMessage(
          icon: Icons.error_outline,
          iconColor: Colors.red,
          title: 'Failed to load invoice data',
          buttonLabel: 'Try Again',
          buttonIcon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
        data: (data) {
          if (data.business == null || data.client == null) {
            return _PreviewMessage(
              icon: Icons.warning_amber,
              iconColor: Colors.orange,
              title: 'Missing data to generate invoice',
              subtitle: 'Please ensure business and client are set.',
              buttonLabel: 'Go Back',
              buttonIcon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            );
          }
          return _PreviewBody(data: data);
        },
      ),
      bottomNavigationBar: canPreview
          ? _BottomActionBar(data: data)
          : const SizedBox.shrink(),
    );
  }
}

Future<void> _printInvoice(BuildContext context, InvoiceDetailData data) async {
  try {
    await InvoiceGenerator.printInvoice(
      invoice: data.invoice,
      business: data.business!,
      client: data.client!,
      signature: data.signature,
    );
  } catch (e) {
    debugPrint('Failed to print invoice: $e');
    if (context.mounted) {
      MySnackBar.show(
        context,
        message: 'Failed to print invoice. Please try again.',
        type: MySnackbarType.failed,
      );
    }
  }
}

Future<void> _shareInvoice(BuildContext context, InvoiceDetailData data) async {
  try {
    await InvoiceGenerator.shareInvoice(
      invoice: data.invoice,
      business: data.business!,
      client: data.client!,
      signature: data.signature,
    );
  } catch (e) {
    debugPrint('Failed to share invoice: $e');
    if (context.mounted) {
      MySnackBar.show(
        context,
        message: 'Failed to share invoice. Please try again.',
        type: MySnackbarType.failed,
      );
    }
  }
}

Future<void> _saveInvoice(BuildContext context, InvoiceDetailData data) async {
  try {
    final savedPath = await InvoiceGenerator.saveInvoice(
      invoice: data.invoice,
      business: data.business!,
      client: data.client!,
      signature: data.signature,
    );
    // Log the full path for debugging; show only a generic message to the user
    // so the filesystem path is not displayed in the UI.
    debugPrint('Invoice saved to $savedPath');
    if (context.mounted) {
      MySnackBar.show(
        context,
        message: 'Invoice saved to app storage',
        type: MySnackbarType.success,
      );
    }
  } catch (e) {
    debugPrint('Failed to save invoice: $e');
    if (context.mounted) {
      MySnackBar.show(
        context,
        message: 'Failed to save invoice. Please try again.',
        type: MySnackbarType.failed,
      );
    }
  }
}

class _PreviewMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String buttonLabel;
  final Icon buttonIcon;
  final VoidCallback onPressed;

  const _PreviewMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: iconColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          MyActionButton(
            cancelLabel: '',
            saveLabel: buttonLabel,
            showCancel: false,
            saveIcon: buttonIcon,
            saveOnPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  final InvoiceDetailData data;

  const _PreviewBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PageNavigationHeader(data: data),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InvoiceGenerator.previewInvoice(
                invoice: data.invoice,
                business: data.business!,
                client: data.client!,
                signature: data.signature,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageNavigationHeader extends StatelessWidget {
  final InvoiceDetailData data;

  const _PageNavigationHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scroll to view all pages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _QuickActionButton(
            icon: Icons.fullscreen,
            label: 'Fullscreen',
            onPressed: () => _showFullscreenPreview(context),
          ),
        ],
      ),
    );
  }

  void _showFullscreenPreview(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Invoice ${data.invoice.invoiceNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => _printInvoice(context, data),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareInvoice(context, data),
              ),
            ],
          ),
          body: InvoiceGenerator.previewInvoice(
            invoice: data.invoice,
            business: data.business!,
            client: data.client!,
            signature: data.signature,
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final InvoiceDetailData data;

  const _BottomActionBar({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.print,
                  label: 'Print',
                  onPressed: () => _printInvoice(context, data),
                  color: Colors.blue[600],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onPressed: () => _shareInvoice(context, data),
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.save_alt,
                  label: 'Save',
                  onPressed: () => _saveInvoice(context, data),
                  color: Colors.orange[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color ?? Colors.grey[300]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
