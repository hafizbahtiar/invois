# Sprint S6 — Hardening: Tests, Settings Conformance, Performance, Analyzer-Zero

> **Depends on:** S2–S5. **Branch:** `s6-hardening`.
> Final MVP sprint. Covers blueprint §14 (testing), §15 (performance), §3.2
> (settings drift), and clears residual analyzer noise + technical-debt checklist (§18).
>
> **Implementation status (2026-06-01) — COMPLETE, branch `s6-hardening`.**
>
> **Delivered (verified):**
> - ✅ **Analyzer-zero**: `flutter analyze lib` → 0 issues. `skeletonizer`
>   declared (it was used but only transitively resolved); the two deprecated
>   `value` form-field infos were already fixed in code.
> - ✅ **Money-spine tests**: extracted a pure, Flutter/ObjectBox-free
>   `InvoiceComposer` (subtotal/discount/multi-tax/total/balance in cents) from
>   the form widget + provider; 14 unit tests covering rounding and the
>   post-discount tax base. Form page + provider delegate to it (single source
>   of truth, behavior-preserving).
> - ✅ **Repository tests** against a real in-memory ObjectBox store (CRUD,
>   cents→double dual-write, reactive `watch` re-emit on put/remove, in-query
>   filter/search). Tagged `@Tags(['objectbox'])`, **skipped by default** via
>   `dart_test.yaml` (the Dart test VM lacks the native lib); run with
>   `flutter test --tags objectbox --run-skipped`. Setup documented in
>   [`../testing.md`](../testing.md).
> - ✅ **PDF smoke coverage**: `generateInvoice` produces a valid multi-page PDF
>   for a 100-item signed invoice + a single-item unsigned invoice, and throws
>   on an empty invoice. (Pixel golden deferred — host-fragile; rationale in the
>   test header.)
> - ✅ **Settings → standard flat template**: removed the `data/datasources` +
>   `data/repositories` nesting; `settings_repository.dart` at feature root,
>   `data/settings_local_source.dart`. Public `settingsProvider` path unchanged
>   → launch wiring untouched. Behavior-preserving.
> - ✅ **Search debounce** (300ms) before `invoiceQueryProvider`; filter/data
>   split was already in place. + 5 SettingsNotifier state-transition tests.
> - ✅ **§18 architecture guard**: a test fails the build if `presentation/`
>   code imports a feature `data/` layer or ObjectBox directly (clean today).
>
> **Deferred (conscious scope decisions, not bugs):**
> - ⬜ **First-page pagination cap (~20) / infinite scroll.** `watchInvoices`
>   returns all matching rows (ordered desc). A bare `.limit` would silently
>   hide invoices without scroll-to-load, a behavior change; full paging is a
>   follow-up. Acceptable at MVP data volumes.
> - ⬜ **`const` list tiles / explicit keys micro-optimisation** and
>   `select`-narrowing of heavy watches — low ROI vs. UI churn risk; revisit if
>   a profiler shows whole-list rebuilds.
> - ⬜ **Dependency major upgrades** (objectbox 5.x, riverpod 3.x, shadcn 0.0.52,
>   etc.) — breaking; `flutter pub outdated` reviewed, no blind majors per plan.
> - ⬜ **`getAll()` ban** beyond the import guard — many legitimate data-layer
>   uses remain; not enforced.
>
> **Manual smoke not run in this session** (headless): create→edit→pdf→share→
>   delete across features should be exercised on-device before release.

---

## 1. Settings → standard template
`features/setting/` is the lone clean-arch outlier
(`data/datasources`, `data/repositories`, `presentation/...`). Refactor to the
flat feature template (blueprint §6) used everywhere else:
- `settings_repository.dart` (Result), `settings_local_source.dart`,
  `settings_provider.dart` (Notifier/AsyncNotifier), `settings_page.dart`.
- Update importers of `settingsProvider` (e.g. `main.dart`, `invoice_overview.dart`).
- Behavior-preserving; verify theme/locale/currency still load on launch.

## 2. Test suite (ROI-tiered — blueprint §14)
**MUST (target ~90% on this code):**
- `invoice_composer_test.dart` — totals, discount, multi-tax, cents rounding (money spine).
- Repository tests on an **in-memory ObjectBox** store
  (`Store(getObjectBoxModel(), directory: 'memory:test')`): CRUD + reactive
  `watch` emits on put/remove + soft-delete hides rows.
  - **Host setup required:** `flutter test`'s VM needs the ObjectBox C lib.
    Run ObjectBox's `install.sh` (puts `libobjectbox.dylib` in `/usr/local/lib`)
    once on the dev machine + CI; document in `doc/` and CI config. Until then,
    tag these `@Tags(['objectbox'])` and exclude from default runs.
- PDF: golden test from S5 + "generateInvoice does not throw" for invoice with
  signature and 100 items.

**SHOULD (~50% application/):** notifier `AsyncValue` transitions (loading→data,
validation→error) for invoice + one other feature.

**IGNORE:** per-screen widget tests, e2e, shadcn rendering.

Target overall ~45–55% lines, ~90% on financial/composer/repository.

## 3. Performance pass (blueprint §15)
- **Search debounce** (~300ms) before pushing to `invoiceQueryProvider` (avoid a
  query per keystroke).
- **`select`** on heavy watches; split filter (`NotifierProvider`) from data
  (`StreamProvider`) so filter changes don’t rebuild rows.
- **`const` list tiles** + keys; verify no whole-list rebuilds (rebuild counter).
- Confirm list streams are paged (S3) and cap first page (~20).
- Profile: cold start, large-list scroll, PDF export frame timeline.

## 4. Analyzer-zero + debt checklist
- Resolve the 3 residual infos:
  - `home_page.dart:204` + `invoice_list_page.dart:202` — `value` →
    `initialValue` on the deprecated form field.
  - `my_list.dart` — add `skeletonizer` to `pubspec.yaml` deps (it's imported but
    undeclared) or remove the import.
- Enforce blueprint §18 anti-patterns. Optionally add custom lints / a CI grep
  banning `import '.../data/'` and `objectbox.g.dart` from `presentation/`, and
  `getAll()` outside export paths.
- `dart pub audit` (if available on the SDK) / review `flutter pub outdated`; no
  blind major upgrades.

## 5. Verification
- `~/flutter/bin/flutter analyze` → **0 issues** (the goal of this sprint).
- `~/flutter/bin/flutter test` → green incl. money/repo/golden tests
  (objectbox-tagged tests run where the native lib is installed).
- Manual smoke of the full app (create→edit→pdf→share→delete) across features.

## 6. Rollback
- Independent commits (settings refactor, tests, perf, lint). Revert individually.
- No data/schema risk (no entity changes in S6).

## 7. Out of scope / post-MVP
- Cloud backup, `SyncEngine`/`OutboxOp` drain, multi-device sync, analytics
  dashboard, payment tracking — these ride on the S3 entity groundwork as
  separate epics after MVP.
- ObjectBox at-rest encryption (commercial edition + secure key + destructive
  migration) — tracked separately (R8).
