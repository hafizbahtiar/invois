import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:invois/features/invoice/pdf/invoice_generator.dart';
import 'package:invois/features/shared/widgets/my_action_button.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';

import '../../providers/invoice_notifier.dart';

/// A page to preview and interact with a generated invoice
class InvoicePreviewPage extends ConsumerStatefulWidget {
  final int invoiceId;

  const InvoicePreviewPage({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoicePreviewPage> createState() => _InvoicePreviewPageState();
}

class _InvoicePreviewPageState extends ConsumerState<InvoicePreviewPage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  //============================================
  // MARK: - Actions
  //============================================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(invoiceFormProvider.notifier);
      await notifier.getInvoiceById(widget.invoiceId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load invoice data: ${e.toString()}';
      });
    }
  }

  Future<void> _printInvoice() async {
    final state = ref.read(invoiceFormProvider);
    if (!_canShowPreview()) return;

    try {
      await InvoiceGenerator.printInvoice(
        invoice: state.invoice!,
        business: state.business!,
        client: state.client!,
        signature: state.signature,
      );
    } catch (e) {
      if (mounted) {
        MySnackBar.show(
          context,
          message: 'Failed to print invoice: ${e.toString()}',
          type: MySnackbarType.failed,
        );
      }
    }
  }

  Future<void> _shareInvoice() async {
    final state = ref.read(invoiceFormProvider);
    if (!_canShowPreview()) return;

    try {
      await InvoiceGenerator.shareInvoice(
        invoice: state.invoice!,
        business: state.business!,
        client: state.client!,
        signature: state.signature,
      );
    } catch (e) {
      if (mounted) {
        MySnackBar.show(
          context,
          message: 'Failed to share invoice: ${e.toString()}',
          type: MySnackbarType.failed,
        );
      }
    }
  }

  Future<void> _saveInvoice() async {
    final state = ref.read(invoiceFormProvider);
    if (!_canShowPreview()) return;

    try {
      final savedPath = await InvoiceGenerator.saveInvoice(
        invoice: state.invoice!,
        business: state.business!,
        client: state.client!,
        signature: state.signature,
      );

      if (mounted) {
        MySnackBar.show(
          context,
          message: 'Saved to $savedPath',
          type: MySnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        MySnackBar.show(
          context,
          message: 'Failed to save invoice: ${e.toString()}',
          type: MySnackbarType.failed,
        );
      }
    }
  }

  //============================================
  // MARK: - AppBar
  //============================================

  PreferredSizeWidget _buildAppBar() {
    final state = ref.watch(invoiceFormProvider);
    return AppBar(
      forceMaterialTransparency: true,
      title: Text('Invoice ${state.invoice?.invoiceNumber}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.print),
          tooltip: 'Print Invoice',
          onPressed: _canShowPreview() ? _printInvoice : null,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share Invoice',
          onPressed: _canShowPreview() ? _shareInvoice : null,
        ),
        IconButton(
          icon: const Icon(Icons.save_alt),
          tooltip: 'Save Invoice',
          onPressed: _canShowPreview() ? _saveInvoice : null,
        ),
      ],
    );
  }

  //============================================
  // MARK: - Body
  //============================================

  Widget _buildBody() {
    final state = ref.watch(invoiceFormProvider);

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading invoice data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            MyActionButton(
              cancelLabel: '',
              saveLabel: 'Try Again',
              showCancel: false,
              saveIcon: const Icon(Icons.refresh),
              saveOnPressed: _loadData,
            ),
          ],
        ),
      );
    }

    if (!_canShowPreview()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Missing data to generate invoice',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please ensure business, client, and signature are set.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            MyActionButton(
              cancelLabel: '',
              saveLabel: 'Go Back',
              showCancel: false,
              saveIcon: const Icon(Icons.arrow_back),
              saveOnPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }

    // Show the enhanced PDF preview with better navigation
    return _buildEnhancedPreview(state);
  }

  Widget _buildBottomBar() {
    if (_isLoading || _errorMessage != null || !_canShowPreview()) {
      return const SizedBox.shrink();
    }

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
              // Print button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.print,
                  label: 'Print',
                  onPressed: _printInvoice,
                  color: Colors.blue[600],
                ),
              ),
              const SizedBox(width: 12),

              // Share button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onPressed: _shareInvoice,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(width: 12),

              // Save button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.save_alt,
                  label: 'Save',
                  onPressed: _saveInvoice,
                  color: Colors.orange[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color? color,
  }) {
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

  bool _canShowPreview() {
    final state = ref.read(invoiceFormProvider);
    return state.business != null && state.client != null;
  }

  //============================================
  // MARK: - Enhanced Preview
  //============================================

  Widget _buildEnhancedPreview(dynamic state) {
    return Column(
      children: [
        // Page navigation header
        _buildPageNavigationHeader(),

        // PDF preview with enhanced scrolling
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
                invoice: state.invoice!,
                business: state.business!,
                client: state.client!,
                signature: state.signature,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageNavigationHeader() {
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
          // Page info
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

          // Quick actions
          _buildQuickActionButton(
            icon: Icons.fullscreen,
            label: 'Fullscreen',
            onPressed: () => _showFullscreenPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
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

  void _showFullscreenPreview() {
    final state = ref.read(invoiceFormProvider);
    if (!_canShowPreview()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Invoice ${state.invoice?.invoiceNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: _printInvoice,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareInvoice,
              ),
            ],
          ),
          body: InvoiceGenerator.previewInvoice(
            invoice: state.invoice!,
            business: state.business!,
            client: state.client!,
            signature: state.signature,
          ),
        ),
      ),
    );
  }

  //============================================
  // MARK: - Build
  //============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}
