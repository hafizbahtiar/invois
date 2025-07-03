import 'package:intl/intl.dart';

class NumberUtils {
  const NumberUtils._();

  /// Format a number as currency (with thousands separator, decimal places)
  static String formatCurrency(
    double value, {
    int decimalPlaces = 2,
    String? locale,
  }) {
    final format = NumberFormat.currency(
      symbol: '',
      decimalDigits: decimalPlaces,
      locale: locale,
    );
    return format.format(value).trim();
  }

  /// Format a number as decimal (with thousands separator, decimal places)
  static String formatDecimal(
    double value, {
    int decimalPlaces = 2,
    String? locale,
  }) {
    final format = NumberFormat.decimalPattern(locale);
    return format.format(double.parse(value.toStringAsFixed(decimalPlaces)));
  }

  /// Format an integer with thousands separator
  static String formatInteger(int value, {String? locale}) {
    final format = NumberFormat.decimalPattern(locale);
    return format.format(value);
  }

  /// Parse a formatted number string to double
  static double? parseNumber(String value, {String? locale}) {
    try {
      final format = NumberFormat.decimalPattern(locale);
      return format.parse(value).toDouble();
    } catch (_) {
      return double.tryParse(value.replaceAll(',', ''));
    }
  }
}
