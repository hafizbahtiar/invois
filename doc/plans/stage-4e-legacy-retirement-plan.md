# Stage 4E Legacy Item Retirement Plan

Status: planning only. Do not implement until all gates below are satisfied.

## Scope

Stage 4E retires the legacy invoice item path:

- `Invoice.items`
- `Item`
- `Item.invoiceId`
- legacy quantity compatibility via `Item.stockQuantity`

`InvoiceLine` is the authoritative invoice line model. The goal is to remove the legacy relation and entity only after proving every persisted invoice has safe `InvoiceLine` rows and every user-facing path reads/writes those rows without fallback.

## Preconditions Before Implementation

- `flutter analyze` passes.
- `flutter test` passes.
- `flutter test --tags objectbox --run-skipped` passes on a machine with `libobjectbox.dylib`.
- Decimal quantity manual QA passes:
  - create decimal invoices,
  - save/reopen,
  - edit decimal quantity,
  - detail view,
  - PDF preview/share,
  - invalid quantity rejection.
- Stage 4D cleanup dry-run is reviewed on production-like data.
- Optional but recommended: real orphan delete completed after confirmation and backup.
- Backup/export strategy is defined and tested before schema retirement:
  - export invoices and invoice lines to an external format, or
  - take a copy of the ObjectBox store directory,
  - verify restore/open on a separate build before deleting the legacy entity.
- A release/downgrade decision is made. Once schema removal ships, older app builds may not be able to open the upgraded store.

## Current Legacy Dependencies

These references were found by search while planning. Stashed user UI files were not inspected.

### `Invoice.items`

- `lib/features/invoice/data/invoice_model.dart`
  - owns `final ToMany<Item> items = ToMany<Item>()`.
  - still exposes `addItem`, `removeItem`, `clearItems`, and `sortedItems`.
- `lib/features/invoice/providers/invoice_notifier.dart`
  - loads `invoice.items.toList()` on edit.
  - keeps `state.items` and `state.lines` in lockstep.
  - clears and re-adds legacy items on save before replacing `Invoice.lines`.
- `lib/features/invoice/invoice_line_view.dart`
  - `InvoiceLineReader.resolve` prefers `lines`, then falls back to legacy `items`.
  - `fromInvoice` reads both `invoice.lines` and `invoice.items`.
  - `subtotalCents` accepts both `lines` and `items`.
- `lib/features/invoice/data/invoice_local_source.dart`
  - `getInvoiceItems`, `addItemToInvoice`, `removeItemFromInvoice`, `clearItemsFromInvoice`.
- `lib/features/invoice/data/invoice_repository.dart`
  - exposes `addItemToInvoice` and `clearItemsFromInvoice`.
- `lib/features/invoice/data/invoice_line_backfill.dart`
  - reads legacy `Invoice.items` to create `InvoiceLine` rows.
- `lib/features/invoice/data/invoice_item_orphan_cleanup.dart`
  - scans `Invoice.items` to decide which legacy `Item` rows are still referenced.
- `lib/core/database/objectbox-model.json` and `lib/core/database/objectbox.g.dart`
  - contain the `Invoice.items` relation metadata.
- Tests:
  - `invoice_line_view_test.dart`
  - `invoice_subtotal_source_test.dart`
  - `invoice_line_reader_objectbox_test.dart`
  - `invoice_line_backfill_objectbox_test.dart`
  - `invoice_line_dualwrite_objectbox_test.dart`
  - `invoice_repository_objectbox_test.dart`
  - `invoice_item_orphan_cleanup_objectbox_test.dart`
  - `pdf_generation_test.dart`

### `Item`

- `lib/features/item/item_model.dart`
  - defines the ObjectBox `Item` entity.
- `lib/features/invoice/presentation/pages/invoice_form_page.dart`
  - still creates `Item` instances for form rows.
- `lib/features/invoice/providers/invoice_state.dart`
  - holds `List<Item>? items`.
- `lib/features/invoice/providers/invoice_notifier.dart`
  - public methods are still named `addItem`, `updateItem`, `removeItem`.
- `lib/features/invoice/invoice_form_line.dart`
  - pairs an `Item` with authoritative `quantityMilli`.
- `lib/features/invoice/invoice_line_builder.dart`
  - supports `fromItems`.
- `lib/features/invoice/invoice_line_view.dart`
  - supports `InvoiceLineView.fromItem`.
- `lib/features/invoice/data/invoice_validation.dart`
  - validates `List<Item>`.
- `lib/features/invoice/data/invoice_money_backfill.dart`
  - scans and updates `Item` money fields.
- `lib/features/invoice/data/invoice_item_orphan_cleanup.dart`
  - scans/deletes legacy `Item` rows.
- `lib/core/database/objectbox-model.json` and `lib/core/database/objectbox.g.dart`
  - contain the `Item` entity and generated query metadata.
- Tests:
  - `test/features/item/item_enum_parse_test.dart`
  - invoice line reader/builder/form/parity/subtotal tests
  - ObjectBox backfill/dual-write/cleanup/repository tests
  - PDF generation tests with legacy `Item` fixtures

### `Item.invoiceId`

- `lib/features/item/item_model.dart`
  - defines the scalar `invoiceId` field.
- `lib/core/database/objectbox-model.json`
  - contains the `Item.invoiceId` property.
- `lib/core/database/objectbox.g.dart`
  - contains generated read/write/query metadata for `Item.invoiceId`.
- `lib/features/invoice/data/invoice_item_orphan_cleanup.dart`
  - documents that `Item.invoiceId` is never set and is not a safe ownership source.

No production search hit showed meaningful runtime use of `Item.invoiceId` as an ownership relation.

### `item_model.dart`

`item_model.dart` is still imported by invoice form, invoice state/notifier, invoice repository/local source, line adapters/builders, cleanup/backfill, and legacy-focused tests. It cannot be deleted until the form state no longer depends on `Item` as the temporary line carrier and the ObjectBox schema no longer includes the entity.

### `stockQuantity`

- Still present on `Item`.
- Still used as the legacy quantity source in:
  - `InvoiceFormLine.fromItem`
  - `InvoiceLineMath.quantityMilliFromLegacy`
  - `InvoiceLineBuilder.fromItems`
  - `InvoiceLineView.fromItem`
  - `InvoiceLineBackfill`
  - `InvoiceValidation`
  - many legacy/compatibility tests
- Still written from the decimal form as a compatibility value via `InvoiceFormLine.legacyQuantityFor`.

### Legacy Item Tests

Tests currently prove the compatibility path rather than retirement:

- legacy fallback: `invoice_line_view_test.dart`, `invoice_subtotal_source_test.dart`, `invoice_line_reader_objectbox_test.dart`
- backfill: `invoice_line_backfill_objectbox_test.dart`
- dual-write: `invoice_line_dualwrite_objectbox_test.dart`
- cleanup: `invoice_item_orphan_cleanup_test.dart`, `invoice_item_orphan_cleanup_objectbox_test.dart`, `legacy_item_cleanup_format_test.dart`
- item model formatting/parsing: `item_enum_parse_test.dart`
- repository relation preservation: `invoice_repository_objectbox_test.dart`
- PDF legacy fixtures: `pdf_generation_test.dart`

These should be rewritten or retired in the same staged order as the production code.

## Retirement Strategy

### 4E-1: Remove Production Reads From Legacy Fallback If Safe

Goal: prove production runtime no longer needs `Invoice.items`.

- Change `InvoiceLineReader` production callers to require `InvoiceLine` rows.
- Keep a separate test-only or migration-only helper for legacy fallback if still needed.
- Edit invoice loading should prefer `invoice.lines` without requiring an equal count with legacy items.
- Detail, PDF, and subtotal should fail visibly or show empty only when `Invoice.lines` is empty after a guaranteed backfill.
- Do not remove schema in this step.
- Keep backfill available until migration/open verification proves all old invoices have lines.

Exit criteria:

- No production detail/PDF/subtotal path reads `Invoice.items`.
- Old invoice fixtures pass because backfill created `InvoiceLine` rows first.
- ObjectBox tagged tests pass.

### 4E-2: Remove Write To Legacy `Invoice.items`

Goal: stop creating or mutating legacy `Item` rows.

- Replace form state carrier from `Item + InvoiceFormLine` to an `InvoiceLine`-native draft line model.
- Save/update should call only `replaceInvoiceLines`.
- Remove calls to `clearItemsFromInvoice` and `addItemToInvoice`.
- Remove `InvoiceRepository.addItemToInvoice` / `clearItemsFromInvoice` only after no callers remain.
- Keep the schema for one compatibility release if choosing the conservative fallback strategy.

Exit criteria:

- Creating/editing invoices writes no new `Item` rows.
- Decimal quantity persists through `InvoiceLine.quantityMilli`.
- ObjectBox tagged create/edit tests assert `Invoice.lines` only.

### 4E-3: Remove `Item.invoiceId` If Unused

Goal: remove dead scalar ownership field before or with entity retirement.

- Confirm no production or test code uses `Item.invoiceId`.
- Remove the field only in a schema-change step with generated ObjectBox files regenerated.
- If the entire `Item` entity is removed in 4E-4, this is subsumed by entity removal.

Exit criteria:

- Generated model opens an existing store in a native ObjectBox migration test.

### 4E-4: Remove `Item` Model Only If No References Remain

Goal: delete the legacy entity only after code and tests no longer import it.

- Delete `lib/features/item/item_model.dart` only if no app feature uses catalog/inventory concepts.
- Remove `Invoice.items` from `Invoice`.
- Remove legacy relation helper methods from `Invoice`.
- Remove legacy cleanup service or keep only a pre-retirement branch/tool. Once `Item` is removed from schema, cleanup cannot run in the new app version.
- Remove item-specific tests or rewrite them against the new draft-line model.

Exit criteria:

- `rg "features/item/item_model.dart|\\bItem\\b|stockQuantity|Invoice\\.items|\\.items"` has no legacy invoice hits except unrelated collection variables and generated files pending regeneration.

### 4E-5: Regenerate ObjectBox Files

Goal: update schema/generated code once model changes are complete.

- Run the approved generator command for the project.
- Review `objectbox-model.json` carefully:
  - retired entity/property/relation UIDs must be recorded, not reused.
  - `InvoiceLine` UIDs must remain stable.
  - `Invoice`, `Tax`, `Term`, `Business`, `Client`, `Signature` UIDs must remain stable.
- Review `objectbox.g.dart` for expected removal only:
  - no `Item` entity definition,
  - no `Invoice.items` relation query,
  - no `Item.invoice` relation query,
  - no unrelated entity changes.

Exit criteria:

- Generated diff is narrow and explained in the implementation commit.

### 4E-6: Migration/Open Verification

Goal: prove the new schema opens real old stores.

- Create or keep a fixture store from the pre-4E schema with:
  - invoices with legacy `Item` rows,
  - invoices with `InvoiceLine` rows,
  - invoices with both,
  - invoices with decimal quantity lines,
  - orphan `Item` rows.
- Back up the fixture.
- Open it with the 4E build.
- Assert:
  - old invoices open,
  - line rows remain,
  - totals/detail/PDF are correct,
  - removed legacy rows/entities do not crash store open,
  - old build downgrade behavior is documented.

## Fallback Strategy

### Option A: Keep Legacy Fallback For One More Release

Pros:

- Lower data-loss risk if any invoice missed backfill.
- Allows a release where new writes stop using `Item`, but old stores can still be inspected through fallback.
- Gives time for production dry-run reports and support telemetry/manual QA.

Cons:

- Keeps `Item`, `Invoice.items`, and cleanup code alive longer.
- Users may keep accumulating legacy rows until writes are fully stopped.
- More branching in readers/tests.

### Option B: Remove Immediately After Gates

Pros:

- Ends duplicate model complexity.
- Removes orphan cleanup need from the shipped app.
- Simplifies invoice line code and tests.

Cons:

- Highest migration risk.
- Any invoice without `InvoiceLine` rows loses its displayable line source.
- Store open and downgrade failures become harder to recover from.
- Cleanup cannot run after `Item` schema removal.

Recommendation: use Option A unless a native ObjectBox migration/open test proves every production-like store is safely backfilled and manual QA passes. Stop legacy writes first, keep fallback/schema for one release, then remove schema in a later Stage 4E substep.

## Data Migration Strategy

- Existing `Item` rows are legacy data. They should either:
  - remain readable for one compatibility release, or
  - be cleaned up before the schema removes `Item`.
- Orphan cleanup should run before schema removal if the team wants to delete legacy rows intentionally. After entity removal, cleanup code cannot target `Item`.
- `InvoiceLine` backfill must be guaranteed before removing fallback:
  - run the backfill on startup or as an explicit migration until a durable completed marker exists,
  - verify each invoice that had legacy items now has matching `InvoiceLine` rows,
  - verify decimal `quantityMilli` rows are preserved and not rebuilt from `stockQuantity`.
- To protect old invoices:
  - block schema removal if any invoice has no `InvoiceLine` rows but has or had legacy items,
  - keep external backup/export before migration,
  - add an ObjectBox fixture open test from a pre-4E store.

## ObjectBox Schema Risk

- Entity removal risk: deleting `Item` removes generated APIs and query metadata; any missed import/caller fails compile. Existing stores with `Item` rows must be proven to open and migrate.
- Relation removal risk: deleting `Invoice.items` removes a to-many relation from `Invoice`; stale relation metadata must be retired correctly by ObjectBox.
- UID/model file risk: never hand-edit UIDs. Regenerate and review retired UIDs. UID reuse can corrupt migrations.
- Downgrade risk: after the store is opened with a schema that removed `Item`, older app versions may not open the store or may behave incorrectly. Treat Stage 4E as a one-way app upgrade unless tested otherwise.
- Store open risk: ObjectBox tagged tests in the current environment are blocked by missing `libobjectbox.dylib`; Stage 4E implementation must not proceed until native-lib migration/open tests run.

## Tests Needed

- Old invoice opens after schema change.
- Invoice with only `InvoiceLine` rows opens.
- Invoice create/edit with decimal quantity works.
- PDF generation uses only `InvoiceLine` rows and totals correctly.
- Detail page uses only `InvoiceLine` rows and shows decimal quantity.
- Invoice form save/update does not create legacy `Item` rows once 4E-2 lands.
- Orphan cleanup is either removed as no longer applicable, or remains dev-only until schema removal.
- ObjectBox migration/open test using a pre-4E fixture store.
- Regression test that an invoice missing lines is caught before fallback removal, not silently displayed with zero items.

## Manual QA Checklist

- [ ] Create a new invoice with whole quantity.
- [ ] Create a new invoice with decimal quantity.
- [ ] Edit an invoice and save.
- [ ] Save/reopen decimal qty 1.5 and 0.25.
- [ ] Detail page shows line names, quantities, prices, and totals.
- [ ] PDF preview/share shows line names, decimal quantities, and correct totals.
- [ ] Settings -> Maintenance cleanup screen still behaves as expected before schema removal.
- [ ] Old invoice from before the migration opens correctly.
- [ ] Old invoice from before the migration can be edited and re-saved.
- [ ] Production-like dry-run report is reviewed before any real delete.
- [ ] Backup/export restore is verified before schema retirement.

## Implementation Stop Points

- Stop if ObjectBox tagged tests still fail for any reason other than missing native library.
- Stop if a pre-4E fixture store cannot open.
- Stop if any invoice can exist with legacy items but no `InvoiceLine` rows.
- Stop if generated ObjectBox diff changes unrelated entities.
- Stop if stash/user UI changes conflict with docs or implementation branches.
