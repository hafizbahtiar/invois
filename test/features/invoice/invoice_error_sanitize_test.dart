import 'package:flutter_test/flutter_test.dart';
import 'package:invois/features/invoice/data/invoice_local_source.dart';

/// Tests for [InvoiceLocalSource.sanitizeError].
///
/// The method must return a generic message that does NOT contain internal
/// exception details (store paths, schema names, query internals, stack
/// traces). The raw error is logged via debugPrint — never exposed to the UI.
void main() {
  group('InvoiceLocalSource.sanitizeError', () {
    test('returns a generic message for an Exception', () {
      final result = InvoiceLocalSource.sanitizeError(
        Exception('ObjectBox error: /data/user/0/app/com.example/files/data.mdb'),
      );
      expect(result, 'A database error occurred. Please try again.');
    });

    test('returns a generic message for an Error', () {
      final result = InvoiceLocalSource.sanitizeError(
        StateError('Bad state: Box<Invoice> not found'),
      );
      expect(result, 'A database error occurred. Please try again.');
    });

    test('returns a generic message for a String', () {
      final result = InvoiceLocalSource.sanitizeError('some string error');
      expect(result, 'A database error occurred. Please try again.');
    });

    test('does not leak internal paths in the returned message', () {
      final result = InvoiceLocalSource.sanitizeError(
        Exception('store at /Users/hafiz/Documents/app/data.mdb'),
      );
      expect(result, contains('database error'), reason: 'should be generic');
      expect(result, isNot(contains('data.mdb')));
      expect(result, isNot(contains('Users/hafiz')));
    });

    test('does not leak schema/class names in the returned message', () {
      final result = InvoiceLocalSource.sanitizeError(
        Exception('UniqueViolationException on Invoice_.invoiceNumber'),
      );
      expect(result, isNot(contains('Invoice_')));
      expect(result, isNot(contains('UniqueViolation')));
    });

    test('does not leak stack trace fragments in the returned message', () {
      final result = InvoiceLocalSource.sanitizeError(
        Exception('objectbox.g.dart:123: Box<Invoice>.put failed'),
      );
      expect(result, isNot(contains('objectbox.g.dart')));
      expect(result, isNot(contains('Box<Invoice>')));
    });

    test('always returns the same constant message regardless of input', () {
      final a = InvoiceLocalSource.sanitizeError(Exception('a'));
      final b = InvoiceLocalSource.sanitizeError(Exception('b'));
      final c = InvoiceLocalSource.sanitizeError(StateError('c'));
      expect(a, equals(b));
      expect(b, equals(c));
    });

    test('does not throw on any input type', () {
      expect(() => InvoiceLocalSource.sanitizeError(42), returnsNormally);
      expect(() => InvoiceLocalSource.sanitizeError(<String>[]), returnsNormally);
      expect(() => InvoiceLocalSource.sanitizeError(Object()), returnsNormally);
    });
  });
}