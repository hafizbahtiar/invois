import 'app_failure.dart';

/// Return type for imperative repository operations.
///
/// Repositories never throw across their boundary; they return [Ok] on success
/// or [Err] carrying an [AppFailure]. Reactive reads use streams + `AsyncValue`
/// instead and do not need [Result].
sealed class Result<T> {
  const Result();

  /// Collapse both branches into a single value.
  R fold<R>(R Function(T value) ok, R Function(AppFailure failure) err);

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value if [Ok], otherwise `null`.
  T? get valueOrNull => fold((v) => v, (_) => null);

  /// The failure if [Err], otherwise `null`.
  AppFailure? get failureOrNull => fold((_) => null, (f) => f);

  /// The value if [Ok], otherwise throws the [AppFailure].
  T orThrow() => fold((v) => v, (f) => throw f);
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);

  @override
  R fold<R>(R Function(T value) ok, R Function(AppFailure failure) err) =>
      ok(value);
}

class Err<T> extends Result<T> {
  final AppFailure failure;
  const Err(this.failure);

  @override
  R fold<R>(R Function(T value) ok, R Function(AppFailure failure) err) =>
      err(failure);
}
