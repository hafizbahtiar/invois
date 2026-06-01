import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The invoice PDF font set, loaded from bundled assets (offline-first, R4).
///
/// Replaces `PdfGoogleFonts.*`, which fetched fonts over the network and failed
/// offline. Loaded once and cached for the process lifetime.
class PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;

  const PdfFonts({
    required this.regular,
    required this.bold,
    required this.italic,
  });
}

PdfFonts? _cached;

/// Loads the bundled Nunito faces. Cached after the first call.
Future<PdfFonts> loadInvoiceFonts() async {
  final cached = _cached;
  if (cached != null) return cached;
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Nunito-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Nunito-Bold.ttf'),
  );
  final italic = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Nunito-Italic.ttf'),
  );
  return _cached = PdfFonts(regular: regular, bold: bold, italic: italic);
}
