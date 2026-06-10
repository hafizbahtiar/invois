import 'package:objectbox/objectbox.dart';

import '../result/app_failure.dart';

/// The single place that converts a thrown exception into a typed [AppFailure].
///
/// Repositories call this in their `catch` blocks so the rest of the app only
/// ever deals with [AppFailure] subtypes, never raw exceptions.
AppFailure mapException(Object error) {
  if (error is AppFailure) return error;
  if (error is UniqueViolationException) {
    return UniqueViolation(_fieldFromUnique(error.toString()));
  }
  if (error is ObjectBoxException) {
    return DatabaseFailure(error.toString());
  }
  return UnexpectedFailure(error);
}

/// Best-effort extraction of the conflicting field name from ObjectBox's
/// unique-violation message. Falls back to a generic label.
String _fieldFromUnique(String message) {
  final match = RegExp(r'property "?(\w+)"?').firstMatch(message);
  return match?.group(1) ?? 'value';
}
