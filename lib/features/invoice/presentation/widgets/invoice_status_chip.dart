import 'package:flutter/material.dart';

import '../../data/invoice_model.dart';

/// Single source of truth for invoice-status colour + label.
///
/// Replaces the `_getStatusColor` switch blocks that were duplicated across
/// `home_page.dart` and the (now removed) `invoice_list_page.dart`. Parsing is
/// done safely via [InvoiceStatusExtension.fromName], so a null/legacy status
/// renders as Draft instead of throwing.
class InvoiceStatusChip extends StatelessWidget {
  /// Raw stored status name (e.g. `invoice.status`). May be null/empty/legacy.
  final String? statusName;

  const InvoiceStatusChip({super.key, required this.statusName});

  @override
  Widget build(BuildContext context) {
    final status = InvoiceStatusExtension.fromName(statusName);
    final color = colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Semantic colour for an [InvoiceStatus]. Kept as a static helper so callers
  /// that need just the colour (e.g. status dots) share the same mapping.
  static Color colorFor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.viewed:
        return Colors.orange;
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.red.shade700;
      case InvoiceStatus.refunded:
        return Colors.purple;
    }
  }

  /// Colour for a raw stored status name (safe-parsed).
  static Color colorForName(String? statusName) =>
      colorFor(InvoiceStatusExtension.fromName(statusName));
}
