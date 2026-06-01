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

  /// Export the canvas to PNG bytes at the drawing's natural aspect ratio
  /// (white background).
  ///
  /// Renders without forcing a width: passing only `width` stretches the image
  /// horizontally (height stays natural), which makes it shrink badly under
  /// `BoxFit.contain` in the PDF signature box. Natural sizing preserves the
  /// aspect ratio so it fills the box like the legacy points-render path.
  /// Higher-DPI proportional upscaling is a future tweak (see S4 plan).
  ///
  /// Throws [SignatureEmptyFailure] when nothing was drawn and
  /// [SignatureRenderFailure] if the controller can't produce bytes.
  Future<Uint8List> export(SignatureController controller) async {
    if (controller.isEmpty) throw const SignatureEmptyFailure();
    final bytes = await controller.toPngBytes();
    if (bytes == null) throw const SignatureRenderFailure();
    return bytes;
  }
}

final signatureServiceProvider = Provider<SignatureService>(
  (_) => const SignatureService(),
);
