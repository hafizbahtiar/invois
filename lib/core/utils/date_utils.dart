import 'package:intl/intl.dart';

class DateUtils {
  const DateUtils._();

  /// Format a DateTime to a string with a given pattern
  static String format(
    DateTime date, {
    String pattern = 'yyyy-MM-dd',
    String? locale,
  }) {
    final formatter = DateFormat(pattern, locale);
    return formatter.format(date);
  }

  /// Format a DateTime to a readable date (e.g., Jan 1, 2024)
  static String formatReadable(DateTime date, {String? locale}) {
    final formatter = DateFormat.yMMMd(locale);
    return formatter.format(date);
  }

  /// Format a DateTime to a readable date and time (e.g., Jan 1, 2024, 10:00 AM)
  static String formatReadableWithTime(DateTime date, {String? locale}) {
    final formatter = DateFormat.yMMMd(locale).add_jm();
    return formatter.format(date);
  }

  /// Parse a string to DateTime with a given pattern
  static DateTime? parse(
    String value, {
    String pattern = 'yyyy-MM-dd',
    String? locale,
  }) {
    try {
      final formatter = DateFormat(pattern, locale);
      return formatter.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Parse ISO8601 string to DateTime
  static DateTime? parseIso(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}
