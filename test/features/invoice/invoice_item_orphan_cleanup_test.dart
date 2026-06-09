import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_item_orphan_cleanup.dart';

/// Stage 4D: report value object (pure).
void main() {
  group('OrphanItemCleanupReport', () {
    test('hasOrphans / hasDeletions', () {
      const none = OrphanItemCleanupReport(
        scannedItems: 3,
        referencedItems: 3,
        orphanItems: 0,
        deletedItems: 0,
        skippedItems: 0,
      );
      expect(none.hasOrphans, isFalse);
      expect(none.hasDeletions, isFalse);

      const dryRun = OrphanItemCleanupReport(
        scannedItems: 5,
        referencedItems: 3,
        orphanItems: 2,
        deletedItems: 0,
        skippedItems: 2,
      );
      expect(dryRun.hasOrphans, isTrue);
      expect(dryRun.hasDeletions, isFalse); // dry-run found but didn't delete

      const deleted = OrphanItemCleanupReport(
        scannedItems: 5,
        referencedItems: 3,
        orphanItems: 2,
        deletedItems: 2,
        skippedItems: 0,
      );
      expect(deleted.hasDeletions, isTrue);
    });
  });
}
