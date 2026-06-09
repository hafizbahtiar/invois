import 'data/invoice_line_model.dart';
import 'invoice_form_line.dart';

/// Builds [InvoiceLine] snapshots for persistence.
///
/// Pure — does not touch ObjectBox; the local source sets each line's `invoice`
/// relation when persisting.
class InvoiceLineBuilder {
  const InvoiceLineBuilder._();

  /// Authoritative: preserves each form line's `quantityMilli` exactly.
  static List<InvoiceLine> fromFormLines(List<InvoiceFormLine> formLines) => [
    for (var i = 0; i < formLines.length; i++) _fromFormLine(formLines[i], i),
  ];

  static InvoiceLine _fromFormLine(InvoiceFormLine line, int sortOrder) {
    return InvoiceLine(
      sourceItemId: line.sourceItemId,
      name: line.name,
      description: line.description,
      unit: line.unit,
      currency: line.currency,
      unitPriceCents: line.unitPriceCents,
      quantityMilli: line.quantityMilli,
      taxRateBasisPoints: line.taxRateBasisPoints,
      sortOrder: sortOrder,
    );
  }
}
