enum ListFilterType { all, active, inactive, defaultStatus }

enum InvoiceListFilterType {
  all,
  draft,
  sent,
  viewed,
  paid,
  overdue,
  cancelled,
  refunded,
}

extension InvoiceListFilterTypeExtension on InvoiceListFilterType {
  String get displayName {
    switch (this) {
      case InvoiceListFilterType.all:
        return 'All';
      case InvoiceListFilterType.draft:
        return 'Draft';
      case InvoiceListFilterType.sent:
        return 'Sent';
      case InvoiceListFilterType.viewed:
        return 'Viewed';
      case InvoiceListFilterType.paid:
        return 'Paid';
      case InvoiceListFilterType.overdue:
        return 'Overdue';
      case InvoiceListFilterType.cancelled:
        return 'Cancelled';
      case InvoiceListFilterType.refunded:
        return 'Refunded';
    }
  }
}
