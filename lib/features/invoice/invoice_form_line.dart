import 'data/invoice_line_model.dart';
import 'invoice_line_math.dart';

/// In-memory invoice form row. This is a plain Dart draft, not an ObjectBox
/// entity.
class InvoiceFormLine {
  final int? id;
  final String name;
  final String? description;
  final String? unit;
  final String? currency;
  final int unitPriceCents;
  final int quantityMilli;
  final int? taxRateBasisPoints;
  final int sortOrder;
  final int? sourceItemId;

  const InvoiceFormLine({
    this.id,
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

  /// Line total in cents (`unitPrice × quantityMilli`, half-up at the cent).
  int get lineTotalCents => InvoiceLineMath.lineTotalCents(
    unitPriceCents: unitPriceCents,
    quantityMilli: quantityMilli,
  );

  /// Rebuilds the temporary form row from an authoritative [InvoiceLine]
  /// snapshot. This does not create or persist any legacy `Item` row.
  factory InvoiceFormLine.fromLineSnapshot(InvoiceLine line) => InvoiceFormLine(
    id: line.id != null && line.id! > 0 ? -line.id! : -(line.sortOrder + 1),
    sourceItemId: line.sourceItemId,
    name: line.name,
    description: line.description,
    unit: line.unit,
    currency: line.currency,
    unitPriceCents: line.unitPriceCents,
    quantityMilli: line.quantityMilli,
    taxRateBasisPoints: line.taxRateBasisPoints,
    sortOrder: line.sortOrder,
  );

  InvoiceFormLine copyWith({
    int? id,
    String? name,
    String? description,
    String? unit,
    String? currency,
    int? unitPriceCents,
    int? quantityMilli,
    int? taxRateBasisPoints,
    int? sortOrder,
    int? sourceItemId,
  }) => InvoiceFormLine(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    unit: unit ?? this.unit,
    currency: currency ?? this.currency,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    quantityMilli: quantityMilli ?? this.quantityMilli,
    taxRateBasisPoints: taxRateBasisPoints ?? this.taxRateBasisPoints,
    sortOrder: sortOrder ?? this.sortOrder,
    sourceItemId: sourceItemId ?? this.sourceItemId,
  );

  /// Subtotal (cents) = Σ of each form line's `unitPriceCents × quantityMilli`
  /// (half-up at the cent via [InvoiceLineMath.lineTotalCents]). The
  /// authoritative source for the form's live + stored subtotal (Step 4C-4D-2C).
  static int subtotalCents(List<InvoiceFormLine> lines) {
    var total = 0;
    for (final line in lines) {
      total += InvoiceLineMath.lineTotalCents(
        unitPriceCents: line.unitPriceCents,
        quantityMilli: line.quantityMilli,
      );
    }
    return total;
  }

  /// Resolve the form-line list for a loaded invoice. Stage 4E-4 is line-only.
  static List<InvoiceFormLine> resolve({required List<InvoiceLine> lines}) {
    final sorted = [...lines]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [for (final line in sorted) InvoiceFormLine.fromLineSnapshot(line)];
  }
}
