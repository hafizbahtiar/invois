import 'package:invois/core/database/objectbox.g.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/features/invoice/data/invoice_model.dart';
import 'package:invois/features/item/item_model.dart';

class S3MoneyBackfillReport {
  final int invoicesScanned;
  final int invoicesUpdated;
  final int itemsScanned;
  final int itemsUpdated;

  const S3MoneyBackfillReport({
    required this.invoicesScanned,
    required this.invoicesUpdated,
    required this.itemsScanned,
    required this.itemsUpdated,
  });

  bool get hasChanges => invoicesUpdated > 0 || itemsUpdated > 0;

  @override
  String toString() {
    return 'S3MoneyBackfillReport('
        'invoicesScanned: $invoicesScanned, '
        'invoicesUpdated: $invoicesUpdated, '
        'itemsScanned: $itemsScanned, '
        'itemsUpdated: $itemsUpdated)';
  }
}

/// One-shot, idempotent S3 migration that fills newly added integer money
/// fields from the legacy double fields.
///
/// This stage does not switch reads/writes yet; it only prepares existing rows.
class S3MoneyBackfill {
  final Store _store;

  const S3MoneyBackfill(this._store);

  static int centsFromDouble(double value) =>
      Money.fromDouble(value).minorUnits;

  S3MoneyBackfillReport run() {
    final invoiceBox = _store.box<Invoice>();
    final itemBox = _store.box<Item>();

    var invoicesScanned = 0;
    var invoicesUpdated = 0;
    var itemsScanned = 0;
    var itemsUpdated = 0;

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

      final items = itemBox.getAll();
      itemsScanned = items.length;
      for (final item in items) {
        final changed = _backfillItem(item);
        if (changed) {
          itemBox.put(item);
          itemsUpdated++;
        }
      }
    });

    return S3MoneyBackfillReport(
      invoicesScanned: invoicesScanned,
      invoicesUpdated: invoicesUpdated,
      itemsScanned: itemsScanned,
      itemsUpdated: itemsUpdated,
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

  static bool _backfillItem(Item item) {
    var changed = false;

    if (item.unitPriceCents == null) {
      item.unitPriceCents = centsFromDouble(item.unitPrice);
      changed = true;
    }
    if (item.costPrice != null && item.costPriceCents == null) {
      item.costPriceCents = centsFromDouble(item.costPrice!);
      changed = true;
    }
    if (item.wholesalePrice != null && item.wholesalePriceCents == null) {
      item.wholesalePriceCents = centsFromDouble(item.wholesalePrice!);
      changed = true;
    }

    return changed;
  }
}
