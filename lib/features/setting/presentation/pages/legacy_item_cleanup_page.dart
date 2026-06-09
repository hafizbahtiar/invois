import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/features/invoice/data/invoice_item_orphan_cleanup.dart';
import 'package:invois/features/shared/widgets/my_snackbar.dart';

/// One-line headline for a cleanup report (pure, testable).
String cleanupHeadline(OrphanItemCleanupReport r) {
  if (r.deletedItems > 0) return 'Deleted ${r.deletedItems} orphan item row(s)';
  if (r.orphanItems == 0) return 'No orphan items found';
  return '${r.orphanItems} orphan item row(s) found';
}

/// Labeled rows for displaying a cleanup report (pure, testable).
List<({String label, String value})> cleanupReportRows(
  OrphanItemCleanupReport r,
) => [
  (label: 'Total items', value: '${r.scannedItems}'),
  (label: 'Referenced (kept)', value: '${r.referencedItems}'),
  (label: 'Orphans', value: '${r.orphanItems}'),
  (label: 'Deleted', value: '${r.deletedItems}'),
  (label: 'Skipped', value: '${r.skippedItems}'),
  (label: 'Warnings', value: '${r.warnings.length}'),
];

/// Stage 4D-2: debug-only maintenance screen to manually run the legacy
/// [OrphanItemCleanup]. Reachable only from the Settings "Maintenance" section,
/// which is gated behind `kDebugMode`. Never runs automatically; deletion
/// requires an explicit dry-run first plus a confirmation dialog.
class LegacyItemCleanupPage extends ConsumerStatefulWidget {
  const LegacyItemCleanupPage({super.key});

  @override
  ConsumerState<LegacyItemCleanupPage> createState() =>
      _LegacyItemCleanupPageState();
}

class _LegacyItemCleanupPageState extends ConsumerState<LegacyItemCleanupPage> {
  OrphanItemCleanupReport? _report;
  bool _busy = false;
  String? _error;

  Future<void> _run({required bool dryRun}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(storeProvider);
      final report = OrphanItemCleanup(store).run(dryRun: dryRun);
      if (!mounted) return;
      setState(() => _report = report);
      MySnackBar.show(
        context,
        message: dryRun ? 'Dry run complete' : cleanupHeadline(report),
        type: MySnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      MySnackBar.show(
        context,
        message: 'Cleanup failed: $e',
        type: MySnackbarType.failed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Delete orphan items?'),
        content: const Text(
          'This will permanently delete orphan legacy invoice item rows. '
          'It will not delete invoices or invoice lines.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run(dryRun: false);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    // Delete is enabled only after a dry-run that actually found orphans.
    final canDelete = !_busy && report != null && report.orphanItems > 0;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        centerTitle: false,
        title: const Text('Legacy Item Cleanup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Removes orphan legacy invoice item rows left behind by older edit '
              'flows. Invoices and invoice lines are never touched. Always run a '
              'dry run first.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Dry Run'),
                    onPressed: _busy ? null : () => _run(dryRun: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Delete Orphans'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: canDelete ? _confirmDelete : null,
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator.adaptive()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (report != null) ...[
              const SizedBox(height: 24),
              Text(
                cleanupHeadline(report),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    for (final row in cleanupReportRows(report))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(row.label),
                            Text(row.value),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
