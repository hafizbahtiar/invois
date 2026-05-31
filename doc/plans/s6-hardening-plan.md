# Sprint S6 — Hardening: Tests, Settings Conformance, Performance, Analyzer-Zero

> **Depends on:** S2–S5. **Branch:** `s6-hardening`.
> Final MVP sprint. Covers blueprint §14 (testing), §15 (performance), §3.2
> (settings drift), and clears residual analyzer noise + technical-debt checklist (§18).

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
