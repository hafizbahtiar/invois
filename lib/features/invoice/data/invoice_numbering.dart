import 'invoice_model.dart';

class InvoiceNumbering {
  static final RegExp _sequencePattern = RegExp(r'^INV-(\d{4,})$');

  const InvoiceNumbering._();

  static String nextNumber(Iterable<Invoice> invoices) {
    var maxSequence = 0;
    for (final invoice in invoices) {
      final match = _sequencePattern.firstMatch(fullNumber(invoice).trim());
      if (match == null) continue;

      final sequence = int.tryParse(match.group(1)!);
      if (sequence != null && sequence > maxSequence) {
        maxSequence = sequence;
      }
    }

    return 'INV-${(maxSequence + 1).toString().padLeft(4, '0')}';
  }

  static bool isAvailable({
    required Iterable<Invoice> invoices,
    required String invoiceNumber,
    int? excludingInvoiceId,
  }) {
    final normalized = normalize(invoiceNumber);
    return !invoices.any((invoice) {
      if (excludingInvoiceId != null && invoice.id == excludingInvoiceId) {
        return false;
      }
      return normalize(fullNumber(invoice)) == normalized;
    });
  }

  static String fullNumber(Invoice invoice) {
    return '${invoice.invoiceNumberPrefix ?? ''}${invoice.invoiceNumber}';
  }

  static String normalize(String value) {
    return value.trim().toUpperCase();
  }
}
