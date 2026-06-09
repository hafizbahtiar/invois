# Step 4 Quantity & Relation Migration Plan

> **Status:** Planning only (Step 4A). No app code, no ObjectBox schema, no
> generated files changed. This document specifies the staged work for 4B–4E.
> Branch base: `7be8c38`.

## Current State

**How an invoice stores line items today**
- `Invoice` has a **standalone `ToMany<Item> items`** relation (objectbox-model.json: `Invoice.relations = [items, taxes, terms]`). This is the relation the app actually reads/writes.
- `Item` *also* declares a **`ToOne<Invoice>` (`invoiceId`)** relation property — but **no app code ever sets it**, and there is no `@Backlink` tying it to `Invoice.items`. So there are **two independent relations** between the same pair of entities; one is used, one is dead.
- Line items are **not** shared catalog rows: the form constructs a fresh `Item` per line. There is **no Item catalog UI/route** (only business/client/tax/term/signature lists exist), so every `Item` row is effectively invoice-owned line data — but typed as the catalog entity `Item`.

**Where quantity is stored**
- In **`Item.stockQuantity` (int?)** — an inventory field repurposed as the invoice line quantity. Read as `item.stockQuantity ?? 1` in the composer, form, detail, and PDF.
- There is **no** dedicated quantity field and **no `sortOrder`** (the unused `Invoice.sortedItems` getter sorts by name).

**Save/update flow** (`InvoiceFormNotifier.onUpsert` → `InvoiceRepository` → `InvoiceLocalSource`)
1. Invoice scalar fields are saved (`create`/`update`).
2. `clearItemsFromInvoice(id)` → loads invoice, `invoice.items.clear()`, `put` (clears relation **links** only).
3. For each `state.items`: `addItemToInvoice(id, item)` → loads invoice, `invoice.items.add(item)`, `put`.
   - Items with an existing `id` are reused; items with `id == 0/null` create **new `Item` rows**.

**Why orphan `Item` rows accumulate**
- `clearItemsFromInvoice` removes the *relation links*, not the `Item` rows. A line removed during an edit is dropped from `state.items` and never re-added, so its `Item` row **remains in the box with no relation** → orphan. Over repeated edits these accumulate. (The unused `Item.invoiceId` ToOne means even a backlink-based cleanup wouldn't currently find them.)

**Which files create/update/delete these rows**
- Create/update/clear: `invoice_local_source.dart` (`addItemToInvoice`, `clearItemsFromInvoice`), driven by `invoice_notifier.dart` (`onUpsert`, `addItem`/`updateItem`/`removeItem`).
- Construct line `Item`: `invoice_form_page.dart` (`_showAddItemDialog`, sets `stockQuantity: quantity`).

**Which paths read invoice line items**
- Totals: `invoice_notifier.calculateSubtotalCents` + `invoice_composer.dart` (`ComposerLine.quantity = item.stockQuantity ?? 1`).
- Form summary: `invoice_form_page.dart` (`_buildPricingSummary`, `_buildItemsList`).
- Detail: `invoice_detail_page.dart` (`_LineItemsSection`, `item.stockQuantity ?? 1`).
- PDF: `invoice_generator.dart` (`_buildItemsTable`, `item.stockQuantity ?? 1`).

**Old data shape that must remain readable**
- `Item` rows linked via `Invoice.items` with: `stockQuantity` (int line qty), `unitPriceCents` (int, S3) and/or legacy `unitPrice` (double), `name`, `description`, `currency`, optional `unit`. All money read via `effective*Cents` (cents ?? fromDouble(double)).

## Confirmed Problems

1. **P1-003 quantity overload:** line quantity stored in `Item.stockQuantity`; **integer-only** (no decimals for hours/kg); semantically conflated with inventory.
2. **P2 orphan accumulation:** removed line rows are never deleted (`clear` drops links only).
3. **Dual/fragile relation:** `Invoice.items` (ToMany, used) + `Item.invoiceId` (ToOne, dead, no `@Backlink`).
4. **Relation preservation hazard:** scalar updates go through `copyWith` (fresh empty `ToMany`); the app re-adds items separately. Works today but is brittle (any field update that `put`s without re-adding could drop links).

## Business Rules

- **Decimal quantity** is required if the app serves hours/kg/partial-unit billing (the `ItemUnit` enum already includes hour/kg/gram/liter/meter…), so quantity must support fractions.
- **Do not mutate inventory** stock on invoicing. Inventory (`trackInventory`, `minStockLevel`, etc.) is not a shipped feature; line quantity must be a separate concept.
- **Snapshot at invoice time:** a line should capture name/description/unit/unit price/tax as they were when invoiced. (Today this is *accidentally* true because each line is its own `Item` row, but it isn't guaranteed by design.)
- **Catalog edits must not change historical invoices** (totals/PDF). A future Item catalog must not retro-edit past invoices.

## Recommended Target Design

**Adopt Option A — a dedicated `InvoiceLine` entity** that is explicitly invoice-owned, with decimal quantity and snapshot fields.

Proposed `InvoiceLine` fields:
- `int? id` (`@Id`)
- `ToOne<Invoice> invoice` with **`@Backlink()` on `Invoice.lines`** (single, canonical relation)
- `int? sourceItemId` (nullable; provenance only if an Item catalog is added later — never used to recompute)
- `String name`
- `String? description`
- `int unitPriceCents` (minor units — consistent with the S3 money spine)
- `int quantityMilli` (see Quantity Representation; `1.000 == 1000`)
- `String? unit` (snapshot of unit/customUnit display)
- `int? taxRateBasisPoints` or a small tax snapshot (`taxName`, `rateBasisPoints`) — snapshot, not a live `Tax` reference, so tax edits don't change history (addresses P2-003 too)
- `int sortOrder`
- `String? currency`
- `DateTime? createdAt` / `updatedAt`

Rationale: conventional, queryable, ObjectBox-native; cleanly separates catalog (`Item`, if ever built) from invoice line; one backlinked relation (kills the dual relation); explicit ownership enables safe cascade delete (kills orphans); real `quantityMilli` field (kills the overload).

## Options Considered

**Option A — dedicated `InvoiceLine` entity (RECOMMENDED).**
- Pros: clean separation; single `@Backlink` relation; decimal quantity; snapshot correctness; future line-level reporting; orphans solved by ownership+cascade.
- Cons: new entity + backfill from existing `Item`-based lines; most code touch points; ObjectBox model bump.

**Option B — keep `Item` relation, add `lineQuantityMilli` to `Item`.**
- Pros: smallest change; decimal quantity quickly.
- Cons: leaves `Item` overloaded as catalog+line; **does not fix orphans or the dual relation**; still needs separate orphan-cleanup + `@Backlink` work; technical debt persists. Worse long-term.

**Option C — embed serialized line snapshots inside `Invoice` (e.g. JSON string column).**
- Pros: eliminates the entire relation machinery (no ToMany, no orphans, no relation-preservation hazard); invoices become self-contained + snapshot-correct by construction; decimal quantity trivial.
- Cons: lines no longer queryable; manual (de)serialization + a stable schema/version; bigger conceptual shift; all readers (PDF/detail/form/composer) move from `invoice.items` to parsed lines.
- When preferable: if we want to *delete* the relation problem class entirely and never query lines independently. Strong runner-up; not chosen to keep the relational model and line-level extensibility.

**Recommendation for Invois: Option A.** If the team prefers minimum machinery over queryability, Option C is the fallback.

## Quantity Representation

**Use `int quantityMilli` (thousandths): `1.000 == 1000`, 0.001 precision.**
- Rejected: `double` (rounding/precision risk near money math); `Decimal` package (new dependency — out of scope, overkill); string-backed decimal (parse overhead). `int` milli matches the codebase's existing integer-minor-unit philosophy (`Money`/cents).

**Line total (cents), exact integer math:**
```
product = unitPriceCents * quantityMilli      // cents × milli
lineTotalCents = (product + (product < 0 ? -500 : 500)) ~/ 1000   // half-up rounding
```
- Round once, at the line. Subtotal = Σ line totals (then discount/tax via the existing `InvoiceComposer`). Keep all rounding in one pure helper so UI/PDF/persistence agree.
- 64-bit `int` is ample on mobile (native); guard only matters for absurd values.

**Display:** `quantityMilli / 1000` formatted with trailing zeros trimmed (e.g. `1000 → "1"`, `2500 → "2.5"`, `1250 → "1.25"`).

**Migrate old values:** `quantityMilli = (stockQuantity ?? 1) * 1000`.

## ObjectBox Schema Plan

- **4B (additive only):** add `InvoiceLine` entity + `ToMany<InvoiceLine> lines` on `Invoice` with `@Backlink()`. **Keep** `Invoice.items`, `Item`, and `Item.stockQuantity` intact and readable. Regenerate **only** via `dart run build_runner build` (never hand-edit `objectbox.g.dart` / `objectbox-model.json`).
- **4E (cleanup):** once `InvoiceLine` fully owns lines, retire `Invoice.items` (and the dead `Item.invoiceId` ToOne / `Item` entity if unused). Removing relations/entities **retires** their UIDs in the model (generator-managed) — non-destructive to remaining data; UIDs must never be hand-reused.

## Migration / Backfill Plan

- **Stage 4B — additive schema + backfill.** Add `InvoiceLine` + backlink. Backfill: for each `Invoice`, if it has `items` but no `lines`, create one `InvoiceLine` per `Item` (`name`, `description`, `unitPriceCents = item.effectiveUnitPriceCents`, `quantityMilli = (stockQuantity ?? 1) * 1000`, `unit`, `currency`, `sortOrder = index`). **Idempotent:** guard on "invoice already has lines" (or a stored migration-version marker, mirroring `S3MoneyBackfill`). No deletion. Old fields stay authoritative this stage.
- **Stage 4C — switch reads/writes.** Form builds/edits `InvoiceLine` (decimal qty input); `InvoiceComposer` line total uses `quantityMilli`; detail + PDF read `lines`; totals use `lines`. Update tests. `Invoice.items` no longer written.
- **Stage 4D — orphan cleanup.** Delete `Item` rows that are not referenced by any `Invoice.items` relation (legacy orphans). **Guard:** only delete rows provably unreferenced; never touch a future catalog. Run once, idempotent, inside a transaction with a counted report (like `S3MoneyBackfillReport`).
- **Stage 4E — relation cleanup.** Remove `Invoice.items` ToMany and the dead `Item.invoiceId` ToOne (and `Item` if fully unused), regenerate, verify model opens.

## Read/Write Switch Plan

- **Single pure helper** (extend `InvoiceComposer` or add `InvoiceLineMath`) computes `lineTotalCents(unitPriceCents, quantityMilli)`; everyone calls it.
- Order of switch (4C): composer/helper → notifier persistence → form (input + summary) → detail → PDF → tests. Keep a temporary compatibility reader (`lines` if present else map from `items`) until 4D so old invoices still render during rollout.

## Orphan Cleanup Plan

- Definition of a safe-to-delete orphan: an `Item` row whose id appears in **no** `Invoice.items` relation set (and, post-4C, in no `InvoiceLine`).
- Compute the referenced-id set from all invoices first; delete only `Item` rows not in it. Never delete by heuristic on fields. Transactional, with a `{scanned, deleted}` report and a dry-run/log first.
- Do **not** run 4D until 4C is verified, so we don't delete rows still needed by the old path.

## Testing Plan

(Add before/with each stage; ObjectBox-tagged where a store is needed — `flutter test --tags objectbox --run-skipped`.)
- Old invoice with `stockQuantity` still reads/totals correctly (pre- and post-backfill).
- New invoice with decimal quantity (e.g. 2.5) computes the correct line total + subtotal/tax/total.
- Editing an invoice (add/remove/change line) creates **no** orphan `Item`/`InvoiceLine` rows.
- PDF shows correct decimal quantity and line totals; PDF total == stored total.
- Catalog/source edit does not change an old invoice's line snapshot.
- Backfill is idempotent (second run updates 0).
- Deleting an invoice deletes only its own lines (cascade), not shared/other data.
- Deleting a (future) catalog item does not corrupt existing invoice lines.
- ObjectBox migration/open test: store opens against pre-migration data; backfill runs clean.
- Large invoice (e.g. 200 lines) totals + PDF pagination remain correct/performant.
- Pure unit tests: `lineTotalCents` rounding (half-up, boundaries, negative), quantity display formatting, `quantityMilli` from legacy `stockQuantity`.

## Manual QA Checklist

- Create invoice with whole + decimal quantities; verify summary, detail, PDF, share/print.
- Edit existing (pre-migration) invoice; verify quantities preserved, totals unchanged, no duplicate lines.
- Remove a line, save, reopen; verify it's gone and no stray rows (DB inspection).
- Old invoices created before 4B render identically after backfill.
- Light/dark + small screen; large invoice pagination.
- App cold start runs backfill once; second start no-ops.

## Risks and Rollback

- **Data loss:** mitigated by additive-only 4B, idempotent non-destructive backfill, and deferring all deletion to 4D after 4C is verified.
- **Old-invoice compatibility:** keep `items`/`stockQuantity` readable through 4C; compatibility reader until 4D.
- **ObjectBox UID risk:** only the generator mutates `objectbox-model.json`/`objectbox.g.dart`; never hand-edit or reuse retired UIDs.
- **Generated-file risk:** regenerate via build_runner; review the (small) flag/relation diffs; commit generated files only as produced.
- **Backfill idempotency:** guard on existing `lines` / version marker; transactional with a report.
- **Duplicate item rows / PDF total mismatch:** centralize `lineTotalCents`; assert PDF total == stored total in tests.
- **Relation preservation:** the `@Backlink` + explicit line persistence removes the `copyWith`-drops-relations hazard for lines.
- **Rollback:** each stage is independently revertable; until 4D/4E the old data path remains intact, so 4B/4C can be rolled back without data loss. 4D/4E are one-way (deletions) — gate behind a verified backup + the tagged-test run on native lib.

## Recommended Implementation Order

1. **4B** — additive `InvoiceLine` entity + `@Backlink`, idempotent backfill, regenerate, tagged tests. (Approval gate; needs native-lib test run.)
2. **4C** — switch reads/writes (helper → notifier → form → detail → PDF) + tests.
3. **4D** — orphan cleanup migration (guarded, transactional, reported).
4. **4E** — retire `Invoice.items` / dead `Item.invoiceId` (+ `Item` if unused), regenerate, model-open test.

Each stage: separate commit, `flutter analyze` + `flutter test` + (where relevant) `flutter test --tags objectbox --run-skipped` on a native-lib machine, audit-report update, pause for approval before the next.

## Files Likely To Change

- New: `lib/features/invoice/data/invoice_line_model.dart`; `lib/features/invoice/invoice_line_math.dart` (or extend `invoice_composer.dart`); `lib/features/invoice/data/invoice_line_backfill.dart`.
- Schema/generated: `lib/features/invoice/data/invoice_model.dart` (add `lines` backlink), `lib/core/database/objectbox-model.json`, `lib/core/database/objectbox.g.dart` (regenerated).
- Wiring: `invoice_notifier.dart`, `invoice_state.dart`, `invoice_local_source.dart`, `invoice_repository.dart`, `invoice_composer.dart`.
- UI/PDF: `invoice_form_page.dart` (decimal qty input), `invoice_detail_page.dart`, `invoice/pdf/invoice_generator.dart`.
- Startup: `main.dart` (run line backfill alongside `S3MoneyBackfill`).
- Tests: `invoice_composer_test.dart` / new `invoice_line_math_test.dart`, `invoice_repository_objectbox_test.dart`, `pdf_generation_test.dart`, new backfill test.
- `Item`: only retired/trimmed in 4E (not in 4B/4C).
