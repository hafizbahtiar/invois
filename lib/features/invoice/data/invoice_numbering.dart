import 'invoice_model.dart';

/// Parsed parts of a full invoice number: everything before the trailing
/// digits is the prefix scope, the digits are the sequence.
class InvoiceNumberParts {
  final String prefix;
  final int sequence;

  /// Digit count of the sequence as stored (preserved when suggesting the
  /// next number, so `INV-001` is followed by `INV-002`, not `INV-0002`).
  final int width;

  const InvoiceNumberParts({
    required this.prefix,
    required this.sequence,
    required this.width,
  });
}

/// Prefix-aware invoice number suggestion + duplicate checks.
///
/// A "scope" is the text before the trailing digits of a full number
/// (`prefix + invoiceNumber`), compared trimmed and case-insensitively:
/// `INV-0001` and `QUO-0001` count independently, and `INV2026-0001` is its
/// own scope (not part of `INV-`). Numbers without trailing digits (manual
/// one-offs, malformed legacy values) are tolerated and simply skipped.
class InvoiceNumbering {
  /// Scope used when the form's prefix field is empty — the legacy behaviour
  /// where the suggestion carries `INV-` inside the number field itself.
  static const String defaultPrefix = 'INV-';

  static final RegExp _numberPattern = RegExp(r'^(.*?)(\d+)$');

  const InvoiceNumbering._();

  /// Tolerant parse of a full number. Returns null when there are no trailing
  /// digits or the sequence is too large for an int — callers skip such
  /// numbers instead of crashing.
  static InvoiceNumberParts? tryParse(String fullNumber) {
    final match = _numberPattern.firstMatch(fullNumber.trim());
    if (match == null) return null;
    final digits = match.group(2)!;
    final sequence = int.tryParse(digits);
    if (sequence == null) return null;
    return InvoiceNumberParts(
      prefix: match.group(1)!,
      sequence: sequence,
      width: digits.length,
    );
  }

  /// The next sequence (digits only, zero-padded) within the [prefix] scope,
  /// considering only [invoices] whose full number belongs to that scope.
  /// A fresh scope starts at `0001`.
  static String nextSequence(
    Iterable<Invoice> invoices, {
    required String prefix,
  }) {
    final scope = normalize(prefix);
    var maxSequence = 0;
    var width = 4;
    for (final invoice in invoices) {
      final parts = tryParse(fullNumber(invoice));
      if (parts == null || normalize(parts.prefix) != scope) continue;
      if (parts.sequence > maxSequence) {
        maxSequence = parts.sequence;
        width = parts.width;
      }
    }
    return (maxSequence + 1).toString().padLeft(width, '0');
  }

  /// Full suggested number (prefix + next sequence) within the [prefix] scope.
  static String nextNumber(
    Iterable<Invoice> invoices, {
    String prefix = defaultPrefix,
  }) {
    return '$prefix${nextSequence(invoices, prefix: prefix)}';
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
