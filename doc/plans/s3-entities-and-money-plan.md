# Sprint S3 — Sync-Ready Entities, Money as Cents, Indexes, Relations, Pagination

> **Depends on:** S2. **Branch:** `s3-entities-and-money`.
> **HIGHEST-RISK sprint** — it changes the ObjectBox schema and money
> representation on live data. **Requires `build_runner` + a data migration.**
> Do this on a branch, back up the `.mdb` first, test on a copy.
>
> **Implementation status (2026-06-01):** S3 was deliberately narrowed to the
> money-safety spine and is complete after isolated smoke testing. Implemented:
> additive nullable cents fields for `Invoice`/`Item`, `Money` value object,
> startup backfill from legacy doubles, cents-first invoice calculations,
> repository dual-write to legacy doubles for rollback, and PDF/list/overview
> compatibility. Not implemented in this pass: sync metadata, indexes,
> `ToOne` relation migration, soft-delete, or pagination; keep those as future
> schema work because they are independent risks.

Covers blueprint §8 (ObjectBox spec) + §13 entity prep (ADR-0005) + the
`double → int cents` debt (R5).

---

## 1. Sub-phases (each its own commit; can stop after any)

S3 is split so the destructive money change is isolated and skippable if risk is too high:

| Phase | Change | Codegen | Risk |
|---|---|---|---|
| 3a | Sync metadata fields (additive, nullable) | yes | Low |
| 3b | Indexes on query fields | yes | Low |
| 3c | Invoice `ToOne` relations (Business/Client/Signature) alongside existing int FKs | yes | Med |
| 3d | Soft-delete + reactive `isDeleted` filter + pagination | no (uses 3a) | Med |
| 3e | Money `double → int cents` | yes | **High** |

---

## 2. Phase 3a — Sync metadata (ADR-0005)

Add to every syncable entity (`Invoice, Business, Client, Signature, Item, Tax, Term`):
```dart
@Index() @Unique(onConflict: ConflictStrategy.replace)
String uuid;                                  // default: const Uuid().v4() at construction
@Property(type: PropertyType.date) DateTime? updatedAt;   // already present on most
@Property(type: PropertyType.date) DateTime? createdAt;   // already present on most
bool isDeleted = false;
int version = 0;
```
- Add `uuid` dependency to `pubspec.yaml` (`uuid: ^4.x`).
- **Migration:** new fields are additive → ObjectBox auto-migrates. Backfill `uuid`
  lazily: a repository read that finds `uuid == ''`/null assigns one and re-puts
  (one-time, transparent). No destructive step.
- All `copyWith`/`toJson`/`fromJson` updated.

## 3. Phase 3b — Indexes
Add `@Index()` to fields used in filters/sorts/joins:
- `Invoice`: `invoiceNumber`, `status`, `paymentStatus`, `issueDate`.
- `Business`/`Client`/`Signature`: keep existing `@Unique` (already indexed).
- Rebuild: `dart run build_runner build --delete-conflicting-outputs`.

## 4. Phase 3c — Invoice relations
- Add to `Invoice`: `final business = ToOne<Business>();`,
  `final customer = ToOne<Client>();`, `final signature = ToOne<Signature>();`.
- Keep `businessId`/`clientId` ints **temporarily** (dual-write) to avoid breaking
  reads; backfill relations from ints on read; flip readers to relations; then
  remove the int fields in a later commit.
- Eliminates the N+1 in `invoice_form_provider` (`getBusinessById`/`getClientById`
  per load) → replace with `invoice.business.target`.

## 5. Phase 3d — Soft-delete + pagination
- `InvoiceRepository.delete` → set `isDeleted = true`, `updatedAt = now`, re-put
  (instead of `box.remove`). Tombstone for future sync.
- `watchInvoices` adds `Invoice_.isDeleted.equals(false)` and supports
  `offset`/`limit` (see `core/pagination/page_request.dart`); list providers move to
  `StreamProvider.family<.., InvoiceListArgs>` with “load more” bumping `limit`.
- Apply the same soft-delete to other aggregates.

## 6. Phase 3e — Money as integer cents (HIGH RISK)
- `Invoice`: `subtotalCents/discountAmountCents/taxAmountCents/totalCents/
  paidAmountCents/balanceDueCents` (`int`); `Item.unitPriceCents` (`int`).
- Add a `Money` value type or `int.toCurrency(code)` formatter in `core/utils`.
- Ripple: `InvoiceComposer` math, `invoice_generator` formatting, totals widgets,
  `currency_utils`. All `toStringAsFixed(2)` becomes cents→display formatting.
- **Migration:** convert existing `double` → `int` cents on read
  (`(value * 100).round()`), write back. Provide a one-shot migration routine run
  once at startup guarded by a `settings` flag, OR lazy per-record.
- Property-based test: `formatCents(parseCents(x)) == x` for representative values.

---

## 7. Migration & safety
- **Back up** the store before first run: copy the app documents `objectbox/`
  directory; document the path. Provide an in-app "export all (JSON)" escape hatch
  before 3e.
- After each `@Entity` change: `dart run build_runner build --delete-conflicting-outputs`,
  commit regenerated `objectbox.g.dart` + `objectbox-model.json` (single writer).
- Manage renames/removals with `@Property(uid:)`/`@Entity(uid:)` from the build error.

## 8. Verification
- `flutter analyze lib` clean; `flutter test` green (incl. new money tests).
- Manual: create/list/search/paginate; delete hides via tombstone; relations resolve;
  totals identical pre/post cents conversion on a sample invoice.
- Query plans use indexes (no full scans) — spot check large-list scroll perf.

### 8.1 Isolated smoke result (2026-06-01)

Smoke test used a fresh isolated ObjectBox store, not real production/dev data:
`/private/tmp/invois-s3-smoke-1780245093975-55324`.

Executed scenarios:
- Seeded a pre-S3 invoice with only legacy double money fields.
- Ran `S3MoneyBackfill`; report:
  `invoicesScanned: 1, invoicesUpdated: 1, itemsScanned: 2, itemsUpdated: 2`.
- Verified migrated old invoice totals:
  `subtotal=3060`, `discount=500`, `tax=154`, `total=2714`,
  `balanceDue=1714`.
- Created a new invoice through `InvoiceRepository`; verified cents fields and
  rollback doubles were both written.
- Edited a migrated invoice; verified reopened totals stayed stable.
- Generated PDFs for a migrated old invoice and a new invoice.
- Confirmed rollback safety: legacy `double` total and item unit price remain
  populated with reasonable equivalent values.

Smoke output:
```text
OK: Old invoice: total=MYR27.14, balance=MYR17.14
OK: New invoice: total=MYR23.30, item=MYR10.99
OK: Edited old invoice: total=MYR38.16, balance=MYR28.16
OK: PDF bytes: old=13350, new=13311
S3_SMOKE_PASS
```

Non-blocking notes:
- The host VM initially lacked `libobjectbox.dylib`; the official ObjectBox
  installer was used temporarily, then downloaded repo artifacts were removed.
- PDF generation printed a non-fatal `AssetManifest.json` binding warning while
  still producing both PDFs. PDF engine/font work remains S5.

## 9. Rollback
- Per-phase commits; revert in reverse. 3e is the only destructive one — revert
  restores `double` fields, but **data written as cents must be converted back**
  (the migration must be reversible, or restore from the pre-3e `.mdb` backup).
- Phases 3a–3d are additive/non-destructive and safely revertible.

## 10. Out of scope
- The actual cloud `SyncEngine`/`OutboxOp` drain (post-MVP). S3 only lays entity groundwork.
