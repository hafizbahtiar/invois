import 'invoice_line_math.dart';

/// Typed result of parsing a user-entered quantity string. Non-throwing.
class QuantityParseResult {
  /// Parsed quantity in thousandths (`1000 == 1.000`), or null on failure.
  final int? quantityMilli;

  /// Short, user-friendly message when invalid, else null.
  final String? error;

  const QuantityParseResult._(this.quantityMilli, this.error);

  factory QuantityParseResult.success(int quantityMilli) =>
      QuantityParseResult._(quantityMilli, null);

  factory QuantityParseResult.failure(String error) =>
      QuantityParseResult._(null, error);

  bool get isValid => quantityMilli != null;
}

/// Pure parser/formatter bridging the form's quantity text field and the
/// integer `quantityMilli` spine. No Flutter/ObjectBox deps.
///
/// Rules (documented + tested):
/// - Dot decimal only; comma is **rejected** (locale ambiguity).
/// - Up to **3** decimal places; more is **rejected** (not rounded, for clarity).
/// - Minimum 0.001 (`quantityMilli >= 1`); no maximum imposed.
/// - Leading/trailing zeros are fine (`001.500` -> 1500); whitespace is trimmed.
/// - Leading-dot allowed (`.5` -> 500); a trailing dot (`1.`), bare dots
///   (`.`, `..`), empty, zero, negative, and non-numeric are **rejected**.
class InvoiceQuantityInput {
  const InvoiceQuantityInput._();

  // Optional integer part, then optionally a dot followed by 1+ digits.
  // Requires at least the integer part OR a fractional part to be non-empty,
  // which is enforced after matching (rejects "", ".", "1.").
  static final RegExp _pattern = RegExp(r'^(\d*)(?:\.(\d+))?$');

  static QuantityParseResult parse(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) {
      return QuantityParseResult.failure('Enter a quantity');
    }
    if (cleaned.contains(',')) {
      return QuantityParseResult.failure('Use a dot (.) for decimals');
    }

    final match = _pattern.firstMatch(cleaned);
    if (match == null) {
      return QuantityParseResult.failure('Enter a valid number');
    }

    final wholeStr = match.group(1) ?? '';
    final fracStr = match.group(2); // null when no decimal part

    // Rejects "." / "1." (no usable digits / trailing dot).
    if (wholeStr.isEmpty && (fracStr == null || fracStr.isEmpty)) {
      return QuantityParseResult.failure('Enter a valid number');
    }
    if (fracStr != null && fracStr.length > 3) {
      return QuantityParseResult.failure('Use at most 3 decimal places');
    }

    final whole = wholeStr.isEmpty ? 0 : int.parse(wholeStr);
    final milliFrac = int.parse('${fracStr ?? ''}000'.substring(0, 3));
    final quantityMilli = whole * InvoiceLineMath.milliPerUnit + milliFrac;

    if (quantityMilli <= 0) {
      return QuantityParseResult.failure('Quantity must be greater than 0');
    }
    return QuantityParseResult.success(quantityMilli);
  }

  /// `quantityMilli` -> clean decimal string (`1000 -> "1"`, `1500 -> "1.5"`,
  /// `1 -> "0.001"`). Reuses [InvoiceLineMath.formatQuantity].
  static String format(int quantityMilli) =>
      InvoiceLineMath.formatQuantity(quantityMilli);
}
