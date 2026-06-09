@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the blueprint §18 layering anti-patterns as a cheap CI guard.
///
/// Presentation code must go through providers/repositories, never reach into a
/// feature's local data source or touch ObjectBox directly. (Importing the
/// entity model or the query filter type from `data/` is fine — those are the
/// shared types presentation renders.) This test fails the build if a
/// regression reintroduces a forbidden import.
void main() {
  final featuresDir = Directory('lib/features');
  final libDir = Directory('lib');

  test('presentation layers do not import a local source or ObjectBox', () {
    final violations = <String>[];

    final presentationFiles = featuresDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.path.contains('/presentation/'));

    final forbidden = <RegExp, String>{
      RegExp(r'''import\s+['"][^'"]*_local_source\.dart'''):
          'imports a feature local data source',
      RegExp(r'objectbox\.g\.dart'): 'imports the ObjectBox generated bindings',
      RegExp(r'''import\s+['"]package:objectbox/'''):
          'imports package:objectbox',
    };

    for (final file in presentationFiles) {
      final content = file.readAsStringSync();
      for (final entry in forbidden.entries) {
        if (entry.key.hasMatch(content)) {
          violations.add('${file.path} ${entry.value}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Presentation must go through repositories. Offenders:\n'
          '${violations.join('\n')}',
    );
  });

  test(
    'production code does not call legacy invoice item fallback readers',
    () {
      final violations = <String>[];

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('lib/features/invoice/invoice_line_view.dart'),
          );

      final fallbackCalls = RegExp(
        r'InvoiceLineReader\.(resolveWithLegacyFallback|'
        r'fromInvoiceWithLegacyFallback|'
        r'subtotalCentsWithLegacyFallback)\s*\(',
      );

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (fallbackCalls.hasMatch(content)) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Production reads must stay line-only. Legacy fallback readers '
            'are reserved for migration/recovery tests and helpers.\n'
            'Offenders:\n${violations.join('\n')}',
      );
    },
  );
}
