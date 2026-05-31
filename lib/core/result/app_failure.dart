/// The single, typed error vocabulary for the app.
///
/// Thrown inside reactive streams (surfaced as `AsyncError`) and wrapped in
/// [Result] for imperative repository calls. UI matches on the subtype to
/// decide how to present the failure (inline field errors vs snackbar/dialog).
sealed class AppFailure {
  final String message;
  const AppFailure(this.message);

  @override
  String toString() => '$runtimeType($message)';
}

/// User-fixable input problem. [fieldErrors] maps form field keys to messages.
class ValidationFailure extends AppFailure {
  final Map<String, String> fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors = const {}});
}

/// A persistence-layer problem (ObjectBox storage, transactions, etc.).
class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message);
}

/// A unique-index conflict (e.g. duplicate email/phone/invoice number).
class UniqueViolation extends DatabaseFailure {
  final String field;
  const UniqueViolation(this.field)
    : super('A record with this $field already exists');
}

/// A requested record does not exist.
class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// Anything we did not anticipate. Keeps the original [cause] for logging.
class UnexpectedFailure extends AppFailure {
  final Object cause;
  const UnexpectedFailure(this.cause) : super('Something went wrong');
}
