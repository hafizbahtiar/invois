import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/features/signature/signature_model.dart';
import 'package:invois/features/signature/signature_service.dart';
import 'package:signature/signature.dart' show SignatureController;

void main() {
  group('SignatureService', () {
    test('export throws SignatureEmptyFailure when nothing is drawn', () {
      final controller = SignatureController();
      addTearDown(controller.dispose);
      const service = SignatureService();
      expect(
        () => service.export(controller),
        throwsA(isA<SignatureEmptyFailure>()),
      );
    });
  });

  group('Signature.imageBytes JSON round-trip', () {
    test('base64-encodes and decodes the PNG bytes', () {
      final bytes = Uint8List.fromList([0, 1, 2, 250, 255]);
      final signature = Signature(name: 'A', imageBytes: bytes);
      final restored = Signature.fromJson(signature.toJson());
      expect(restored.imageBytes, equals(bytes));
    });

    test('null imageBytes stays null through JSON', () {
      final signature = Signature(name: 'A');
      final restored = Signature.fromJson(signature.toJson());
      expect(restored.imageBytes, isNull);
    });
  });
}
