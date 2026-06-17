import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/database/objectbox_response.dart';

/// Tests for [ObjectBoxResponse.fromException] error sanitization.
///
/// The factory must return a generic message that does NOT contain internal
/// exception details. The raw error is logged via debugPrint — never exposed
/// in the response message that reaches the UI.
void main() {
  group('ObjectBoxResponse.fromException', () {
    test('returns a failure response', () {
      final response = ObjectBoxResponse<int>.fromException(
        Exception('ObjectBox error: /data/user/0/app/files/data.mdb'),
      );
      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('returns a generic message — does not leak the exception string',
        () {
      final response = ObjectBoxResponse<String>.fromException(
        Exception('UniqueViolationException on Invoice_.invoiceNumber'),
      );
      expect(response.message, 'A database error occurred. Please try again.');
      expect(response.message, isNot(contains('UniqueViolation')));
      expect(response.message, isNot(contains('Invoice_')));
    });

    test('does not leak filesystem paths', () {
      final response = ObjectBoxResponse<int>.fromException(
        Exception('store at /Users/hafiz/Documents/app/data.mdb'),
      );
      expect(response.message, isNot(contains('Users/hafiz')));
      expect(response.message, isNot(contains('data.mdb')));
    });

    test('does not leak stack trace fragments', () {
      final response = ObjectBoxResponse<int>.fromException(
        Exception('objectbox.g.dart:123: Box<Invoice>.put failed'),
      );
      expect(response.message, isNot(contains('objectbox.g.dart')));
      expect(response.message, isNot(contains('Box<Invoice>')));
    });

    test('returns the same constant message for different exceptions', () {
      final a = ObjectBoxResponse<int>.fromException(Exception('a')).message;
      final b = ObjectBoxResponse<int>.fromException(Exception('b')).message;
      final c =
          ObjectBoxResponse<String>.fromException(Exception('c')).message;
      expect(a, equals(b));
      expect(b, equals(c));
    });

    test('does not throw on any exception', () {
      expect(
        () => ObjectBoxResponse<int>.fromException(Exception('test')),
        returnsNormally,
      );
      expect(
        () => ObjectBoxResponse<int>.fromException(
          FormatException('bad format'),
        ),
        returnsNormally,
      );
    });
  });
}