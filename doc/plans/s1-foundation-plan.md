# Sprint S1 — Foundation: Reactive Reads + Result/Failure + Invoice Repository Collapse

> **Scope:** invoice feature only (other features = S2). In-place (flat files); the
> `data/domain/presentation` folder restructure is deliberately deferred to S2 to bound blast radius.
> **No ObjectBox entity changes → no `build_runner` / codegen in S1** (`uuid`/`isDeleted`/cents are S3).
> **Status:** AWAITING APPROVAL. Do not implement until approved.

Covers: ADR-0002 (single repo/notifier), ADR-0003 (reactive reads), `Result<T>`, `AppFailure`,
repository standard, first reactive `StreamProvider`, list/form provider collapse.

---

## 0. Blast radius (measured, not guessed)

`invoiceListProvider` (currently a `StateNotifier`) is consumed by **4 files** + the form provider:

| File | Current usage | Must change |
|---|---|---|
| `invoice_list_page.dart` | `.notifier.init/getInvoices/searchInvoices`; `watch` → `.invoices/.isLoading/.error` | yes |
| `home_page.dart` | same notifier calls + `watch` at L419 | yes |
| `invoice_list_partial.dart` | `watch(invoiceListProvider)` → state | yes |
| `invoice_overview.dart` | `watch` → `state.invoices` iteration | yes |
| `invoice_form_provider.dart` | `_refreshInvoiceList()` → `.notifier.getInvoices()` | yes (delete) |

Form provider depends on these repo methods (the unified repo must be a superset):
`addItemToInvoice, addTaxToInvoice, addTermToInvoice, clearItemsFromInvoice, clearTaxesFromInvoice,
clearTermsFromInvoice, createCompleteInvoice, updateCompleteInvoice, updateInvoiceStatus,
deleteInvoice, getCompleteInvoice`.

Confirmed entity facts: `status`/`paymentStatus` are `String?` (store enum `.name`); `createdAt` is `DateTime?`;
**no `isDeleted`** field exists yet.

---

## 1. Decisions for S1 (explicit tradeoffs to approve)

1. **`AppFailure` is the universal error type** (thrown in streams, wrapped in `Result` for imperative calls).
2. **`Result<T>` adopted for imperative `delete` in S1**; the write/compose path (`onUpsert`, items/taxes/terms)
   **keeps returning `ObjectBoxResponse` for S1** and migrates to `Result` in **S2** alongside the
   `StateNotifier → AsyncNotifier` move. *Rationale:* converting `onUpsert` now ripples into
   `invoice_form_page.dart` (`result.success`/`result.data`) and explodes S1. Bounded compromise; documented TODO.
3. **Reactive reads surface errors via `AsyncValue`** — the stream throws `AppFailure`; `StreamProvider` turns it
   into `AsyncError`. No `Result` needed on the read path.
4. **Form provider stays a `StateNotifier` in S1** (AsyncNotifier = S2) but is **rewired to the unified repo**
   and **loses `_refreshInvoiceList()`**.
5. **No singletons** for the new repo/local-source — exposed via Riverpod providers. The existing
   `InvoiceLocalSource` singleton stays usable but new code goes through the provider.

---

## 2. Files to CREATE (6)

### 2.1 `lib/core/result/app_failure.dart`
```dart
sealed class AppFailure {
  final String message;
  const AppFailure(this.message);
  @override String toString() => '$runtimeType($message)';
}

class ValidationFailure extends AppFailure {
  final Map<String, String> fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors = const {}});
}
class DatabaseFailure extends AppFailure { const DatabaseFailure(super.message); }
class UniqueViolation extends DatabaseFailure {
  final String field;
  const UniqueViolation(this.field) : super('A record with this $field already exists');
}
class NotFoundFailure extends AppFailure { const NotFoundFailure(super.message); }
class UnexpectedFailure extends AppFailure {
  final Object cause;
  const UnexpectedFailure(this.cause) : super('Something went wrong');
}
```

### 2.2 `lib/core/result/result.dart`
```dart
import 'app_failure.dart';

sealed class Result<T> {
  const Result();
  R fold<R>(R Function(T value) ok, R Function(AppFailure failure) err);
  bool get isOk => this is Ok<T>;
  T? get valueOrNull => fold((v) => v, (_) => null);
  T orThrow() => fold((v) => v, (f) => throw f);
}
class Ok<T> extends Result<T> {
  final T value; const Ok(this.value);
  @override R fold<R>(R Function(T) ok, R Function(AppFailure) err) => ok(value);
}
class Err<T> extends Result<T> {
  final AppFailure failure; const Err(this.failure);
  @override R fold<R>(R Function(T) ok, R Function(AppFailure) err) => err(failure);
}
```

### 2.3 `lib/core/error/failure_mapper.dart`
```dart
import 'package:objectbox/objectbox.dart';
import '../result/app_failure.dart';

/// Single place that turns thrown exceptions into typed AppFailure.
AppFailure mapException(Object error) {
  if (error is AppFailure) return error;
  if (error is UniqueViolationException) {
    return const UniqueViolation('value'); // refine field in S2 if needed
  }
  if (error is ObjectBoxException) return DatabaseFailure(error.toString());
  return UnexpectedFailure(error);
}
```
> Verify `UniqueViolationException` symbol exists in installed objectbox during impl; if not, match on message.

### 2.4 `lib/core/providers/objectbox_providers.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/database/objectbox_database.dart';
import 'package:objectbox/objectbox.dart';

/// App-wide Store. Overridable in tests with an in-memory store.
final storeProvider = Provider<Store>((ref) => ObjectBoxDatabase.instance);
```

### 2.5 `lib/features/invoice/invoice_query_provider.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invoice_model.dart';

class InvoiceQuery {
  final String? search;
  final InvoiceStatus? status;
  final PaymentStatus? paymentStatus;
  const InvoiceQuery({this.search, this.status, this.paymentStatus});
  InvoiceQuery copyWith({String? search, InvoiceStatus? status, PaymentStatus? paymentStatus}) =>
      InvoiceQuery(search: search ?? this.search, status: status ?? this.status,
                   paymentStatus: paymentStatus ?? this.paymentStatus);
  @override bool operator ==(Object o) => o is InvoiceQuery &&
      o.search == search && o.status == status && o.paymentStatus == paymentStatus;
  @override int get hashCode => Object.hash(search, status, paymentStatus);
}

class InvoiceQueryNotifier extends Notifier<InvoiceQuery> {
  @override InvoiceQuery build() => const InvoiceQuery();
  void setSearch(String? term) =>
      state = state.copyWith(search: (term == null || term.isEmpty) ? null : term);
  void setStatus(InvoiceStatus? s) => state = InvoiceQuery(search: state.search, status: s);
  void reset() => state = const InvoiceQuery();
}

final invoiceQueryProvider =
    NotifierProvider<InvoiceQueryNotifier, InvoiceQuery>(InvoiceQueryNotifier.new);
```
> Note: `setStatus` intentionally rebuilds without carrying old status (single active filter), matching current single-filter UI.

### 2.6 `lib/features/invoice/invoice_repository.dart` (unified — replaces both old repos)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invois/core/database/objectbox_response.dart';
import 'package:invois/core/error/failure_mapper.dart';
import 'package:invois/core/providers/objectbox_providers.dart';
import 'package:invois/core/result/app_failure.dart';
import 'package:invois/core/result/result.dart';
import 'package:invois/features/item/item_model.dart';
import 'package:invois/features/tax/tax_module.dart';
import 'package:invois/features/term/term_module.dart';

import 'invoice_local_source.dart';
import 'invoice_model.dart';
import 'invoice_query_provider.dart';

final invoiceLocalSourceProvider = Provider<InvoiceLocalSource>(
  (ref) => InvoiceLocalSource.withDependencies(store: ref.watch(storeProvider)),
);
final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(ref.watch(invoiceLocalSourceProvider)),
);

class InvoiceRepository {
  final InvoiceLocalSource _local;
  InvoiceRepository(this._local);

  // ---- Reactive reads (ADR-0003): throw AppFailure -> AsyncError ----
  Stream<List<Invoice>> watchInvoices(InvoiceQuery q) =>
      _local.watchInvoices(q).handleError((e) => throw mapException(e));

  Future<Invoice?> getCompleteInvoice(int id) => _local.getCompleteInvoice(id);

  // ---- Imperative: Result (S1 adopts Result for delete) ----
  Future<Result<void>> delete(int id) async {
    try { await _local.deleteInvoiceById(id); return const Ok(null); }
    catch (e) { return Err(mapException(e)); }
  }

  // ---- TRANSITIONAL (S1): keep ObjectBoxResponse; migrate to Result in S2 ----
  Future<ObjectBoxResponse<Invoice>> createCompleteInvoice(Invoice i) => _local.insertInvoice(i.stampCreate());
  Future<ObjectBoxResponse<Invoice>> updateCompleteInvoice(Invoice i) => _local.updateInvoice(i.stampUpdate());
  Future<bool> updateInvoiceStatus(int id, InvoiceStatus s) => _local.updateInvoiceStatus(id, s).then((r)=>r);
  Future<void> clearItemsFromInvoice(int id) => _local.clearItemsFromInvoice(id);
  Future<void> addItemToInvoice(int id, Item it) => _local.addItemToInvoice(id, it);
  Future<void> clearTaxesFromInvoice(int id) => _local.clearTaxesFromInvoice(id);
  Future<void> addTaxToInvoice(int id, Tax t) => _local.addTaxToInvoice(id, t);
  Future<void> clearTermsFromInvoice(int id) => _local.clearTermsFromInvoice(id);
  Future<void> addTermToInvoice(int id, Term t) => _local.addTermToInvoice(id, t);
}
```
> `stampCreate()/stampUpdate()` = small `Invoice` copyWith helpers for timestamps (the timestamp logic currently
> lives in the old form repository; move it onto the model or inline `copyWith(createdAt/updatedAt: DateTime.now())`).

---

## 3. Files to MODIFY (6)

### 3.1 `invoice_local_source.dart` — ADD a reactive query (keep everything else)
```dart
import 'package:invois/features/invoice/invoice_query_provider.dart';
// ...
Stream<List<Invoice>> watchInvoices(InvoiceQuery q) {
  final condition = (q.status != null)
      ? Invoice_.status.equals(q.status!.name)
      : (q.paymentStatus != null)
          ? Invoice_.paymentStatus.equals(q.paymentStatus!.name)
          : null;
  final builder = condition == null ? _invoiceBox.query() : _invoiceBox.query(condition);
  builder.order(Invoice_.createdAt, flags: Order.descending);
  final query = builder.build();
  return query
      .watch(triggerImmediately: true)
      .map((q) {
        var list = q.find();
        final term = q0Search(q); // placeholder; see note
        return list;
      });
}
```
> **Impl note:** ObjectBox `contains` on `invoiceNumber` can be added to `condition`
> (`Invoice_.invoiceNumber.contains(q.search!, caseSensitive: false)`) combined with `.and(...)`.
> Confirm exact `Invoice_` property names against generated `objectbox.g.dart` during impl. Do **not**
> reintroduce `getAll().where()`. `q0Search` above is pseudocode to be replaced by an in-query `contains`.

### 3.2 `invoice_list_provider.dart` — REPLACE StateNotifier with StreamProvider (same symbol name)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invoice_model.dart';
import 'invoice_query_provider.dart';
import 'invoice_repository.dart';

/// Reactive list. Re-emits on ANY matching ObjectBox write (no manual refresh).
final invoiceListProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  final repo = ref.watch(invoiceRepositoryProvider);
  final query = ref.watch(invoiceQueryProvider);
  return repo.watchInvoices(query);
});
```
Delete `InvoiceListNotifier`, the old provider, and the import of `InvoiceListState`.

### 3.3 `invoice_form_provider.dart`
- Change `_repository` type `InvoiceFormRepository` → `InvoiceRepository`.
- Provider def: `InvoiceFormNotifier(ref.watch(invoiceRepositoryProvider), ref)`.
- **Delete** `_refreshInvoiceList()` and its 3 call sites (L247, L258, L270, def L274–276) — list is reactive now.
- `deleteInvoiceById`: adapt to `Result`:
```dart
final result = await _repository.delete(id);
return result.fold((_) => true, (f) { state = state.copyWith(error: f.message); return false; });
```
- `onUpsert`: unchanged logic except it calls the unified repo's transitional methods (same names) — keep `ObjectBoxResponse` handling. (Already includes the null-guard + always-clear taxes/terms from the prior fix pass.)

### 3.4 `invoice_list_page.dart` — consume `AsyncValue`
- L40 `init()` call → **remove** (stream auto-loads).
- L56/L67/L72 `getInvoices()` (manual refresh) → **remove**.
- L59/L74 `searchInvoices(value)` → `ref.read(invoiceQueryProvider.notifier).setSearch(value)`.
- Filter selection → `ref.read(invoiceQueryProvider.notifier).setStatus(...)`.
- L413–422 watch block:
```dart
final async = ref.watch(invoiceListProvider);
// ...
items: async.valueOrNull ?? const [],
isLoading: async.isLoading,
errorMessage: async.hasError ? (async.error as AppFailure?)?.message ?? 'Failed to load' : null,
```

### 3.5 `invoice_list_partial.dart` — same `AsyncValue` mapping as 3.4 at L29.

### 3.6 `invoice_overview.dart` — L16:
```dart
final invoices = ref.watch(invoiceListProvider).valueOrNull ?? const <Invoice>[];
```
(remove `state.invoices`; the rest of the aggregation loop is unchanged.)

### 3.7 `home_page.dart` — mirror 3.4 (L42 init remove; L55/L71 getInvoices remove; L73 search→query notifier; L419 watch→AsyncValue).

---

## 4. Files to DELETE (3)
- `lib/features/invoice/invoice_list_repository.dart`  (folded into `invoice_repository.dart`)
- `lib/features/invoice/invoice_form_repository.dart`  (folded into `invoice_repository.dart`)
- `lib/features/invoice/invoice_list_state.dart`        (replaced by `AsyncValue`)

> `invoice_form_state.dart` is **kept** (form provider stays `StateNotifier` in S1).

---

## 5. Migration order (each step keeps the app compiling → its own commit)

| Step | Action | App state | Commit msg |
|---|---|---|---|
| 1 | Create `app_failure.dart`, `result.dart`, `failure_mapper.dart`, `objectbox_providers.dart` | green (no consumers) | `feat(core): add Result/AppFailure + store provider` |
| 2 | Create `invoice_query_provider.dart` + `invoice_repository.dart`; add `watchInvoices` to local source | green (new code unused) | `feat(invoice): unified repository + reactive query (unwired)` |
| 3 | Rewrite `invoice_list_provider.dart` → StreamProvider; update **all 4 consumers**; delete `_refreshInvoiceList`; delete `invoice_list_state.dart` | green after all consumers updated | `refactor(invoice): reactive list, remove manual refresh` |
| 4 | Rewire `invoice_form_provider` to unified repo; delete the two old repos | green | `refactor(invoice): collapse list/form repositories` |
| 5 | `flutter analyze` + smoke test + commit fixups | green | `chore(invoice): S1 verification fixups` |

**Rule:** do not start step N+1 until step N analyzes clean.

---

## 6. Verification steps

Per step and at the end:
```bash
~/flutter/bin/flutter analyze lib            # must be clean (pre-existing infos excepted)
~/flutter/bin/flutter test                   # composer/repo tests once added
```
Manual smoke (the behaviors that matter for S1):
1. **Reactive insert:** create an invoice → list updates **without** any manual refresh call.
2. **Reactive delete:** delete from detail → row disappears from list immediately.
3. **Search:** typing filters the list via `invoiceQueryProvider` (no full-scan; in-query `contains`).
4. **Status filter:** selecting a filter chip narrows the list.
5. **Overview/home cards** recompute from the reactive stream.
6. **No regressions** in form save (null-guard + taxes/terms clearing still work).

Optional new test (cheap, high ROI): `test/invoice_repository_test.dart` against an in-memory store
(`Store(getObjectBoxModel(), directory: 'memory:s1test')`) asserting `watchInvoices` emits on `put`/`remove`.

---

## 7. Rollback plan

- **Per-commit revert** (steps are isolated): `git revert <sha>` in reverse order. Step 3 is the only breaking
  switch; reverting it restores the `StateNotifier` provider + the 4 consumers + `_refreshInvoiceList`.
- **Hard reset option:** S1 lives entirely on a branch `s1-foundation`; if abandoned, `git checkout main`
  discards everything. (Recommend doing S1 on a branch.)
- **No data risk:** zero entity/schema changes in S1 → no DB migration → existing `.mdb` data untouched and
  fully compatible if rolled back.
- **Deleted files** are recoverable from git history (`git checkout main -- <path>`).

---

## 8. Explicitly OUT of S1 (so scope can't creep)
- Folder restructure to `data/domain/presentation` (S2).
- `StateNotifier → AsyncNotifier` for the form (S2).
- Converting `onUpsert`/compose to `Result` (S2).
- Propagating the pattern to business/client/product/etc. (S2).
- Entity changes: `uuid`/`updatedAt`/`isDeleted`/`int cents`/indexes/`ToOne` (S3) — **no codegen in S1**.
- PDF, signature, encryption (S4/S5/later).

---

## 9. Open questions for approval
1. OK to run **S1 on a dedicated `s1-foundation` branch**? (Strongly recommended.)
2. Approve the **transitional `ObjectBoxResponse` for writes** (Result only for `delete`) in S1, converging in S2?
3. Approve **deleting** `invoice_list_repository.dart`, `invoice_form_repository.dart`, `invoice_list_state.dart`?
4. Should `home_page.dart` be included in S1, or do you want S1 limited to the invoice screens (deferring `home_page` to a follow-up)? It shares `invoiceListProvider`, so it must change when the symbol's type changes — I recommend including it.
