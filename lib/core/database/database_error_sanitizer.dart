import 'package:flutter/foundation.dart';

const databaseErrorMessage = 'A database error occurred. Please try again.';

/// Logs database internals only in debug builds and returns a stable,
/// user-facing message.
String sanitizeDatabaseError(Object error, {String context = 'Database'}) {
  if (kDebugMode) {
    debugPrint('$context error: $error');
  }
  return databaseErrorMessage;
}
