import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';

class LegacyInvoiceMoneyBackfillReport {
  final int invoicesScanned;
  final int invoicesUpdated;

  const LegacyInvoiceMoneyBackfillReport({
    required this.invoicesScanned,
    required this.invoicesUpdated,
  });

  bool get hasChanges => invoicesUpdated > 0;

  @override
  String toString() {
    return 'LegacyInvoiceMoneyBackfillReport('
        'invoicesScanned: $invoicesScanned, '
        'invoicesUpdated: $invoicesUpdated)';
  }
}

/// One-shot, idempotent migration that fills the integer minor-unit money
/// fields on [Invoice] from the legacy double fields.
///
/// Kept so old installs (and restored backups) upgrade safely; main.dart gates
/// it to a single run per install.
class LegacyInvoiceMoneyBackfill {
  final Store _store;

  const LegacyInvoiceMoneyBackfill(this._store);

  static int centsFromDouble(double value) =>
      Money.fromDouble(value).minorUnits;

  LegacyInvoiceMoneyBackfillReport run() {
    final invoiceBox = _store.box<Invoice>();

    var invoicesScanned = 0;
    var invoicesUpdated = 0;

    _store.runInTransaction(TxMode.write, () {
      final invoices = invoiceBox.getAll();
      invoicesScanned = invoices.length;
      for (final invoice in invoices) {
        final changed = _backfillInvoice(invoice);
        if (changed) {
          invoiceBox.put(invoice);
          invoicesUpdated++;
        }
      }
    });

    return LegacyInvoiceMoneyBackfillReport(
      invoicesScanned: invoicesScanned,
      invoicesUpdated: invoicesUpdated,
    );
  }

  static bool _backfillInvoice(Invoice invoice) {
    var changed = false;

    if (invoice.subtotalCents == null) {
      invoice.subtotalCents = centsFromDouble(invoice.subtotal);
      changed = true;
    }
    if (invoice.discountAmountCents == null) {
      invoice.discountAmountCents = centsFromDouble(invoice.discountAmount);
      changed = true;
    }
    if (invoice.taxAmountCents == null) {
      invoice.taxAmountCents = centsFromDouble(invoice.taxAmount);
      changed = true;
    }
    if (invoice.totalCents == null) {
      invoice.totalCents = centsFromDouble(invoice.total);
      changed = true;
    }
    if (invoice.paidAmountCents == null) {
      invoice.paidAmountCents = centsFromDouble(invoice.paidAmount);
      changed = true;
    }
    if (invoice.balanceDueCents == null) {
      invoice.balanceDueCents = centsFromDouble(invoice.balanceDue);
      changed = true;
    }

    return changed;
  }
}
