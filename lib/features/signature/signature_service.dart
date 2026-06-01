import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:signature/signature.dart';

/// Renders signature canvas strokes into a canonical, PDF-ready PNG (ADR-0004).
///
/// S4 scope: produces the white-background PNG the controller already exports
/// at a print-friendly width. Bounding-box trim/flatten (the `image` package)
/// is a deferred storage optimization — see the S4 plan.
class SignatureService {
  const SignatureService();

  /// Export the canvas to PNG bytes (~1000px wide, white background).
  ///
  /// Throws [SignatureEmptyFailure] when nothing was drawn and
  /// [SignatureRenderFailure] if the controller can't produce bytes.
  Future<Uint8List> export(SignatureController controller) async {
    if (controller.isEmpty) throw const SignatureEmptyFailure();
    final bytes = await controller.toPngBytes(width: 1000);
    if (bytes == null) throw const SignatureRenderFailure();
    return bytes;
  }
}

final signatureServiceProvider = Provider<SignatureService>(
  (_) => const SignatureService(),
);
