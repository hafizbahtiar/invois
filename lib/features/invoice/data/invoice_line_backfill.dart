import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/features/invoice/data/invoice_line_model.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/invoice/invoice_line_math.dart';

class InvoiceLineBackfillReport {
  final int invoicesScanned;
  final int invoicesBackfilled;
  final int linesCreated;

  const InvoiceLineBackfillReport({
    required this.invoicesScanned,
    required this.invoicesBackfilled,
    required this.linesCreated,
  });

  bool get hasChanges => invoicesBackfilled > 0;

  @override
  String toString() {
    return 'InvoiceLineBackfillReport('
        'invoicesScanned: $invoicesScanned, '
        'invoicesBackfilled: $invoicesBackfilled, '
        'linesCreated: $linesCreated)';
  }
}

/// Step 4B — additive, idempotent backfill that creates [InvoiceLine] snapshots
/// from the legacy `Invoice.items` relation. It is purely additive:
///   - never deletes or mutates legacy `Item` rows,
///   - never changes invoice totals or the legacy `items` relation,
///   - skips invoices that already have lines (safe to run on every launch),
///   - skips invoices with no legacy items.
class InvoiceLineBackfill {
  final Store _store;

  const InvoiceLineBackfill(this._store);

  InvoiceLineBackfillReport run() {
    final invoiceBox = _store.box<Invoice>();
    final lineBox = _store.box<InvoiceLine>();

    var invoicesScanned = 0;
    var invoicesBackfilled = 0;
    var linesCreated = 0;

    _store.runInTransaction(TxMode.write, () {
      final invoices = invoiceBox.getAll();
      invoicesScanned = invoices.length;

      for (final invoice in invoices) {
        // Idempotent: an invoice that already has lines is left untouched.
        if (invoice.lines.isNotEmpty) continue;

        final items = invoice.items.toList(); // preserves legacy order
        if (items.isEmpty) continue;

        final newLines = <InvoiceLine>[];
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final line = InvoiceLine(
            sourceItemId: item.id,
            name: item.name,
            description: item.description,
            unit: item.unit,
            currency: item.currency ?? invoice.currency,
            unitPriceCents: item.effectiveUnitPriceCents,
            quantityMilli: InvoiceLineMath.quantityMilliFromLegacy(
              item.stockQuantity,
            ),
            taxRateBasisPoints: item.taxRate == null
                ? null
                : (item.taxRate! * 100).round(),
            sortOrder: i,
            createdAt: invoice.createdAt,
            updatedAt: invoice.updatedAt,
          );
          line.invoice.target = invoice;
          newLines.add(line);
        }

        lineBox.putMany(newLines);
        invoicesBackfilled++;
        linesCreated += newLines.length;
      }
    });

    return InvoiceLineBackfillReport(
      invoicesScanned: invoicesScanned,
      invoicesBackfilled: invoicesBackfilled,
      linesCreated: linesCreated,
    );
  }
}
