# Invois — Sprint Plans Index

Engineering blueprint: [`../architecture-blueprint.md`](../architecture-blueprint.md)

Execute strictly in order. Each plan keeps the app green at every commit and is
reversible. S1 → S2 → S3 are the load-bearing wall; S4/S5/S6 are independent and
may be reordered by product priority.

| Sprint | Plan | Objective | Status |
|---|---|---|---|
| S1 | [`s1-foundation-plan.md`](s1-foundation-plan.md) | Result/Failure, reactive reads, invoice repo collapse | ✅ Done (branch `s1-foundation`) |
| S2 | [`s2-feature-propagation-plan.md`](s2-feature-propagation-plan.md) | Propagate S1 pattern to all features; reactive lists; converge writes to `Result` | ✅ Done (verified 2026-05-31) |
| S3 | [`s3-entities-and-money-plan.md`](s3-entities-and-money-plan.md) | Money safety: additive cents fields, backfill, cents reads/writes, rollback dual-write | ✅ Done (isolated smoke passed 2026-06-01) |
| S4 | [`s4-signature-system-plan.md`](s4-signature-system-plan.md) | Store render-ready PNG; fix PDF embed at the source | ✅ Done (2026-06-01; `signatureData` kept, `image`-trim deferred) |
| S5 | [`s5-pdf-engine-plan.md`](s5-pdf-engine-plan.md) | Offline bundled fonts + MultiPage pagination | ✅ Done at reduced scope (2026-06-01, branch `s5-pdf-engine`). DTO+isolate, pdf/ decomposition, caching **deferred** to a follow-up. |
| S6 | [`s6-hardening-plan.md`](s6-hardening-plan.md) | Tests, settings→template, perf, analyzer-zero | ✅ Done (2026-06-01, branch `s6-hardening`). Analyzer 0; MUST-tier tests added; ObjectBox tests gated; search debounced. Full pagination + tile micro-opts deferred. |

## Current verification
- S1/S2 verified against code on 2026-05-31.
- `~/flutter/bin/flutter test` passes (45 tests; ObjectBox-tagged repo tests
  skipped by default — see [`../testing.md`](../testing.md)).
- `~/flutter/bin/flutter analyze lib` reports **0 issues** as of S6
  (2026-06-01). The deprecated `value` infos were already fixed in code; the
  undeclared `skeletonizer` dependency is now declared.
- Form notifiers intentionally remain `StateNotifier` after S2; reactive list
  providers + unified repositories + `Result` write boundaries are the completed
  S2 target.
- `ObjectBoxResponse` may still exist inside local sources as an internal adapter,
  but feature repositories expose `Result` for imperative writes.
- S3 money safety verified on 2026-06-01 against an isolated temp ObjectBox store:
  legacy double rows backfilled, new/edit invoice flows dual-write cents+doubles,
  and PDF generation succeeded for migrated and new invoices. `~/flutter/bin/flutter test`
  passes; analyzer reports the same known S6 infos only.

## Conventions (all sprints)
- Dedicated branch per sprint (`s2-…`, `s3-…`); green-at-each-step commits.
- Verify `~/flutter/bin/flutter analyze lib` clean + `~/flutter/bin/flutter test` before each commit.
- Repositories return `Result<T, AppFailure>` (imperative) or reactive `Stream` (reads).
- One repository per aggregate; no `*_list_*`/`*_form_*` splits; no `static _instance` singletons.
- ObjectBox entity changes require `dart run build_runner build --delete-conflicting-outputs` and a committed `objectbox-model.json` (single writer).
