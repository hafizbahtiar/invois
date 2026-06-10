# Invois — Full Audit & Fix Summary

> Date: 2026-06-11 · Branch: `dev` · Commits: `45addc5..b132346` (+ docs)
> Follow-up to the staged audit in `AUDIT_REPORT.md` (Stages 1–4E-4). This pass
> re-verified the whole codebase after the legacy `Item` schema retirement,
> closed the remaining open findings, and finally executed the objectbox-tagged
> suite on a real native store.

## What was checked

- **Tooling:** `flutter pub get`, `flutter pub outdated`, `dart format`,
  `flutter analyze`, `flutter test`, `flutter test --tags objectbox
  --run-skipped`. No `build_runner` run was needed — **no ObjectBox schema
  changed** in this pass.
- **Security/privacy:** dependency versions, committed files (`git ls-files`
  sweep for Pods/build/keys — clean), debug leftovers, `debugPrint` content
  (paths only, no PII), file handling (PDF save/share paths + filename
  sanitizer), signature byte handling (`imageBytes` with legacy JSON-points
  fallback, fails soft), AndroidManifest, `build.gradle.kts`, iOS `Info.plist`.
- **Invoice business logic:** numbering, composer totals, tax math, discount,
  payment/sent/status lifecycle and its invariant, due-date validation, delete
  safety, missing business/client/signature handling.
- **PDF:** totals vs app display, multi-page flow (`pw.MultiPage`, repeating
  header row, page numbers), bundled offline fonts, signature rendering, null
  safety.
- **Architecture:** feature layering (local source → repository → notifier →
  UI), the architecture guard test, dead code, provider hygiene.
- **State:** Riverpod usage (`ref.read` in callbacks, autoDispose families,
  reactive ObjectBox streams), stale-state paths.

## Baseline at start of this pass

`flutter analyze` clean · 160 default tests passing, 7 skipped (objectbox) ·
objectbox-tagged tests **never executed anywhere** (no native lib) — flagged as
a release blocker in every prior stage.

## Issues found and fixed

| # | Severity | Issue | Fix (commit) |
|---|----------|-------|--------------|
| 1 | **P1** | `deleteInvoiceById` removed only the `Invoice` row — its `InvoiceLine` snapshots were orphaned forever (delete path missed the cleanup the edit path has) | Delete owned lines + invoice in one write transaction; 2 new tagged tests (`8a8afcb`) |
| 2 | **P1** | Long-pressing a line item in the invoice form **popped the whole form page** (the remove handler popped a bottom sheet that wasn't open) and deleted without confirmation (P3-003) | Split sheet-remove vs list-remove; list removal confirms first and never pops a route (`e2afa30`) |
| 3 | **P1** | Form saves could write `status=paid` with `paymentStatus=unpaid` / full balance due — the form bypassed the Step 2B invariant (residual P1-002 path) | New pure `InvoicePayment.forManualSave`; form save, summary, and the (now display-only, derived) Payment Status dropdown all reconcile; +5 unit tests (`e2afa30`) |
| 4 | **P2** | PDF tax rows recomputed from **live** tax rates while the total used the stored snapshot (P2-003); a deleted tax silently dropped its row while the total still included tax | Pure `InvoiceTaxBreakdown`: per-tax rows only when they sum to the snapshot, else one aggregate "Tax" row — rows always sum to the printed total, matching the detail screen; +6 unit tests (`b6fac9a`) |
| 5 | **P2** | Preview page mutated the shared `invoiceFormProvider` (P2-006) | Rewritten on its own autoDispose `invoiceDetailProvider(invoiceId)` — preview/detail/PDF now read identical data (`05dfaf3`) |
| 6 | **P2** | `invoiceId!` force-unwrap in detail/preview routes (P3-005) | Null/invalid id → `NoRoutePage` (`6dc507c`) |
| 7 | **P2** | S3 money backfill scanned every invoice synchronously before `runApp` on each cold start (P2-004) | One-time `SharedPreferences` flag `s3_money_backfill_done_v1` (`a2e6913`) |
| 8 | P3 | Stale error shown in the delete snackbar (read before the delete ran) | Read state after the operation (`e2afa30`) |
| 9 | P3 | Discount rate/amount edits didn't refresh the pricing summary (P3-004) | Both handlers refresh (`e2afa30`) |
| 10 | P3 | 4 undisposed `TextEditingController`s in the form | Disposed (`e2afa30`) |
| 11 | P3 | `kDebugMode` autofill leftover (REF/NOTES/sent/paid dates) — a debug tool polluting debug-mode data | Removed (`e2afa30`) |
| 12 | P3 | ~250 lines of dead data-layer code, incl. the unreconciled `updateStatus` path that could recreate P1-002 if ever called, full-scan search/read helpers, `markAsViewed`, `updatePaymentStatus`, `updateInvoiceAmounts` | Removed; the test covering dead `updateStatus` replaced by the orphan-cleanup tests (`8a8afcb`) |
| 13 | P3 | PDF footer page badge used built-in Helvetica (not the bundled offline font) | Uses bundled bold font (`b6fac9a`) |
| 14 | P3 | iOS `NSLocalNetworkUsageDescription` claimed "sync data with the server" — false for an offline-first app; a privacy-review red flag | Reworded for AirPrint discovery (`b132346`) |
| 15 | — | objectbox-tagged tests had **never been executed** (no native lib) | Installed `libobjectbox.dylib` 5.3.2 (project root, git-ignored); **all 49 tagged tests pass** — documented the no-sudo setup in `doc/testing.md` (`b132346`) |

## Dependency review

- `flutter_riverpod` 3.3.1 → **3.3.2** (patch) — applied, suite green.
- `signature` 5.5.0 → 6.3.0 — **major, NOT applied.** It renders legacy
  JSON-point signatures in the PDF fallback path; upgrade needs its own pass
  with manual signature QA.
- `image` (dev) intentionally pinned to the `pdf` package's decode major.
- Everything else is current or transitively pinned by Flutter. **No known
  vulnerable dependencies.** Note: `printing`, `pdfx`, `objectbox_flutter_libs`
  don't support Swift Package Manager yet (Flutter warning, upstream issue —
  nothing actionable here).

## Intentionally not fixed (and why)

1. **Data-at-rest encryption (P0/P1-SEC):** ObjectBox open-source edition has
   no encryption. Still the top privacy risk for PII on rooted/backed-up
   devices. Options when ready: ObjectBox Sync/encrypted edition, or migrating
   the store. Tracked since the first audit.
2. **Android release signing uses debug keys** (`build.gradle.kts` TODO).
   Cannot ship to Play like this — needs your keystore; nothing I can generate
   for you safely.
3. **`InvoiceFormState.copyWith` clobbers `error` (P3-006):** evaluated and
   **deliberately left**. The notifier and UIs rely on the overwrite to clear
   stale errors (each call site passes `error` explicitly or wants it
   cleared); a keep-old sentinel would *introduce* stale-error bugs like #8
   above. Documented here so it isn't re-flagged.
4. **Invoice numbering only recognises `INV-####` (P3-002):** custom prefixes
   get a fresh `INV-0001` *suggestion*; uniqueness is still validated per
   business, so no collision is possible. Making suggestions prefix-aware is a
   product decision.
5. **Add-item sheet sizing (P2-007 residue):** quantity "null" bug is long
   gone; the sheet is scrollable/draggable with keyboard insets. Left for
   on-device QA before fiddling with sizes.
6. **`signature` 6.x upgrade** — see dependency review.
7. **Partial-payment entry UI / payment history / refund semantics** — feature
   work, not defects (per Stage 2B notes).

## Verification results (final, this machine)

```
flutter analyze                          → No issues found
flutter test                             → 171 passed, 7 skipped (tagged)
flutter test --tags objectbox --run-skipped → 49 passed   ← first-ever native run
dart format lib test                     → 0 changed (clean)
```

Test delta this pass: +11 default (`forManualSave` ×5, tax breakdown ×6),
tagged 48 → 49 (+2 delete-orphan tests, −1 dead `updateStatus` test).

## Manual QA checklist

Invoice flow
- [ ] Create invoice → save → appears in list/dashboard immediately
- [ ] Edit invoice → change items/discount/taxes → detail + PDF totals match the form summary
- [ ] Set Status=Paid in the **form** and save → detail shows Paid, balance RM0.00, payment status Paid
- [ ] Enter a partial Paid Amount with Status=Sent → payment status shows "Partially Paid" (derived, not editable)
- [ ] Long-press a line item → confirmation dialog; Cancel keeps the form open and unchanged
- [ ] Remove a line from the edit-item sheet → sheet closes, form stays
- [ ] Delete invoice from detail and from form menu → list updates, no crash
- [ ] Open detail/preview for an invoice, then edit elsewhere → refresh shows new data

PDF
- [ ] Preview = Share = Print output; totals identical to detail screen
- [ ] Edit a tax's rate **after** saving an invoice → regenerate PDF → single "Tax" row equals stored amount; total unchanged
- [ ] Delete a tax used by an old invoice → PDF still shows the tax amount
- [ ] 100-item invoice → pages flow, header row repeats, page badge styled like body text
- [ ] Invoice number with `/` (e.g. `INV/2026/001`) → share/save works
- [ ] No signature / legacy JSON signature / PNG signature all render or degrade gracefully

Startup & misc
- [ ] First launch after update on an old (pre-S3) database → amounts intact; second launch is fast
- [ ] Preview page open/close repeatedly → no stale form data when creating a new invoice afterwards
- [ ] Dark mode pass over form, detail, preview, settings

## Remaining risks

- Unencrypted PII at rest (see above) — unchanged.
- Release signing config — unchanged.
- The backfill flag means restoring a **pre-S3 database backup over an existing
  install** skips the money backfill; clear app data (or the
  `s3_money_backfill_done_v1` pref) when doing that.
- Tagged tests run on macOS arm64 here; CI should install the matching
  `libobjectbox` (5.3.2) per `doc/testing.md` to keep them running.
