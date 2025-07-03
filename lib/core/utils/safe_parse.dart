import 'dart:convert';

/// A comprehensive utility class for safe parsing with rich dynamic features
class SafeParse {
  const SafeParse._();

  // ==================== STRING PARSING ====================

  /// Safely parse string with fallback
  static String string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely parse string with trimming
  static String stringTrim(dynamic value, {String fallback = ''}) {
    return string(value, fallback: fallback).trim();
  }

  /// Safely parse string with case conversion
  static String stringLower(dynamic value, {String fallback = ''}) {
    return string(value, fallback: fallback).toLowerCase();
  }

  static String stringUpper(dynamic value, {String fallback = ''}) {
    return string(value, fallback: fallback).toUpperCase();
  }

  /// Safely parse string with length validation
  static String stringMaxLength(
    dynamic value,
    int maxLength, {
    String fallback = '',
  }) {
    final str = string(value, fallback: fallback);
    return str.length > maxLength ? str.substring(0, maxLength) : str;
  }

  /// Safely parse string with minimum length validation
  static String? stringMinLength(dynamic value, int minLength) {
    final str = string(value);
    return str.length >= minLength ? str : null;
  }

  // ==================== NUMBER PARSING ====================

  /// Safely parse int with fallback
  static int integer(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? fallback;
    }
    return fallback;
  }

  /// Safely parse double with fallback
  static double decimal(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? fallback;
    }
    return fallback;
  }

  /// Safely parse number with range validation
  static int integerRange(dynamic value, int min, int max, {int fallback = 0}) {
    final num = integer(value, fallback: fallback);
    if (num < min) return min;
    if (num > max) return max;
    return num;
  }

  static double decimalRange(
    dynamic value,
    double min,
    double max, {
    double fallback = 0.0,
  }) {
    final num = decimal(value, fallback: fallback);
    if (num < min) return min;
    if (num > max) return max;
    return num;
  }

  /// Safely parse positive numbers
  static int positiveInteger(dynamic value, {int fallback = 0}) {
    final num = integer(value, fallback: fallback);
    return num > 0 ? num : fallback;
  }

  static double positiveDecimal(dynamic value, {double fallback = 0.0}) {
    final num = decimal(value, fallback: fallback);
    return num > 0 ? num : fallback;
  }

  // ==================== BOOLEAN PARSING ====================

  /// Safely parse boolean with fallback
  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on';
    }
    if (value is int) return value != 0;
    if (value is double) return value != 0.0;
    return fallback;
  }

  // ==================== DATE PARSING ====================

  /// Safely parse DateTime with fallback
  static DateTime? dateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Safely parse DateTime with fallback
  static DateTime dateTimeWithFallback(dynamic value, {DateTime? fallback}) {
    return dateTime(value) ?? fallback ?? DateTime.now();
  }

  /// Safely parse date string in specific format
  static DateTime? dateTimeFormat(dynamic value, String format) {
    if (value == null || value is! String) return null;
    try {
      // Basic format support - you can extend this
      switch (format.toLowerCase()) {
        case 'iso':
        case 'iso8601':
          return DateTime.parse(value);
        case 'unix':
        case 'timestamp':
          final timestamp = int.tryParse(value);
          return timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : null;
        default:
          return DateTime.parse(value);
      }
    } catch (e) {
      return null;
    }
  }

  // ==================== LIST PARSING ====================

  /// Safely parse list with fallback
  static List<T> list<T>(
    dynamic value,
    T Function(dynamic) converter, {
    List<T> fallback = const [],
  }) {
    if (value == null) return fallback;
    if (value is List) {
      try {
        return value.map((item) => converter(item)).toList();
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  /// Safely parse string list
  static List<String> stringList(
    dynamic value, {
    List<String> fallback = const [],
  }) {
    return list(value, (item) => string(item), fallback: fallback);
  }

  /// Safely parse int list
  static List<int> integerList(dynamic value, {List<int> fallback = const []}) {
    return list(value, (item) => integer(item), fallback: fallback);
  }

  /// Safely parse double list
  static List<double> decimalList(
    dynamic value, {
    List<double> fallback = const [],
  }) {
    return list(value, (item) => decimal(item), fallback: fallback);
  }

  // ==================== MAP PARSING ====================

  /// Safely parse map with fallback
  static Map<String, dynamic> map(
    dynamic value, {
    Map<String, dynamic> fallback = const {},
  }) {
    if (value == null) return fallback;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  /// Safely parse map with type conversion
  static Map<K, V> mapTyped<K, V>(
    dynamic value,
    K Function(dynamic) keyConverter,
    V Function(dynamic) valueConverter, {
    Map<K, V> fallback = const {},
  }) {
    if (value == null) return fallback;
    if (value is Map) {
      try {
        return Map.fromEntries(
          value.entries.map(
            (entry) =>
                MapEntry(keyConverter(entry.key), valueConverter(entry.value)),
          ),
        );
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  // ==================== JSON PARSING ====================

  /// Safely parse JSON string
  static Map<String, dynamic>? json(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Safely parse JSON string with fallback
  static Map<String, dynamic> jsonWithFallback(
    dynamic value, {
    Map<String, dynamic> fallback = const {},
  }) {
    return json(value) ?? fallback;
  }

  // ==================== ENUM PARSING ====================

  /// Safely parse enum from string
  static T? enumFromString<T>(List<T> values, dynamic value) {
    if (value == null) return null;
    final stringValue = string(value).toLowerCase();
    for (final enumValue in values) {
      if (enumValue.toString().split('.').last.toLowerCase() == stringValue) {
        return enumValue;
      }
    }
    return null;
  }

  /// Safely parse enum with fallback
  static T enumWithFallback<T>(List<T> values, dynamic value, T fallback) {
    return enumFromString(values, value) ?? fallback;
  }

  // ==================== VALIDATION HELPERS ====================

  /// Check if value is not null and not empty string
  static bool isNotEmpty(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  /// Check if value is null or empty
  static bool isEmpty(dynamic value) {
    return !isNotEmpty(value);
  }

  /// Check if value is numeric
  static bool isNumeric(dynamic value) {
    if (value == null) return false;
    if (value is num) return true;
    if (value is String) {
      return double.tryParse(value) != null;
    }
    return false;
  }

  /// Check if value is valid email
  static bool isEmail(dynamic value) {
    if (value == null || value is! String) return false;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(value);
  }

  /// Check if value is valid phone number
  static bool isPhone(dynamic value) {
    if (value == null || value is! String) return false;
    final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{0,15}$');
    return phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  // ==================== TRANSFORMATION HELPERS ====================

  /// Transform value if not null
  static T? transform<T>(dynamic value, T Function(dynamic) transformer) {
    if (value == null) return null;
    try {
      return transformer(value);
    } catch (e) {
      return null;
    }
  }

  /// Transform value with fallback
  static T transformWithFallback<T>(
    dynamic value,
    T Function(dynamic) transformer,
    T fallback,
  ) {
    return transform(value, transformer) ?? fallback;
  }

  /// Chain multiple transformations
  static T? chain<T>(dynamic value, List<T Function(dynamic)> transformers) {
    dynamic current = value;
    for (final transformer in transformers) {
      current = transform(current, transformer);
      if (current == null) return null;
    }
    return current as T;
  }
}
