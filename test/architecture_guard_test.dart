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

  test('production code has no legacy invoice item schema references', () {
    final violations = <String>[];

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('lib/core/database/objectbox.g.dart'));

    final legacyPatterns = <RegExp, String>{
      RegExp(r'''features/item/item_model\.dart'''): 'imports item_model.dart',
      RegExp(
        r'\bInvoiceLineReader\.(resolveWithLegacyFallback|'
        r'fromInvoiceWithLegacyFallback|'
        r'subtotalCentsWithLegacyFallback)\s*\(',
      ): 'uses legacy fallback',
      RegExp(r'\binvoice\.items\b'): 'reads Invoice.items',
      RegExp(r'\bBox<Item>\b|\bbox<Item>\s*\('): 'opens Item box',
    };

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      for (final entry in legacyPatterns.entries) {
        if (entry.key.hasMatch(content)) {
          violations.add('${file.path} ${entry.value}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Legacy Item schema is retired. Offenders:\n'
          '${violations.join('\n')}',
    );
  });
}
