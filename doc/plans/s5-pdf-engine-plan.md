# Sprint S5 — PDF Generation Engine

> **Depends on:** S4 (signature bytes). **Branch:** `s5-pdf-engine`.
> Decomposes the 1,700-line `invoice_generator.dart` (manual pagination
> heuristics, synchronous build, network fonts) into a maintainable, offline,
> off-thread engine. Covers blueprint §10. **No entity changes / no codegen.**

---

## 1. Target structure (`features/invoice/pdf/`)
```
pdf/
├── pdf_invoice_data.dart     # flat DTO the template needs (no DB/Flutter types):
│                             #   business/client snapshot, line items, totals (cents),
│                             #   currency, dates pre-formatted, signature PNG bytes
├── invoice_template.dart     # abstract: pw.Document/List<pw.Widget> build(PdfInvoiceData)
├── templates/
│   └── classic_template.dart # current visual layout, refactored into pw widgets
├── widgets/                  # header, client_block, items_table, totals, terms, signature, footer
├── pdf_engine.dart           # loads bundled fonts; runs template in compute(); returns Uint8List
├── pdf_store.dart            # write bytes to file (path_provider) -> path  [S1 saveInvoice moves here]
└── pdf_sharer.dart           # Printing.sharePdf / layoutPdf                [share/print move here]
```
Providers: `pdfEngineProvider`, `pdfStoreProvider`, `pdfSharerProvider`.

## 2. Key changes (with rationale)
| Change | From → To | Why |
|---|---|---|
| Pagination | manual `estimatedItemsPerPage`/magic thresholds → `pw.MultiPage` | deletes ~400 lines of heuristics; the `pdf` pkg flows content + repeats header/footer |
| Threading | sync build on UI isolate → `await compute(_build, payload)` | no jank on large invoices (R3) |
| Fonts | `PdfGoogleFonts.*` (network) → **bundled TTF** in `assets/fonts/`, loaded once | offline-first (R4); `pubspec.yaml` fonts/asset entry; load inside isolate from rootBundle |
| Data | template reads `Invoice`/relations directly → consumes `PdfInvoiceData` DTO | template has no DB/isolate-unsafe deps; easy to unit/golden test |
| Templates | one giant method → `InvoiceTemplate` strategy | new styles = new class, not edits |
| Caching | rebuild every share/save → cache bytes by `(invoiceId, updatedAt)` | instant re-share; invalidates on edit |

## 3. Isolate boundary
- `compute` payload must be primitives/transferable: pass `PdfInvoiceData`
  (plain fields + `Uint8List` signature/logo) + the template id. Build the
  `InvoiceTemplate` *inside* the isolate from the id (templates are stateless).
- Fonts: load TTF bytes from `rootBundle` inside the isolate (or pass bytes in).

## 4. Migration order
1. Introduce `PdfInvoiceData` + a mapper from `Invoice`/relations (pure). Commit.
2. Port the existing layout into `classic_template.dart` using `pw.MultiPage`
   (visual parity first; keep old generator temporarily). Commit.
3. Add `pdf_engine` (compute + bundled fonts); wire preview/print/share/save to it. Commit.
4. Move `saveInvoice`/`shareInvoice`/`printInvoice` into `pdf_store`/`pdf_sharer`;
   update `invoice_preview_page.dart`. Commit.
5. Delete the old `invoice_generator.dart`. Commit.

## 5. Verification
- **Golden test** for `classic_template` on a representative invoice (1 page) +
  a 100-item invoice (multi-page) — guards visual regressions cheaply.
- Manual: airplane-mode export (fonts offline); 100-item invoice builds without
  UI freeze (frame timeline); signature/logo render; re-share hits cache.
- `flutter analyze lib` clean; `flutter test` green.

## 6. Rollback
- Old generator kept until the final delete commit → revert that commit to restore.
- No data/schema risk.

## 7. Out of scope
- Multiple selectable templates in UI (engine supports it; UI is later).
- Email delivery / cloud storage of PDFs.
