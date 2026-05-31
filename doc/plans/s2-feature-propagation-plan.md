# Sprint S2 — Propagate the S1 Pattern to All Features + AsyncNotifier

> **Depends on:** S1 (merged). **Branch:** `s2-feature-propagation`.
> **Scope:** apply ADR-0002/0003 to every remaining feature, migrate forms from
> `StateNotifier` → `AsyncNotifier`, converge imperative writes onto `Result`,
> and extract `InvoiceComposer`. Still in-place (flat files); folder restructure
> to `data/domain/presentation` is optional polish, NOT required here.
> **No ObjectBox entity changes → no codegen.**

Covers blueprint §6/§9 across: **business, client, tax, term, signature** (full
list/form splits) + the **invoice form** (finish the S1 transitional debt).
`item` is an embedded model (no providers) — untouched. `settings` → S6.

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
- `X_list_repository.dart`, `X_form_repository.dart`, `X_list_state.dart`,
  `X_form_state.dart` (the last replaced by `AsyncValue`).

---

## 2. Invoice form finish (S1 debt)

- Extract `domain/invoice_composer.dart`: moves the `onUpsert` orchestration
  (resolve business/client, items/taxes/terms clear+add, totals) out of the
  notifier. Pure, unit-testable. Exposed via `invoiceComposerProvider`.
- Migrate `invoice_form_provider.dart` `StateNotifier` → `AsyncNotifier`.
- Converge `createCompleteInvoice`/`updateCompleteInvoice`/`updateInvoiceStatus`
  from `ObjectBoxResponse` → `Result` (remove the transitional methods from
  `InvoiceRepository`; delete the `ObjectBoxResponse` dependency from the
  invoice write path).
- Update `invoice_form_page.dart` + `invoice_preview_page.dart` to the new
  `AsyncValue`/`Result` surface.

> `ObjectBoxResponse` may still be used by not-yet-migrated features mid-sprint;
> it is fully retired only after all features are migrated (end of S2 or S6).

---

## 3. Canonical AsyncNotifier form (pattern for every `X`)

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
