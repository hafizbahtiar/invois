import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';

import 'invoice_model.dart';

/// A dedicated, invoice-owned line snapshot.
///
/// Money is in integer minor units (cents); quantity is in thousandths
/// (`quantityMilli`, `1000 == 1.000`) — see [InvoiceLineMath].
@Entity()
// ignore: must_be_immutable
class InvoiceLine extends Equatable {
  @Id()
  int? id;

  /// Owning invoice (canonical relation; backlinked by `Invoice.lines`).
  final ToOne<Invoice> invoice = ToOne<Invoice>();

  /// Historical provenance only. Never used to recompute; the line is a
  /// self-contained snapshot.
  final int? sourceItemId;

  final String name;
  final String? description;
  final String? unit;
  final String? currency;

  /// Unit price in minor units (cents) at invoice time.
  final int unitPriceCents;

  /// Quantity in thousandths: `1000 == 1.000` (0.001 precision).
  final int quantityMilli;

  /// Snapshot of the line's tax rate in basis points (e.g. 6.0% -> 600), if the
  /// source item carried one. Nullable; invoice-level taxes still live on
  /// `Invoice.taxes`.
  final int? taxRateBasisPoints;

  final int sortOrder;

  @Property(type: PropertyType.date)
  final DateTime? createdAt;

  @Property(type: PropertyType.date)
  final DateTime? updatedAt;

  InvoiceLine({
    this.id = 0,
    this.sourceItemId,
    required this.name,
    this.description,
    this.unit,
    this.currency,
    required this.unitPriceCents,
    this.quantityMilli = 1000,
    this.taxRateBasisPoints,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    sourceItemId,
    name,
    description,
    unit,
    currency,
    unitPriceCents,
    quantityMilli,
    taxRateBasisPoints,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
