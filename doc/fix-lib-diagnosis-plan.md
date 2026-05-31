# Fix `lib` — Diagnosis, Plan & Technical Spec

> Status: Phase 1 (spec). Engineering pass on 2026-05-31.
> Scope: targeted correctness/security fixes in `lib/` for the Invois Flutter app
> (Riverpod + ObjectBox + PDF/signature). Keep changes scoped; follow existing
> patterns; no architecture rewrites.

## 0. Environment / tooling

- Flutter & Dart **are available** at `~/flutter/bin` (`/Users/hafiz/flutter/bin/{flutter,dart}`).
  Issue #8's "tooling missing from PATH" is resolved by using the absolute path.
- Pre-existing uncommitted user changes (must **not** be reverted):
  - `pubspec.yaml` — removed the `assets/icons/` asset entry.
  - `pubspec.lock` — corresponding lock churn.
  - Untracked `CLAUDE.md` (added earlier this session).
- Verification commands (Phase 6):
  - `~/flutter/bin/flutter analyze lib`
  - `~/flutter/bin/flutter test`
  - `~/flutter/bin/flutter pub outdated`
  - `dart pub audit` if available (else manual review of `flutter pub outdated`)

## 1. Problem summary

| # | Area | Defect | Risk |
|---|------|--------|------|
| 1 | `invoice_form_repository.dart` | `deleteInvoice` calls `deleteInvoiceById` **twice**; 2nd call returns `false` (row already gone) → UI may report failure for a successful delete. Error text wrongly says "business". | Medium — false failures |
| 2 | `invoice_generator.dart` + signature files | Signature stored as **JSON drawing points**, but the PDF embeds it via `Uint8List.fromList(signatureData.codeUnits)` as if PNG bytes → invalid image, can break PDF generation when a signature exists. | High — PDF crash/garbage |
| 3 | `objectbox_database.dart` | PII (business/client/addresses/invoices/signatures) stored **unencrypted** at rest. | High — but see §2 feasibility |
| 4 | `invoice_form_provider.dart` | `onUpsert` force-unwraps `state.business!` / `state.client!` → null crash. | High — crash on save |
| 5 | `invoice_form_provider.dart` | Taxes/terms cleared **only when the new list is non-empty** → removing all taxes/terms leaves stale relations. | Medium — wrong data |
| 6 | business/client/signature models + forms | Optional `@Unique()` fields (email/phone) save **`""`** instead of `null` → second blank record collides on the unique index. | Medium — second record fails to save |
| 7 | `invoice_generator.dart` + preview page | `saveInvoice` identical to `shareInvoice` (`Printing.sharePdf`) yet UI claims "Invoice saved successfully!". | Low — misleading UX |
| 8 | tooling | `flutter`/`dart` not on PATH previously. | Resolved (see §0) |

## 2. Encryption feasibility (issue #3) — important finding

The user selected **"Implement encryption now."** Investigation shows this is
**not feasible with the current dependency**:

- `objectbox: 2.5.1` — the `Store` constructor / `openStore` expose **no cipher
  key / encryption parameter** (constructor args: `directory, maxDBSizeInKB,
  maxDataSizeInKB, fileMode, maxReaders, debugFlags, queriesCaseSensitiveDefault,
  macosApplicationGroup` — none for encryption).
- The bundled native lib (`objectbox_flutter_libs: 2.5.1`) `OBXFeature` enum has
  **no encryption feature**; there is no cipher/encryption C API.
- ObjectBox **data-at-rest encryption is a commercial-edition feature** shipping a
  *different* native library (license required). It cannot be enabled by code
  changes alone with the current open-source `objectbox_flutter_libs`.

**Decision for this phase:** encryption is **deferred** (blocked by package edition),
not silently skipped. We will:
1. Add a documented risk + actionable `TODO(security)` in `objectbox_database.dart`.
2. Record the concrete future plan here so it can be picked up later.

**Future encryption plan (out of scope to implement now):**
- Acquire ObjectBox encryption edition (commercial native libs).
- Add `flutter_secure_storage` to hold a 256-bit random key (generated once per
  install) in Keychain/Keystore.
- Pass the key to the store on open (encrypted-edition API).
- Migration: an existing unencrypted store cannot be opened with a key → requires a
  one-time **export → wipe → re-import** migration or accepting data loss on
  upgrade. Destructive; must be designed deliberately.

> If the commercial edition + migration is desired, that is a separate, larger work
> item and should be scheduled on its own.

## 3. Phased implementation plan

### Phase 2 — Low-risk correctness fixes
- **#1 delete double-call**: in `InvoiceFormRepository.deleteInvoice`, remove the
  redundant first `deleteInvoiceById` call; keep one; fix message to
  `'Failed to delete invoice'`.
- **#4 null guard on upsert**: in `InvoiceFormNotifier.onUpsert`, validate
  `state.business` and `state.client` non-null **before** building the invoice. On
  failure: set `isLoading: false`, `error: <readable message>`, return
  `ObjectBoxResponse.failure(message: ...)`. No force-unwrap.
- **#5 taxes/terms clearing**: always `clearTaxesFromInvoice` /
  `clearTermsFromInvoice` for the saved invoice, then add selected ones only if the
  list is non-empty (mirror the items pattern which already always clears first).
- **#6 normalize blank optional fields**: at form submit, convert blank/whitespace
  optional text to `null` before constructing the model. Minimum: the `@Unique()`
  optional fields — Business `email`/`phone`, Client `email`, Signature
  `email`/`phone`. Apply consistently to other optional strings too.
  - Add a small shared helper `nullIfBlank(String)` in `lib/core/utils/` and use it
    in the three form pages.
  - **No ObjectBox model/annotation changes** → **no codegen required.**

### Phase 3 — Signature → PDF rendering (#2)
- Root cause: `signatureData` holds JSON points (`[{dx,dy,type,pressure}...]`), not
  image bytes. The signature-section builders decode it as raw bytes.
- Fix (chosen — **render points → PNG in the generator**):
  - Add `static Future<Uint8List?> _renderSignatureImage(Signature signature)` that:
    1. Returns `null` if `signatureData` is null/empty.
    2. `jsonDecode`s the points, rebuilds a `signature_lib.SignatureController`,
       sets `.points`, and `await controller.toPngBytes(...)`.
    3. Wraps everything in `try/catch` → returns `null` on any failure (covers
       legacy/non-JSON/corrupt data **gracefully**: no image instead of a crash).
  - Compute the PNG **once** in `generateInvoice`
    (`final sigImg = await _renderSignatureImage(signature)`).
  - Change the signature-section builders to accept a decoded `Uint8List
    signatureImage` and embed via `pw.MemoryImage(signatureImage)`.
  - Gate all signature rendering on `signature != null && sigImg != null` (replaces
    the `signature.signatureData != null` checks in single- and multi-page paths).
- Rationale: preserves edit capability (points remain the stored format, form page
  unchanged), needs **no DB migration**, handles existing stored JSON correctly.

### Phase 4 — Save vs Share (#7)
- Chosen behavior: **real file save with truthful path** (Share stays as-is).
- `InvoiceGenerator.saveInvoice` → returns `Future<String>` (saved file path):
  - `dir = await getDownloadsDirectory()` (desktop) `?? await getApplicationDocumentsDirectory()`.
  - Write bytes to `'<dir>/<prefix><number>.pdf'` via `File.writeAsBytes`.
  - Return the absolute path. Guard platform via try/catch; on unsupported
    platforms (web), fall back to `Printing.sharePdf` and signal via the message.
  - `path_provider` is already a dependency.
- `invoice_preview_page._saveInvoice`: show the returned path in the snackbar
  (`'Saved to <path>'`) instead of the generic "saved successfully!".

### Phase 5 — Security / dependency audit
- `~/flutter/bin/flutter pub outdated` — review, **no blind major upgrades**.
- `dart pub audit` equivalent if available.
- Encryption: document-only this phase (see §2).

### Phase 6 — Verification & report
- `~/flutter/bin/flutter analyze lib`
- `~/flutter/bin/flutter test`
- Summarize changed files + behavior; list anything blocked.

## 4. Files to change

| File | Change | Codegen? |
|------|--------|----------|
| `lib/features/invoice/invoice_form_repository.dart` | #1 delete single-call + message | no |
| `lib/features/invoice/invoice_form_provider.dart` | #4 null guard, #5 always-clear taxes/terms | no |
| `lib/core/utils/string_utils.dart` (new) | `nullIfBlank` helper | no |
| `lib/features/business/business_form_page.dart` | #6 normalize email/phone (+optionals) | no |
| `lib/features/client/client_form_page.dart` | #6 normalize email (+optionals) | no |
| `lib/features/signature/signature_form_page.dart` | #6 normalize email/phone (+optionals) | no |
| `lib/features/invoice/invoice_generator.dart` | #2 render signature PNG; #7 real save | no |
| `lib/features/invoice/invoice_preview_page.dart` | #7 show saved path | no |
| `lib/core/database/objectbox_database.dart` | #3 risk note + TODO | no |

> **No ObjectBox `@Entity` annotations are modified**, so `build_runner` /
> `objectbox.g.dart` regeneration is **not required** for any fix here.

## 5. Expected behavior after fixes

1. Deleting an invoice reports success when the row is removed; failure text is
   invoice-specific.
2. Invoices with signatures generate a valid PDF showing the rendered signature;
   invoices with blank/corrupt signature data generate a PDF with no signature
   image (no crash).
3. DB remains unencrypted **but** the risk and remediation path are documented in
   code and this spec.
4. Saving an invoice with no business/client selected shows a readable error
   instead of crashing.
5. Removing all taxes/terms persists (the invoice ends up with none).
6. A second business/client/signature with blank email/phone saves successfully
   (blanks stored as `null`).
7. "Save" writes a real PDF file and the snackbar reports its location; "Share"
   continues to open the OS share sheet.

## 6. Risks / out-of-scope

- **Encryption (#3)**: out of scope to implement; blocked by ObjectBox edition.
  Documented + TODO only. Commercial edition + key store + destructive migration is
  a separate scheduled item.
- **`toPngBytes` rendering**: uses the `signature` package's headless render; if it
  returns `null` (e.g. empty points) we correctly show no image.
- **Web save**: `dart:io` file save unavailable on web; fall back to share.
- **`getDownloadsDirectory`** unsupported on iOS/Android (throws/returns null); fall
  back to the app documents directory there.
- Existing uncommitted `pubspec.*` user edits are preserved.
- No dependency major-version bumps without explicit approval.
