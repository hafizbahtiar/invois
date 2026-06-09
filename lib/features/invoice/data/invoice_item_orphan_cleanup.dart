import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/item/item_model.dart';

class OrphanItemCleanupReport {
  /// Total legacy `Item` rows in the box.
  final int scannedItems;

  /// Items referenced by an `Invoice.items` relation (or an `InvoiceLine`
  /// provenance id) — preserved.
  final int referencedItems;

  /// Items referenced by nothing — deletion candidates.
  final int orphanItems;

  /// Orphans actually removed (0 in dry-run).
  final int deletedItems;

  /// Orphans found but not removed (= [orphanItems] in dry-run, 0 after delete).
  final int skippedItems;

  final List<String> warnings;

  const OrphanItemCleanupReport({
    required this.scannedItems,
    required this.referencedItems,
    required this.orphanItems,
    required this.deletedItems,
    required this.skippedItems,
    this.warnings = const [],
  });

  bool get hasOrphans => orphanItems > 0;
  bool get hasDeletions => deletedItems > 0;

  @override
  String toString() {
    return 'OrphanItemCleanupReport('
        'scanned: $scannedItems, referenced: $referencedItems, '
        'orphans: $orphanItems, deleted: $deletedItems, '
        'skipped: $skippedItems, warnings: ${warnings.length})';
  }
}

/// Stage 4D — deletes orphaned legacy `Item` rows: rows left behind when an old
/// invoice edit cleared the `Invoice.items` relation link without deleting the
/// row.
///
/// Safety: `Item` is invoice-owned only — there is no product/catalog feature,
/// no standalone `Item` creation, and `Item.invoiceId` is never set. An Item is
/// "referenced" (and thus preserved) if it appears in any `Invoice.items`
/// relation OR is named by any `InvoiceLine.sourceItemId` (provenance). Anything
/// else is a safe-to-delete orphan.
///
/// NOT run automatically on startup — call explicitly. Always run [dryRun] first.
class OrphanItemCleanup {
  final Store _store;

  const OrphanItemCleanup(this._store);

  OrphanItemCleanupReport run({required bool dryRun}) {
    final itemBox = _store.box<Item>();
    final invoiceBox = _store.box<Invoice>();
    final lineBox = _store.box<InvoiceLine>();

    final referenced = <int>{};
    for (final invoice in invoiceBox.getAll()) {
      for (final item in invoice.items) {
        final id = item.id;
        if (id != null) referenced.add(id);
      }
    }
    // Extra guard: never delete an item still claimed by a line's provenance id.
    for (final line in lineBox.getAll()) {
      final src = line.sourceItemId;
      if (src != null) referenced.add(src);
    }

    final allItems = itemBox.getAll();
    final orphanIds = <int>[
      for (final item in allItems)
        if (item.id != null && !referenced.contains(item.id)) item.id!,
    ];

    var deleted = 0;
    if (!dryRun && orphanIds.isNotEmpty) {
      _store.runInTransaction(TxMode.write, () {
        deleted = itemBox.removeMany(orphanIds);
      });
    }

    return OrphanItemCleanupReport(
      scannedItems: allItems.length,
      referencedItems: allItems.length - orphanIds.length,
      orphanItems: orphanIds.length,
      deletedItems: deleted,
      skippedItems: orphanIds.length - deleted,
    );
  }
}
