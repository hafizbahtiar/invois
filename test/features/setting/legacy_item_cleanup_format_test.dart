import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_item_orphan_cleanup.dart';
import 'package:invois/features/setting/presentation/pages/legacy_item_cleanup_page.dart';

/// Stage 4D-2: pure formatting of the cleanup report shown in the maintenance UI.
void main() {
  OrphanItemCleanupReport report({
    int scanned = 0,
    int referenced = 0,
    int orphan = 0,
    int deleted = 0,
    int skipped = 0,
  }) => OrphanItemCleanupReport(
    scannedItems: scanned,
    referencedItems: referenced,
    orphanItems: orphan,
    deletedItems: deleted,
    skippedItems: skipped,
  );

  group('cleanupHeadline', () {
    test('no orphans', () {
      expect(
        cleanupHeadline(report(scanned: 3, referenced: 3)),
        'No orphan items found',
      );
    });

    test('orphans found (dry-run, not deleted)', () {
      expect(
        cleanupHeadline(report(scanned: 5, referenced: 3, orphan: 2, skipped: 2)),
        '2 orphan item row(s) found',
      );
    });

    test('after delete', () {
      expect(
        cleanupHeadline(report(scanned: 5, referenced: 3, orphan: 2, deleted: 2)),
        'Deleted 2 orphan item row(s)',
      );
    });
  });

  group('cleanupReportRows', () {
    test('handles zero orphans', () {
      final rows = cleanupReportRows(report(scanned: 4, referenced: 4));
      expect(rows.map((r) => r.label), [
        'Total items',
        'Referenced (kept)',
        'Orphans',
        'Deleted',
        'Skipped',
        'Warnings',
      ]);
      expect(rows.firstWhere((r) => r.label == 'Orphans').value, '0');
      expect(rows.firstWhere((r) => r.label == 'Total items').value, '4');
    });

    test('handles non-zero orphans + deletions', () {
      final rows = cleanupReportRows(
        report(scanned: 6, referenced: 4, orphan: 2, deleted: 2),
      );
      expect(rows.firstWhere((r) => r.label == 'Orphans').value, '2');
      expect(rows.firstWhere((r) => r.label == 'Deleted').value, '2');
      expect(rows.firstWhere((r) => r.label == 'Skipped').value, '0');
    });
  });
}
