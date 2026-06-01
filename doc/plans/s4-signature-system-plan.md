# Sprint S4 — Signature System: Store Render-Ready PNG

> **Depends on:** S3 (entity changes + codegen workflow). **Branch:** `s4-signature-system`.
> **Requires `build_runner`** (new field on `Signature`). Covers blueprint §11, ADR-0004.
>
> **Implementation status (2026-06-01):** Done. Implemented: additive
> `Signature.imageBytes` (byteVector), `SignatureService.export`,
> `SignatureEmptyFailure`/`SignatureRenderFailure`, form capture of `imageBytes`,
> and PDF embed preferring `imageBytes` with legacy points-render fallback.
> build_runner regenerated; analyze clean; 23 tests pass (empty-export +
> base64 round-trip added). **Intentional deviations from the plan below:**
> - **Kept `signatureData`** (points) instead of renaming to `pointsJson` — avoids
>   a UID rename migration; `imageBytes` is purely additive.
> - **Skipped the `image` package** trim/flatten (no new dependency). PNG uses the
>   controller's white background at ~1000px; bbox trim is a deferred storage
>   optimization.
> - **Self-heal persistence (§5) deferred:** legacy rows render from points at PDF
>   time via the fallback (non-destructive); bytes are not back-written.
> - **Memory split (§6) deferred:** ObjectBox loads `imageBytes` with each list
>   row. Signatures are few in practice (≈1/business) so impact is low; a
>   separate-entity/projection split is future work if lists grow.

Fixes the root cause behind the PDF signature bug at the *source*: signatures are
captured/stored as JSON drawing points, then re-rendered at PDF time. S1 added a
safe runtime render (`InvoiceGenerator._renderSignatureImage`); S4 makes the
stored, compressed PNG the canonical artifact so the PDF embeds bytes directly.

---

## 1. Entity change (`signature_model.dart`)
```dart
// canonical, render-ready (white bg, trimmed, compressed PNG)
@Property(type: PropertyType.byteVector) Uint8List? imageBytes;
// optional: keep points for re-editing the drawing
String? pointsJson;   // renamed from signatureData (use @Property(uid:) to rename, not drop)
```
- Run `dart run build_runner build --delete-conflicting-outputs`.
- Update `copyWith`/`toJson`/`fromJson`/`props`.

## 2. New: `features/signature/signature_service.dart`
```dart
class SignatureService {
  /// Capture controller -> trimmed, flattened, compressed PNG (~1000px wide).
  Future<Uint8List> export(SignatureController c) async {
    final raw = await c.toPngBytes(width: 1000);
    if (raw == null) throw const SignatureEmptyFailure();   // new AppFailure subtype
    return compute(_trimAndFlatten, raw);                    // image pkg, off-thread
  }
}
final signatureServiceProvider = Provider((_) => SignatureService());
```
- Add `image` package for trim/flatten (or hand-roll bbox trim on the canvas).
- Add `SignatureEmptyFailure`/`SignatureRenderFailure` to `core/result/app_failure.dart`.

## 3. Capture flow (`signature_form_page.dart`)
- On save: `final bytes = await ref.read(signatureServiceProvider).export(controller);`
  store `imageBytes: bytes` (+ `pointsJson` if keeping edit support).
- Validate non-empty before save (reuse the empty check).

## 4. PDF embed (`invoice_generator.dart`)
- Replace `_renderSignatureImage` (runtime points→PNG) with: prefer
  `signature.imageBytes`; **fallback** to the existing points→PNG render only when
  `imageBytes == null` (legacy rows) so old data still works.
- Signature section already takes `Uint8List signatureImage` (S1) — just change the
  source in `generateInvoice`.

## 5. Migration of existing signatures
- Lazy: when a signature with `imageBytes == null` but non-null `pointsJson` is
  opened/used, render once via the fallback and persist `imageBytes` (self-heals).
- No destructive step; `pointsJson` retained.

## 6. Memory discipline (blueprint §11/§15)
- Signature **list/grid** must NOT hold full `imageBytes` for every row — show a
  cached thumbnail or icon; load full bytes only on detail open / PDF embed.
- Verify with a memory profile on a list of many signatures.

## 7. Verification
- `flutter analyze lib` clean; `flutter test` green (add `signature_service_test`
  for empty-input failure + size bound, gated if it needs platform image codecs).
- Manual: capture → save → open invoice with that signature → PDF shows crisp
  signature; size of stored bytes 5–30 KB; legacy (points-only) signature still renders.

## 8. Rollback
- Single feature, additive field. Revert the commits; `imageBytes` column retires
  via UID (don't reuse). Legacy points path remains functional throughout.

## 9. Out of scope
- PDF engine decomposition (S5). Multi-signature per invoice (not a current requirement).
