import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:invois/features/invoice/invoice_generator.dart';
import 'package:invois/features/shared/widgets/my_action_button.dart';

import 'invoice_form_provider.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveInvoice() async {
    final state = ref.read(invoiceFormProvider);
    if (!_canShowPreview()) return;

    try {
      await InvoiceGenerator.saveInvoice(
        invoice: state.invoice!,
        business: state.business!,
        client: state.client!,
        signature: state.signature,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
    final state = ref.watch(invoiceFormProvider);
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
              color: Colors.grey[100],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scroll to view all pages • Tap to zoom',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Quick actions
          Row(
            children: [
              _buildQuickActionButton(
                icon: Icons.zoom_in,
                label: 'Zoom',
                onPressed: () => _showZoomOptions(),
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                icon: Icons.fullscreen,
                label: 'Fullscreen',
                onPressed: () => _showFullscreenPreview(),
              ),
            ],
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.blueGrey[700]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showZoomOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zoom Options', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildZoomButton('Fit Width', Icons.fit_screen),
                _buildZoomButton('Fit Page', Icons.pages),
                _buildZoomButton('100%', Icons.zoom_in),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(String label, IconData icon) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Colors.blueGrey[700]),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey[700],
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
            backgroundColor: Colors.blueGrey[800],
            foregroundColor: Colors.white,
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
