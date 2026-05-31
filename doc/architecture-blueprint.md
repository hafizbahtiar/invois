# Invois — Production Architecture Blueprint

> Engineering-grade architecture review and implementation blueprint for a solo-maintained
> (3–5 year horizon) offline-first Flutter invoicing app.
> Stack: Flutter 3.x · Dart · Riverpod · ObjectBox · shadcn_flutter.
> Grounded in the actual Invois codebase (real files referenced throughout).

---

## 1. Executive Summary

Invois is a **CRUD-heavy, offline-first, single-writer** application: one user, one device (today),
no concurrent writers, and business logic that is overwhelmingly *data shaping + document rendering*
rather than complex domain rules. That single fact drives every decision below.

**The current architecture is ~80% right and 20% actively harmful.** The layering instinct
(LocalSource → Repository → Provider → UI) is correct and worth keeping. Three structural defects
will compound over 3–5 years:

| Defect | Where | Why it hurts |
|---|---|---|
| **Split `*_list_*` / `*_form_*` everywhere** | Every feature has `invoice_list_repository.dart` *and* `invoice_form_repository.dart`, two providers, two states | Doubles file count for zero benefit. A repository is per-*aggregate*, not per-*screen*. Biggest productivity tax. |
| **No reactivity — `getAll()` + manual refresh** | `_refreshInvoiceList()` re-fetches after every write | Hand-wiring cache invalidation ObjectBox gives free via `query.watch()`. #1 future source of stale-UI bugs. |
| **Inconsistent feature shape** | `setting/` uses clean-arch layers; everything else is flat | Drift already happened; without a template it spreads. |

**Decisive recommendations:**

1. **Reject the UseCase layer (Option B)** — pure pass-through boilerplate here. Choose **Option A** + targeted domain services (`InvoiceComposer`, `PdfService`, `SignatureService`). See ADR-0001.
2. **Collapse list/form into one repository + one `AsyncNotifier` per feature**; migrate off `StateNotifier`.
3. **Make reads reactive** via ObjectBox `Query.watch()` → `StreamProvider`; delete manual refresh.
4. **Fix the signature storage model** (store render-ready compressed PNG as source of truth).
5. **Decompose `invoice_generator.dart`** (1,700 lines) into template/engine/service.
6. **Add sync scaffolding to entities now** (`uuid`, `updatedAt`, `isDeleted`, `version`).

Effort to target: **~6 one-week solo sprints**, front-loaded on the repository/provider collapse.

---

## 2. Architecture Decision Record (ADR)

### ADR-0001 — No UseCase Layer; Repository → Notifier with Targeted Domain Services
- **Status:** Accepted
- **Context:** Option A (`Repository → Provider → UI`) vs Option B (`Repository → UseCase → Provider → UI`). Solo dev, CRUD-dominant, thin rules.
- **Decision:** Adopt **Option A**. Forbid generic per-operation UseCases. Permit **domain services** only when an operation spans ≥2 aggregates or wraps non-trivial non-DB logic (PDF, image export).
- **Consequences:** ✅ ~1 fewer file per op; ✅ real orchestration (invoice = header + items + taxes + terms + signature) gets a home (`InvoiceComposer`) instead of being smeared in `invoice_form_provider.onUpsert`. ⚠️ Risk of logic dumped in Notifiers → mitigated by "Notifier orchestrates, never computes."
- **Reversibility:** High.

### ADR-0002 — Single Repository + Single AsyncNotifier per Feature
- **Decision:** Eliminate `*_list_*` vs `*_form_*` duplication. One `InvoiceRepository`, one reactive `invoiceListProvider` (stream) and one `invoiceFormProvider` (`AsyncNotifier`).
- **Why:** The split is screen-driven, not domain-driven; both touch the same `Box<Invoice>`.

### ADR-0003 — Reactive Reads via `Query.watch()` → `StreamProvider`
- **Decision:** All list/detail reads flow through ObjectBox reactive queries. `_refreshInvoiceList()` is deleted.
- **Why:** ObjectBox emits on any matching write; manual refresh is a correctness liability + race risk.

### ADR-0004 — Signature Stored as Compressed PNG (render-ready), Points Optional
- **Decision:** Persist the rendered, white-bg, trimmed, compressed PNG as canonical `signatureData`. Optional vector points only if re-edit is required.
- **Why:** PDF embeds an image; storing points forced runtime re-render and caused the `Uint8List.fromList(codeUnits)` crash.

### ADR-0005 — Sync-Ready Entities from Day One
- **Decision:** Add `uuid`, `updatedAt`, `createdAt`, `isDeleted`, `version` to every syncable entity now.
- **Why:** Retrofitting identity + soft-delete after data exists is a destructive migration; nullable columns now are free.

---

## 3. Architecture Review (Deep Audit)

### 3.1 Scorecard
| Dimension | Score | Evidence |
|---|---|---|
| Maintainability | 5/10 | Good layering, but list/form duplication + `setting/` outlier + 1,700-line PDF file |
| Scalability | 4/10 | `getAll()` = O(n) load; no pagination; in-memory `.where()` search |
| Testability | 7/10 potential / 1/10 actual | `.withDependencies()` ctors are great seams; only the default counter test exists, and it fails |
| Complexity | 6/10 | Manual PDF pagination heuristics = accidental complexity |
| Performance | 5/10 | Full-table loads + synchronous PDF on UI isolate |
| Developer Experience | 5/10 | Predictable pattern (good) but ~10 files/feature + manual refresh wiring (bad) |

### 3.2 Concrete weaknesses
1. "A repository per screen" is wrong — `InvoiceListRepository` + `InvoiceFormRepository` are the same aggregate.
2. `ObjectBoxResponse<T>` is a hand-rolled Result used inconsistently (some methods return raw `List`, some `bool`, some `ObjectBoxResponse`).
3. `StateNotifier` is legacy — `AsyncNotifier` models loading/error/data for free.
4. Reads not reactive — every new mutation path can forget `_refreshInvoiceList()`.
5. Search is a full scan (`getAll().where(...)`).
6. PDF generation is synchronous on the UI isolate with heuristic pagination.
7. `static final _instance` singletons hide lifecycle; Riverpod should own DI.

### 3.3 Future bottlenecks
- Cloud sync = rewrite without stable UUID/soft-delete.
- Analytics = slow if it `getAll()`s and aggregates in Dart vs ObjectBox counts.
- Large invoices jank the UI thread during PDF build.

### 3.4 Option A vs B — Decision Matrix
| Criterion | Option A (Repo→Provider) | Option B (Repo→UseCase→Provider) |
|---|---|---|
| Files per CRUD op | 0 extra | +1 class per op × N × M |
| Boilerplate | **Low** | **High** |
| Complexity | Low | Medium (pass-through indirection) |
| Testability | Repos + notifiers testable | 3 layers tested per behavior |
| Orchestration home | Notifier / domain service | Use-case |
| Maintainability (solo) | **High** | Medium |
| Fit for Invois | ✅ | ❌ over-engineered |

**Decision: Option A.** The 10% genuinely complex ops get domain services, capturing B's only real benefit at A's cost.

---

## 4. Target Architecture

```
PRESENTATION (features/*/presentation)  — screens/widgets, consume providers, ZERO logic/DB
        ▲ ref.watch / ref.read         │ user intent
APPLICATION (features/*/application)    — Notifiers (AsyncNotifier/Notifier), orchestrate
        ▲                               │
DOMAIN (selective)        DATA (features/*/data)
  entities/models           Repository (1/aggregate) → Result<T,Failure>
  InvoiceComposer           LocalSource (ObjectBox), Mappers
  PdfService                        │
  SignatureService                  ▼
INFRASTRUCTURE (core/) — ObjectBox Store, secure storage, file I/O, (future) sync client
```

**Dependency law:** `presentation → application → data → infrastructure`; `domain` depended on by application & data.
- Allowed: downward only. Presentation never imports `data/` or `objectbox.g.dart`.
- Forbidden: UI→LocalSource; `data/`→`flutter/material` (except signature render); cross-feature deep imports (use barrels).
- Communication: Riverpod providers + `Result<T, AppFailure>` returns. No global singletons.

---

## 5. Complete Folder Structure

```
lib/
├── app/                 # app shell, router, theme (app.dart, router/, theme/)
├── core/                # cross-cutting infra (no feature logic)
│   ├── database/        # objectbox_database.dart, objectbox.g.dart (GEN), model.json (GEN)
│   ├── result/          # result.dart (sealed Result/Ok/Err), app_failure.dart
│   ├── error/           # failure_mapper.dart (Exception → AppFailure)
│   ├── persistence/     # secure_key_store.dart (future encryption)
│   ├── pagination/      # page_request.dart
│   ├── sync/            # syncable.dart, sync_metadata.dart (contracts only today)
│   └── utils/           # safe_parse, date_utils, string_utils...
├── shared/              # reusable dumb UI + value objects (widgets/, models/, extensions/)
└── features/
    ├── invoice/  customer/  product/  tax/  term/  signature/  business/  settings/
```

| Folder | Purpose | Allowed deps | Forbidden deps |
|---|---|---|---|
| `app/` | Composition root, routing, theme | everything | being imported by features |
| `core/` | Infra & contracts | Dart/Flutter SDK | any `features/**` |
| `shared/` | Dumb reusable UI/value types | `core/` | any `features/**` |
| `features/<x>/` | One bounded context | `core/`, `shared/`, other features' **barrel** | another feature's internals; ObjectBox from presentation |

---

## 6. Feature Template Standard (mandatory)

```
features/invoice/
├── invoice.dart                       # BARREL — only public surface
├── data/
│   ├── invoice_entity.dart            # @Entity (persistence shape)
│   ├── invoice_local_source.dart      # Box queries; returns entities
│   ├── invoice_repository.dart        # ONE per aggregate; returns Result<Model>
│   └── invoice_mapper.dart            # entity <-> model
├── domain/                            # only if real logic exists
│   ├── invoice_model.dart             # immutable model
│   ├── invoice_status.dart            # enums + extensions
│   └── invoice_composer.dart          # cross-aggregate orchestration
└── presentation/
    ├── providers/  invoice_list_provider.dart (Stream), invoice_detail_provider.dart, invoice_form_provider.dart (AsyncNotifier)
    ├── screens/    invoice_list_screen.dart, invoice_form_screen.dart, invoice_preview_screen.dart
    └── widgets/    invoice_list_tile.dart, invoice_status_chip.dart
```

**Naming:** `<feature>_entity/local_source/repository/model.dart`, `<feature>_<role>_screen.dart`, `<feature>_<thing>.dart`.

**Anti-drift rules:**
1. One repository per aggregate (no `_list_`/`_form_`).
2. Presentation imports only `domain/` + providers (CI bans `data/` and `objectbox.g.dart` imports).
3. Cross-feature access only via barrel.
4. Repositories return `Result<Model, AppFailure>` — never raw entities, `bool`, or throw.
5. No `static final _instance` singletons — lifecycle belongs to Riverpod.

---

## 7. Data Flow Specification

**Write path:** User Save → `invoice_form_screen` → `InvoiceFormNotifier` (validate, build model) → `InvoiceComposer` (relations, totals) → `InvoiceRepository.upsert` (map→entity, try/catch→Result) → `InvoiceLocalSource` (`box.put` in write txn) → ObjectBox commit **fires reactive query** → `invoiceListProvider` re-emits automatically → UI rebuild.

**Read path:** `invoice_list_screen` → `ref.watch(invoiceListProvider)` → `AsyncValue<List<InvoiceModel>>`; provider = `StreamProvider` → `repo.watchAll(page)` → `localSource.query().watch()`.

| Step | Responsibility | Validation | Error handling | State |
|---|---|---|---|---|
| Screen | Capture intent, render AsyncValue | field validators | show `failure.message` | `ref.watch` |
| Notifier | Orchestrate, hold edit session | cross-field | catch `Result.err` → `AsyncError` | `state = AsyncData/Error` |
| Composer | Multi-aggregate logic, totals, relation diff | invariants (≥1 item) | throws → mapped | — |
| Repository | Map, wrap, txn boundary | preconditions | `try/catch → Result.err` | — |
| LocalSource | Pure ObjectBox calls | none | let throw | — |
| ObjectBox | Persist + notify | `@Unique` | UniqueViolation→repo maps | fires `watch()` |

Key change: "Provider Update → UI Rebuild" is automatic via `watch()`. Delete `_refreshInvoiceList()`.

---

## 8. ObjectBox Specification

### Entity (sync + index strategy)
```dart
@Entity()
class InvoiceEntity {
  @Id() int id = 0;
  // sync identity (ADR-0005)
  @Index() @Unique(onConflict: ConflictStrategy.replace) String uuid;
  @Property(type: PropertyType.date) DateTime updatedAt;
  @Property(type: PropertyType.date) DateTime createdAt;
  bool isDeleted; int version;
  // query-critical, INDEXED
  @Index() String invoiceNumber;
  @Index() int statusValue; @Index() int paymentStatusValue;
  @Property(type: PropertyType.date) @Index() DateTime issueDate;
  @Property(type: PropertyType.date) DateTime dueDate;
  // FKs via ToOne (auto-indexed)
  final business = ToOne<BusinessEntity>();
  final customer = ToOne<CustomerEntity>();
  final signature = ToOne<SignatureEntity>();
  // owned relations
  final items = ToMany<ProductEntity>();
  final taxes = ToMany<TaxEntity>();
  final terms = ToMany<TermEntity>();
  // money as integer minor units
  int subtotalCents; int totalCents; String currencyCode;
}
```
- Money as `int` cents (double accumulates rounding error — unacceptable for invoices).
- Enums stored as `index` (queryable/indexable), not `name` strings.
- `ToOne` FK replaces manual `businessId`/`clientId` + lookups (N+1 generator).

### Indexing: only what you filter/sort/join on. `uuid`(unique hash), `invoiceNumber`, `statusValue`, `issueDate`, FKs(auto).

### Query wrappers (reactive, paged, indexed)
```dart
Stream<List<InvoiceEntity>> watchPage({required int offset, required int limit, InvoiceStatus? status}) {
  final qb = _box.query(InvoiceEntity_.isDeleted.equals(false));
  if (status != null) qb.and(InvoiceEntity_.statusValue.equals(status.index));
  qb.order(InvoiceEntity_.issueDate, flags: Order.descending);
  final q = (qb.build()..offset = offset..limit = limit);
  return q.watch(triggerImmediately: true).map((q) => q.find());
}
List<InvoiceEntity> search(String term) {
  final q = _box.query(InvoiceEntity_.invoiceNumber.contains(term, caseSensitive: false)
      .and(InvoiceEntity_.isDeleted.equals(false))).build();
  try { return (q..limit = 50).find(); } finally { q.close(); }
}
```

### Avoiding the four killers
| Problem | Cause | Fix |
|---|---|---|
| N+1 | `businessId` + per-row `getBusinessById` | `ToOne` relations |
| Full scans | `getAll().where()` | indexed `query().contains()` + limit |
| Memory spikes | load all invoices | `offset/limit` pagination |
| Slow startup | sync `getAll()` first frame | reactive paged stream (first page only) |

### Migration: additive=free; rename via `@Property(uid:)`/`@Entity(uid:)` + paste UID from build error; never reuse retired UIDs; commit `objectbox-model.json` (keep ONE writer). Batch via `runInTransaction` + `putMany`.

---

## 9. Riverpod Specification

### Decision tree
```
Derived/computed?           → Provider
Reactive DB (list/detail)?  → StreamProvider (query.watch)
One-shot async read?        → FutureProvider
Mutable state + CRUD?       → async deps → AsyncNotifierProvider; pure sync → NotifierProvider
```

| Provider | Allowed | Forbidden |
|---|---|---|
| `Provider` | derived state, DI of repos | mutable state, async |
| `FutureProvider` | one-shot reads | live data |
| `StreamProvider` | ObjectBox `watch()` | manual StreamController |
| `NotifierProvider` | sync UI state (filters) | DB I/O |
| `AsyncNotifierProvider` | CRUD, form session | derived state |

### Canonical form Notifier
```dart
final invoiceFormProvider = AsyncNotifierProvider.autoDispose
  .family<InvoiceFormNotifier, InvoiceModel, int?>(InvoiceFormNotifier.new);
class InvoiceFormNotifier extends AutoDisposeFamilyAsyncNotifier<InvoiceModel, int?> {
  @override Future<InvoiceModel> build(int? id) async {
    final repo = ref.watch(invoiceRepositoryProvider);
    return id == null ? InvoiceModel.draft() : (await repo.byId(id)).orThrow();
  }
  Future<void> save() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final m = state.requireValue;
      final composed = ref.read(invoiceComposerProvider).compose(m);
      return (await ref.read(invoiceRepositoryProvider).upsert(composed)).orThrow();
    });
  }
}
```

### Ref & lifecycle rules
- `ref.watch`: in `build()` + widgets (reactive deps). `ref.read`: in callbacks/methods only. `ref.listen`: side effects (snackbar/nav).
- `autoDispose`: **default ON** for form/detail/list. `keepAlive`: only app-wide (repos, settings, DB).
- `family`: cheap equatable keys (value type, not Map).
- Single root `ProviderScope`; override `objectBoxStoreProvider` in tests.
- Optimize: `select`, split filter/data providers, `const` tiles, never watch whole list in a tile.

---

## 10. PDF Generation Engine

Decompose the 1,700-line `invoice_generator.dart`.
```
InvoiceModel → PdfInvoiceData (flattened, pre-computed totals, pre-rendered signature PNG)
  → InvoiceTemplate (interface) [ClassicTemplate] → PdfEngine.build() in compute() → Uint8List
  → PdfStore (file) / PdfSharer (share sheet)
```
```
features/invoice/pdf/
├── pdf_invoice_data.dart   ├── invoice_template.dart   ├── templates/classic_template.dart
├── pdf_engine.dart         ├── pdf_store.dart          ├── pdf_sharer.dart   └── widgets/
```
| Concern | Decision | Why |
|---|---|---|
| Pagination | `pw.MultiPage` auto-break | deletes ~400 lines of heuristics |
| Isolate | `compute(_buildPdf, data)` | off UI thread → no jank |
| Fonts | **bundle TTF** in assets | `PdfGoogleFonts.*` fetches network → fails offline (offline-first violation today) |
| Assets | pre-decode logo/signature to `MemoryImage` | avoid re-decode per page |
| Caching | cache bytes keyed `(invoiceId, updatedAt)` | re-share without rebuild |
| Template | strategy pattern | new style = new class |

---

## 11. Signature System

Root-cause fix (ADR-0004): store the consumable artifact.
```
canvas → controller.toPngBytes(width:~1000) → trim+flatten white bg → PNG (5–30KB)
  → SignatureEntity.imageBytes (+ optional pointsJson) → PDF pw.MemoryImage(bytes)
```
| Concern | Decision | Reason |
|---|---|---|
| Format | PNG | line art on flat bg — smaller + sharper than JPEG |
| Resolution | ~1000px width (≈3×) | crisp at print DPI without huge files |
| Storage | `Uint8List` in ObjectBox | atomic with record, syncs as one unit |
| Size | trim+flatten → 5–30KB | trimming cuts 60–80% |
| Editability | optional `pointsJson` | reopen/edit; PNG remains render source |
| Memory | thumbnails in list, full bytes on detail/PDF only | avoid N×30KB |

---

## 12. Error Handling Architecture
```dart
sealed class AppFailure { final String message; const AppFailure(this.message); }
class ValidationFailure extends AppFailure { final Map<String,String> fieldErrors; const ValidationFailure(super.m,{this.fieldErrors=const{}}); }
class DatabaseFailure   extends AppFailure { const DatabaseFailure(super.m); }
class UniqueViolation   extends DatabaseFailure { final String field; const UniqueViolation(this.field): super('Duplicate $field'); }
class NotFoundFailure   extends AppFailure { const NotFoundFailure(super.m); }
class PdfFailure        extends AppFailure { const PdfFailure(super.m); }
class ExportFailure     extends AppFailure { const ExportFailure(super.m); }
class UnexpectedFailure extends AppFailure { final Object cause; const UnexpectedFailure(this.cause): super('Something went wrong'); }

sealed class Result<T> { const Result(); R when<R>({required R Function(T) ok, required R Function(AppFailure) err}); }
class Ok<T> extends Result<T> { final T value; const Ok(this.value); }
class Err<T> extends Result<T> { final AppFailure failure; const Err(this.failure); }
```
Rule: **throw inside, return `Result` at the repository boundary, render `AsyncValue` at the UI.**
- LocalSource may throw; Repository is the only catcher (maps via `failure_mapper`); Notifier uses `AsyncValue.guard`; UI matches `ValidationFailure`→inline, else snackbar/dialog.

---

## 13. Offline-First Strategy

Local = source of truth always; cloud = eventually-consistent replica. Sync must be **additive**.
```
Repository (unchanged API): writes → LocalSource (immediate) + enqueue Outbox; reads ← LocalSource
[FUTURE] SyncEngine: push (drain Outbox→remote), pull (remote→local since cursor), resolve conflicts
```
- Entity changes now (ADR-0005): `uuid`, `updatedAt`, `version`, `isDeleted` + generic `OutboxOp`.
- Conflicts: invoices/customers/products = **last-write-wins by `updatedAt` + version guard**; deletes = tombstone wins; settings = device-local. LWW is correct *because* one human user.
- Repo write also appends to outbox (no-op cost until SyncEngine exists). UI never knows sync exists.

---

## 14. Testing Strategy (1 dev, limited time/budget)
| Tier | What | Coverage |
|---|---|---|
| **MUST** | repository tests on in-memory ObjectBox; composer/totals/tax math; PDF "does not throw" for representative invoices | ~80% data/+domain/ |
| **SHOULD** | notifier `AsyncValue` transitions; one PDF golden test | ~50% application/ |
| **IGNORE NOW** | per-screen widget tests; e2e; testing shadcn rendering | 0% |

- In-memory ObjectBox: `Store(getObjectBoxModel(), directory: "memory:test")`. Override `objectBoxStoreProvider` in tests.
- Delete `test/widget_test.dart` (default counter test — fails, tests nothing).
- First test: `invoice_composer_test.dart` (money-correctness spine).
- Target ~45–55% global, ~90% on financial/composer/repository code.

---

## 15. Performance Review
| Area | Risk | Detection | Prevention |
|---|---|---|---|
| ObjectBox reads | `getAll()` O(n) load | DevTools memory/timeline | paged `watch()` |
| Search | full scan/keystroke | search latency | indexed `contains` + debounce + limit |
| Riverpod | whole-list rebuilds | rebuild counts | `select`, split providers, `const` |
| PDF | sync build → freeze | frame jank | `compute()` + `MultiPage` |
| Fonts | network fetch | airplane-mode test | bundle TTF |
| Signature | bytes in list state | memory profile | thumbnails; bytes on demand |
| Startup | `getAll()` first frame | startup trace | stream first page (limit 20) |
| Money | `double` rounding | property tests | `int` cents |

---

## 16. Sprint Roadmap (solo, 1-week sprints)
| Sprint | Objective | Deliverables | Verification | Risk | Deps |
|---|---|---|---|---|---|
| **S1 Foundation** | `Result`/`AppFailure`, reactive read spine, DI cleanup, repo/provider collapse (invoice) | Reactive invoice list, no manual refresh, one repo + 2 providers | list auto-updates without `_refreshInvoiceList`; repo tests | High | — |
| **S2 Collapse** | propagate pattern to all features; `AsyncNotifier` | one repo + 2 providers per feature | all compile; form save/validation; notifier tests | High | S1 |
| **S3 Entities & money** | sync-ready entities, `int` cents, indexes, relations | migrated schema, indexed queries, pagination | money tests; index plans; paged list | High | S1 |
| **S4 Signature** | store render-ready PNG; fix PDF embed | signatures render; ≤30KB | PDF opens; size check | Med | S3 |
| **S5 PDF engine** | decompose; isolate + bundled fonts + `MultiPage` | fast offline PDF; 100-item no jank | golden test; airplane-mode; timeline | Med | S4 |
| **S6 Hardening** | tests on money/repos; `settings/` to template; perf | MVP + test spine | ≥90% composer/repo; analyzer clean | Low | S2–S5 |

Cloud sync rides on S3 scaffolding post-MVP with no refactor.

---

## 17. Risk Register
| # | Module | Description | Prob | Impact | Mitigation | Fallback |
|---|---|---|---|---|---|---|
| R1 | OB migration (S3) | relations + cents on live data | Med | High | UID migration; backup `.mdb`; test on copy | export→wipe→import |
| R2 | Repo/provider collapse (S2) | touches all features | Med | High | feature-by-feature, small PRs | revert per-feature |
| R3 | PDF on UI isolate | freeze on big invoices | High | Med | `compute()` + `MultiPage` | cap items/page + spinner |
| R4 | Offline fonts | `PdfGoogleFonts` needs network | High | High | bundle TTF | built-in Helvetica |
| R5 | Money as double | rounding errors | Med | High | `int` cents + property tests | round-half-even at display |
| R6 | Concurrent repo editors | another session churned `objectbox.g.dart` | Med | Med | one writer; commit model.json | regen from entities |
| R7 | Legacy signature data | old JSON-point rows | Low | Med | graceful render-or-skip (done) + S4 migration | "re-capture" prompt |
| R8 | No encryption at rest | OSS ObjectBox has no cipher API | Med | High | documented TODO; minimize PII | commercial edition + secure key (epic) |

---

## 18. Technical Debt Prevention Checklist
**Flutter:** no logic in `build()`; no CPU/IO on UI isolate (`compute()`); `const` tiles.
**Riverpod:** no `ref.watch` in callbacks / `ref.read` in `build()`; no hand-rolled loading/error (use `AsyncValue`); autoDispose default; no manual cache invalidation.
**ObjectBox:** no `getAll()` for lists/search; no manual FK ints (use `ToOne`); `query.close()` on one-shots; `putMany` in txn; never hand-edit `objectbox.g.dart`.
**Repository:** one per aggregate (no `_list_`/`_form_`); return `Result`, never raw/`bool`/throw; no `static _instance` singletons.
**Offline-first:** entities need `uuid`/soft-delete; reads always local; sync is a background engine behind unchanged repo APIs.

---

### Closing
Do **S1 → S2 → S3 in order, do not skip** — load-bearing wall. Highest leverage: **ADR-0002 + ADR-0003** (collapse list/form + go reactive) halves per-feature file count and eliminates stale-UI bugs structurally.
