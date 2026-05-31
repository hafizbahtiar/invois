# Sprint S2 — Propagate the S1 Pattern to All Features

> **Depends on:** S1 (merged). **Branch:** `s2-feature-propagation`.
> **Scope:** apply ADR-0002/0003 to every remaining feature, converge imperative
> writes onto `Result`, and finish the invoice form (remove manual refresh,
> `Result` writes). Still in-place (flat files); folder restructure to
> `data/domain/presentation` is optional polish, NOT required here.
> **No ObjectBox entity changes → no codegen.**

Covers blueprint §6/§9 across: **business, client, tax, term, signature** (full
list/form splits) + the **invoice form**.
`item` is an embedded model (no providers) — untouched. `settings` → S6.

---

## 0. SCOPE DECISION — AsyncNotifier deferred (CONFIRMED)

The original S2 outline included migrating form notifiers
`StateNotifier → AsyncNotifier`. This is **intentionally deferred** (confirmed
decision, not unfinished work):

- **Real S2 win:** repository unification (ADR-0002) + reactive list/query
  providers (ADR-0003) + `Result`/`AppFailure` writes. All delivered here.
- **Why defer AsyncNotifier:** it forces rewriting large (≈300–450 line) form
  *pages*' state consumption for low immediate product value (mostly swapping
  hand-rolled `isLoading`/`error` for `AsyncValue`). High churn, no bug/perf/
  maintenance driver today.
- **Rule going forward:**
  - **Reactive `StreamProvider`** (family on a query type) is the required
    standard for **list/query state**.
  - **Unified repository per aggregate** (one repo, `Result` imperative + `Stream`
    reactive) is the required standard for **all features**.
  - **`StateNotifier` is retained for complex forms** (rewired to the unified
    repo; manual refresh removed). Do **not** rewrite a form page to
    `AsyncNotifier` absent a clear bug, performance issue, or maintenance
    bottleneck. Revisit in a focused pass / S6 if ever justified.

Per-feature delivered shape (matches the `tax` reference migration):
new `X_repository.dart` (+ DI providers) · new `X_query_provider.dart` (if
filtered) · `X_local_source.watchX()` · `X_list_provider` → `StreamProvider`
family · `X_form_provider` rewired to repo (StateNotifier kept) · consumers →
`AsyncValue` · deleted `X_list_repository`/`X_form_repository`/`X_list_state` ·
barrel updated.

---

## 1. Per-feature target (identical shape for each of the 5 features `X`)

Mirror the invoice feature delivered in S1:

**Create**
- `X_repository.dart` — single `XRepository` + `xRepositoryProvider` +
  `xLocalSourceProvider`; reactive `watchX(query)` (throws `AppFailure`) +
  `Result`-returning `create/update/delete`.
- `X_query_provider.dart` — only for features with search/filter UI
  (**business, client**). `tax`, `term`, `signature` are simple lists → a plain
  `StreamProvider` watching all rows is enough (skip the query provider).

**Modify**
- `X_local_source.dart` — add `Stream<List<X>> watchX(...)` (in-query filters,
  no `getAll().where()`). Keep existing methods until callers are migrated.
- `X_list_provider.dart` — rewrite to `StreamProvider.autoDispose<List<X>>`.
- `X_form_provider.dart` — migrate `StateNotifier<XFormState>` →
  `AutoDisposeAsyncNotifier`/`...FamilyAsyncNotifier`; use `AsyncValue.guard`;
  call the unified repo; return/throw `AppFailure`.
- `X_list_page.dart`, `X_form_page.dart` — consume `AsyncValue`
  (`.valueOrNull`, `.isLoading`, `.hasError`); push search/filter to the query
  provider; drop manual refresh and `.notifier.init()` calls.

**Delete**
- `X_list_repository.dart`, `X_form_repository.dart`, `X_list_state.dart`.
- `X_form_state.dart` is **retained** (StateNotifier form kept — see §0).

---

## 2. Invoice form finish

Per §0, this is **NOT** a full AsyncNotifier rewrite. Deliver:
- Converge invoice writes to `Result`: `create/update/delete` return `Result`;
  retire the transitional `ObjectBoxResponse` methods from `InvoiceRepository`
  and the `ObjectBoxResponse` dependency from the invoice write path.
- Remove any remaining manual refresh patterns (S1 already removed
  `_refreshInvoiceList`; verify none linger).
- `invoice_form_provider` stays a `StateNotifier`, rewired to the `Result` repo
  surface; `invoice_form_page`/`invoice_preview_page` adapt their write-result
  handling (no AsyncValue rewrite of the form).
- Extracting `InvoiceComposer` is **optional/deferred** unless it falls out
  naturally; not required for S2.

> `ObjectBoxResponse` is retired from migrated paths as each feature lands; any
> residual usage is cleaned up by end of S2 / S6.

---

## 3. (DEFERRED) Canonical AsyncNotifier form — for future reference only

> Not used in S2 (see §0). Kept here as the target shape if/when a form is
> migrated in a later focused pass.

```dart
final xFormProvider = AsyncNotifierProvider.autoDispose
    .family<XFormNotifier, X, int?>(XFormNotifier.new);

class XFormNotifier extends AutoDisposeFamilyAsyncNotifier<X, int?> {
  @override
  Future<X> build(int? id) async {
    final repo = ref.watch(xRepositoryProvider);
    return id == null ? X.draft() : (await repo.byId(id)).orThrow();
  }

```dart
final xFormProvider = AsyncNotifierProvider.autoDispose
    .family<XFormNotifier, X, int?>(XFormNotifier.new);

class XFormNotifier extends AutoDisposeFamilyAsyncNotifier<X, int?> {
  @override
  Future<X> build(int? id) async {
    final repo = ref.watch(xRepositoryProvider);
    return id == null ? X.draft() : (await repo.byId(id)).orThrow();
  }

  Future<bool> save(X model) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async =>
        (await ref.read(xRepositoryProvider).upsert(model)).orThrow());
    return !state.hasError;
  }

  Future<bool> remove(int id) async {
    final res = await ref.read(xRepositoryProvider).delete(id);
    return res.fold((_) => true, (f) { state = AsyncError(f, StackTrace.current); return false; });
  }
}
```
UI listens for side effects:
```dart
ref.listen(xFormProvider(id), (_, next) {
  if (next.hasError) MySnackBar.show(context, message: (next.error as AppFailure).message, type: failed);
});
```

---

## 4. Migration order (one feature per commit; green each time)

| Step | Feature | Notes |
|---|---|---|
| 1 | **tax** | simplest (no search) — proves the template end-to-end |
| 2 | **term** | same shape |
| 3 | **signature** | same; note it’s also touched in S4 (leave signatureData as-is here) |
| 4 | **business** | has search/filter → add `business_query_provider.dart` |
| 5 | **client** | has search/filter + `ToMany<Address>` (preserve address handling) |
| 6 | **invoice form** | AsyncNotifier + InvoiceComposer + Result writes (§2) |
| 7 | **cleanup** | retire `ObjectBoxResponse` from migrated paths; analyze/test |

Cross-feature callers to watch (these `ref.read(...).notifier` calls must change):
`business_list_provider`/`client_list_provider` are read by `invoice_form_provider`
(`getDefaultBusiness`, `getDefaultClientByBusinessId`) and by the business/client
list pages. Audit with `grep -rn "<x>ListProvider\|<x>FormProvider" lib` before each step.

---

## 5. Verification
- Per feature: `~/flutter/bin/flutter analyze lib` clean; affected list/form screens
  reactive (create/edit/delete reflects without manual refresh).
- Add unit tests: `invoice_composer_test.dart` (totals, discount, multi-tax — the
  money-correctness spine) + one query-provider test per searchable feature.
- `~/flutter/bin/flutter test` green.

## 6. Rollback
- Per-commit `git revert` (each feature isolated). Whole sprint: `git checkout main`.
- No entity/schema change → no data risk.

## 7. Out of scope
- Entity/money/relation/index changes (S3). Folder restructure (optional, post-S6).
- PDF/signature internals (S4/S5). Settings refactor (S6).

## 8. Open questions
1. Do business/client need multi-filter (status+search simultaneously) or single-filter parity with today?
2. Keep `ObjectBoxResponse` until S6, or hard-retire it at end of S2?
3. Adopt the `data/domain/presentation` folder move now (bigger diff) or stay flat through S6?
