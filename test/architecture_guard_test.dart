@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the blueprint §18 layering anti-patterns as a cheap CI guard.
///
/// Presentation code must depend on repositories (which expose Result / Stream),
/// never reach into a feature's `data/` layer or touch ObjectBox directly. This
/// test fails the build if a regression reintroduces those imports.
void main() {
  final featuresDir = Directory('lib/features');

  test('presentation layers do not import data/ or ObjectBox', () {
    final violations = <String>[];

    final presentationFiles = featuresDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.path.contains('/presentation/'));

    final forbidden = <RegExp, String>{
      RegExp(r'''import\s+['"][^'"]*/data/'''): 'imports a feature data/ layer',
      RegExp(r'objectbox\.g\.dart'): 'imports the ObjectBox generated bindings',
      RegExp(r'''import\s+['"]package:objectbox/'''): 'imports package:objectbox',
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
      reason: 'Presentation must go through repositories. Offenders:\n'
          '${violations.join('\n')}',
    );
  });
}
