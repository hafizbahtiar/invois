import 'database_error_sanitizer.dart';

/// A generic response wrapper for ObjectBox database operations.
/// Provides a standard way to handle data, success, and error messages.
///
/// [T] is the type of data returned by the operation.
class ObjectBoxResponse<T> {
  /// The data returned by the operation, if any.
  final T? data;

  /// Whether the operation was successful.
  final bool success;

  /// An optional message, typically for errors or additional info.
  final String? message;

  /// Whether the response is in a loading state.
  final bool loading;

  const ObjectBoxResponse({
    this.data,
    this.success = true,
    this.message,
    this.loading = false,
  });

  /// Creates a successful response with data.
  factory ObjectBoxResponse.success(T data, {String? message}) {
    return ObjectBoxResponse<T>(data: data, success: true, message: message);
  }

  /// Creates a failed response with an optional error message.
  factory ObjectBoxResponse.failure({String? message}) {
    return ObjectBoxResponse<T>(data: null, success: false, message: message);
  }

  /// Creates a response from an exception.
  ///
  /// The raw exception is logged via [debugPrint] (debug mode only) but a
  /// generic message is stored — internal ObjectBox details (store paths,
  /// schema names, query internals) never reach the UI.
  factory ObjectBoxResponse.fromException(Exception e) {
    return ObjectBoxResponse<T>(
      data: null,
      success: false,
      message: sanitizeDatabaseError(e, context: 'ObjectBoxResponse exception'),
    );
  }

  /// Creates an empty response (no data, successful by default).
  factory ObjectBoxResponse.empty({String? message}) {
    return ObjectBoxResponse<T>(data: null, success: true, message: message);
  }

  /// Creates a loading response (useful for async UI states).
  factory ObjectBoxResponse.loading() {
    return ObjectBoxResponse<T>(loading: true, success: false);
  }

  /// Returns true if the response is successful and contains data.
  bool get hasData => success && data != null;

  /// Returns a copy of this response with optional new values.
  ObjectBoxResponse<T> copyWith({
    T? data,
    bool? success,
    String? message,
    bool? loading,
  }) {
    return ObjectBoxResponse<T>(
      data: data ?? this.data,
      success: success ?? this.success,
      message: message ?? this.message,
      loading: loading ?? this.loading,
    );
  }

  /// Maps the data of this response to another type, preserving other fields.
  ObjectBoxResponse<R> map<R>(R Function(T? data) transform) {
    return ObjectBoxResponse<R>(
      data: transform(data),
      success: success,
      message: message,
      loading: loading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectBoxResponse<T> &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          success == other.success &&
          message == other.message &&
          loading == other.loading;

  @override
  int get hashCode => Object.hash(data, success, message, loading);

  @override
  String toString() {
    return 'ObjectBoxResponse<$T>(data: $data, success: $success, message: $message, loading: $loading)';
  }
}
