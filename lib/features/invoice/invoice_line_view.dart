import 'package:equatable/equatable.dart';

import 'data/invoice_line_model.dart';
import 'data/invoice_model.dart';
import 'invoice_line_math.dart';
import 'package:invois/features/item/item_model.dart';

/// A stable read view of an invoice line.
///
/// Money is in minor units (cents); quantity in thousandths (see
/// [InvoiceLineMath]).
class InvoiceLineView extends Equatable {
  final String name;
  final String? description;
  final String? unit;
  final String? currency;
  final int unitPriceCents;
  final int quantityMilli;
  final int? taxRateBasisPoints;
  final int sortOrder;
  final int? sourceItemId;

  const InvoiceLineView({
    required this.name,
    this.description,
    this.unit,
    this.currency,
    required this.unitPriceCents,
    required this.quantityMilli,
    this.taxRateBasisPoints,
    this.sortOrder = 0,
    this.sourceItemId,
  });

  /// Line total in cents (exact integer half-up rounding).
  int get lineTotalCents => InvoiceLineMath.lineTotalCents(
    unitPriceCents: unitPriceCents,
    quantityMilli: quantityMilli,
  );

  /// Clean decimal quantity for display, e.g. `1000 -> "1"`, `2500 -> "2.5"`.
  String get displayQuantity => InvoiceLineMath.formatQuantity(quantityMilli);

  /// From a new [InvoiceLine] snapshot (1:1).
  factory InvoiceLineView.fromLine(InvoiceLine line) => InvoiceLineView(
    name: line.name,
    description: line.description,
    unit: line.unit,
    currency: line.currency,
    unitPriceCents: line.unitPriceCents,
    quantityMilli: line.quantityMilli,
    taxRateBasisPoints: line.taxRateBasisPoints,
    sortOrder: line.sortOrder,
    sourceItemId: line.sourceItemId,
  );

  /// From a legacy `Invoice.items` [Item] row. Mirrors the Step 4B backfill
  /// mapping so the fallback and the persisted lines agree.
  factory InvoiceLineView.fromItem(Item item, {required int sortOrder}) =>
      InvoiceLineView(
        name: item.name,
        description: item.description,
        unit: item.unit,
        currency: item.currency,
        unitPriceCents: item.effectiveUnitPriceCents,
        quantityMilli: InvoiceLineMath.quantityMilliFromLegacy(
          item.stockQuantity,
        ),
        taxRateBasisPoints: item.taxRate == null
            ? null
            : (item.taxRate! * 100).round(),
        sortOrder: sortOrder,
        sourceItemId: item.id,
      );

  @override
  List<Object?> get props => [
    name,
    description,
    unit,
    currency,
    unitPriceCents,
    quantityMilli,
    taxRateBasisPoints,
    sortOrder,
    sourceItemId,
  ];
}

/// Resolves invoice line snapshots for production and migration/recovery paths.
class InvoiceLineReader {
  const InvoiceLineReader._();

  /// Production resolution: use only [InvoiceLine] rows.
  ///
  /// Stage 4E-2 intentionally does not fall back to legacy `Invoice.items`.
  /// Missing lines produce an empty result rather than a crash.
  static List<InvoiceLineView> resolveLinesOnly(List<InvoiceLine> lines) {
    if (lines.isEmpty) return const [];
    final sorted = [...lines]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted.map(InvoiceLineView.fromLine).toList();
  }

  /// Production convenience for a store-backed [Invoice].
  static List<InvoiceLineView> fromInvoiceLinesOnly(Invoice invoice) =>
      resolveLinesOnly(invoice.lines.toList());

  /// Migration/recovery resolution (no ObjectBox access) — the unit-testable
  /// fallback core.
  ///
  /// - If [lines] is non-empty: use it (sorted by `sortOrder`).
  /// - Else: map [items] in their given (relation) order.
  static List<InvoiceLineView> resolve({
    required List<InvoiceLine> lines,
    required List<Item> items,
  }) {
    if (lines.isNotEmpty) return resolveLinesOnly(lines);
    return [
      for (var i = 0; i < items.length; i++)
        InvoiceLineView.fromItem(items[i], sortOrder: i),
    ];
  }

  /// Migration/recovery convenience for a store-backed [Invoice]. Production
  /// consumers should use [fromInvoiceLinesOnly].
  static List<InvoiceLineView> fromInvoice(Invoice invoice) =>
      resolve(lines: invoice.lines.toList(), items: invoice.items.toList());

  /// Production subtotal in cents = Σ of line-only totals.
  static int subtotalCentsFromLines(List<InvoiceLine> lines) {
    var total = 0;
    for (final view in resolveLinesOnly(lines)) {
      total += view.lineTotalCents;
    }
    return total;
  }

  /// Migration/recovery subtotal in cents = Σ of the resolved lines' totals
  /// (same lines-preferred / items-fallback source as [resolve]).
  static int subtotalCents({
    required List<InvoiceLine> lines,
    required List<Item> items,
  }) {
    var total = 0;
    for (final view in resolve(lines: lines, items: items)) {
      total += view.lineTotalCents;
    }
    return total;
  }
}
