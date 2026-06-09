# Invois Audit Report

> Read-only audit. No source files were modified. Date: 2026-06-09. Branch: `s6-hardening`.

## Summary

The codebase is **well-structured and healthier than average** for an app of this size (~26k LOC). The layering (local source → repository → notifier/state → UI) is consistent, the money spine is being migrated to integer minor-units (S3) with dual-write and a backfill, parsing is defensive (`SafeParse`, safe `fromName`), PDF generation flows across pages, and there is a real unit-test suite (77 passing).

However, there are a handful of **genuine correctness and completeness gaps** that matter for an invoicing app:

1. The invoice **edit/view form parses enums with `.values.byName()`**, which throws on any legacy/unknown stored value — a latent crash that the model's own safe `fromName` was written to avoid.
2. **"Mark as Sent" and "Record Payment" are not implemented** (buttons are disabled), and the only payment path (status → "paid" via the home dialog) does not update `paidAmount`/`balanceDue`/`paymentStatus`, producing invoices that read "Paid" while still showing a balance due.
3. **Line-item quantity is stored in `Item.stockQuantity`** (an inventory field), is integer-only, and leaves **orphaned `Item` rows** on every edit because of a duplicate Invoice↔Item relation.
4. **Data-at-rest is unencrypted** (PII) — already documented as blocked by ObjectBox edition.

Most other findings are medium/low: PDF tax breakdown vs. total can diverge if a tax is edited after invoicing, a startup full-scan, some state-coupling in the preview page, currency-symbol inconsistencies, and a meaningful amount of dead code.

**Tooling results**
- `flutter analyze`: **No issues found** (exit 0).
- `flutter test`: **77 passed, 1 skipped** (the skip is a pre-existing PDF golden/skip, unrelated to these findings). No failures.

## Stage 1 — Completed (2026-06-09)

Low-risk, no-schema fixes. No ObjectBox schema or generated files touched; no dependencies changed; no unrelated refactors; payment lifecycle not started.

**Fixes completed**
- **P1-001 (enum safe parse):** Replaced `Enum.values.byName(stored)` with safe `fromName`/guarded lookups on persisted values.
  - `invoice_form_page.dart`: invoiceType/status/paymentStatus/recurringFrequency now use the model's safe parsers.
  - `item_model.dart`: `displayUnit`/`unitDisplay`/`itemTypeDisplay` now use new private safe helpers (`_itemTypeFromName` → `other`, `_itemUnitFromName` → raw string fallback).
  - Added `RecurringFrequencyExtension.fromName` (was missing) → defaults to `monthly`.
  - *Note:* `home_page.dart:55` `InvoiceStatus.values.byName(_selectedFilter.name)` was intentionally left — it parses a controlled in-app filter enum (never a stored/legacy value), so it cannot throw on bad data.
- **P2-008 (PDF filename sanitize):** Added public `InvoiceGenerator.sanitizeFileName` + `_invoiceFileBase`; applied to `printInvoice` (name), `shareInvoice` and `saveInvoice` (filenames). Illegal path chars (`/ \ : * ? " < > |`, control chars) → `-`; never empty.
- **P2-005 (currency symbol):** `Item.formattedPrice`/`formattedPriceWithTax` and `Invoice.formattedTotal`/`formattedBalanceDue`/`formattedPaidAmount` now render via `CurrencyUtils.getSymbol(code)` instead of using the raw currency code as the symbol. *Transparency note:* these getters are currently **unused** (dead) — there is no live display bug today; the fix makes them correct for future use and is harmless. (The dead `Invoice.formattedCurrency` getter was left in place; its removal is P3 cleanup, out of this stage's scope.)
- **P2-009 (provider misuse):** `invoice_form_page.dart` `_onDeleteInvoice` and `_showDeleteConfirmation` now use `ref.read` instead of `ref.watch` inside callbacks.

**Files changed**
- `lib/features/invoice/data/invoice_model.dart` — `RecurringFrequencyExtension.fromName`; `CurrencyUtils` import; `formatted*` symbol fix.
- `lib/features/invoice/presentation/pages/invoice_form_page.dart` — safe enum parse (4 sites); `ref.watch`→`ref.read` (2 sites).
- `lib/features/item/item_model.dart` — safe `ItemType`/`ItemUnit` parsing; `CurrencyUtils` import; symbol fix; new private helpers.
- `lib/features/invoice/pdf/invoice_generator.dart` — `sanitizeFileName`/`_invoiceFileBase`; applied to print/share/save.
- `test/features/item/item_enum_parse_test.dart` — **new** (item enum safe parse + currency symbol).
- `test/features/invoice/pdf_filename_sanitize_test.dart` — **new** (sanitizer).
- `test/features/invoice/invoice_status_parse_test.dart` — added `RecurringFrequencyExtension.fromName` group.

**Test result**
- `flutter analyze` → **No issues found** (exit 0).
- `flutter test` → **91 passed, 1 skipped** (was 77; +14 new cases). The skip is the pre-existing unrelated PDF skip.

**Remaining risks after Stage 1**
- All P1 schema/lifecycle items remain: **P1-002** (sent/paid lifecycle), **P1-003** (quantity field), **P1-004** (signature `@Unique` nulls — still needs verification).
- **P2-001/002** (orphaned items + duplicate relation), **P2-003** (PDF tax snapshot), **P2-004** (startup backfill scan), **P2-006** (preview shared provider), **P2-007** (add-item sheet overflow/`"null"` qty) remain.
- P1-001 form fix is covered indirectly (model parsers are unit-tested) but **no widget test yet** opens the form on a legacy invoice end-to-end — recommended in a later stage.
- All P3 cleanup remains.

---

## Stage 2 — Completed (2026-06-09) — P1-002 Sent/Paid lifecycle

Wired the previously-dead `markAsSent`/`markAsPaid` through repository → notifier → UI, and made the status path reconcile payment fields. No ObjectBox schema or generated files touched; no dependencies changed; P1-003/quantity and @Backlink/orphan work untouched.

**Fixes completed**
- **Single source of truth for payment math:** new pure, store-free `InvoicePayment` (`lib/features/invoice/invoice_payment.dart`) computes `paid/balance/paymentStatus` (full, partial, overpay, unpaid). `InvoiceLocalSource.markAsPaid` now delegates to it (no duplicated arithmetic).
- **Status path reconciles "paid":** `InvoiceFormNotifier.updateInvoiceStatus` now routes `InvoiceStatus.paid` through `markAsPaid` instead of writing the status alone. This fixes the audit's core symptom — the home "Change Status" dialog can no longer produce a "Paid" invoice that still shows `balanceDue == total` / `paymentStatus == unpaid`.
- **Mark as Sent:** `markAsSent` exposed on the repository and notifier (`markInvoiceAsSent`); sets `status=sent` + `sentDate`, leaves payment fields untouched.
- **Mark as Paid (full):** `markAsPaid` exposed on the repository and notifier (`markInvoiceAsPaid`); sets `paidAmount=total`, `balanceDue=0`, `paymentStatus=paid`, `status=paid`, `paidDate`, with the legacy double dual-write kept consistent.
- **Detail UI wired:** the two previously-`onPressed: null` buttons are live — "Mark as Sent" (enabled when `status==draft` and the invoice has items) and the former "Record Payment" relabelled to **"Mark as Paid"** (enabled via `Invoice.canMarkAsPaid`). Both use the existing snackbar style, surface errors from notifier state, and `ref.invalidate(invoiceDetailProvider(id))` after success.
- **Reactivity:** list, dashboard overview, and home all read the `invoiceListProvider` stream, so they update automatically on the write; the one-shot detail `FutureProvider` is explicitly invalidated.
- **Riverpod hygiene:** new UI callbacks use `ref.read` (not `ref.watch`).

**Files changed**
- `lib/features/invoice/invoice_payment.dart` — **new** pure helper.
- `lib/features/invoice/data/invoice_local_source.dart` — `markAsPaid` delegates to `InvoicePayment`.
- `lib/features/invoice/data/invoice_repository.dart` — added `markAsSent` / `markAsPaid` (`Result`).
- `lib/features/invoice/providers/invoice_notifier.dart` — `updateInvoiceStatus` reconciles paid; added `markInvoiceAsSent` / `markInvoiceAsPaid`.
- `lib/features/invoice/presentation/pages/invoice_detail_page.dart` — enabled + wired the two actions, with guards/snackbars/invalidate.
- `test/features/invoice/invoice_payment_test.dart` — **new** (pure unit tests).
- `test/features/invoice/invoice_repository_objectbox_test.dart` — new `payment lifecycle` group (markAsSent/markAsPaid/partial/**item-preservation**), objectbox-tagged.

**Tests added**
- 6 pure unit tests (`InvoicePayment`) — run in the default suite.
- 5 ObjectBox integration tests (sent, full paid + dual-write, partial, item preservation) — **objectbox-tagged**.

**Test result**
- `flutter analyze` → **No issues found**.
- `flutter test` → **97 passed, 1 skipped** (was 91; +6).
- ⚠️ The 5 new objectbox-tagged tests **could not be executed in this environment** — `libobjectbox.dylib` isn't available for host Dart-VM tests here (`flutter test --tags objectbox --run-skipped` fails to load the native lib). They compile cleanly (verified via `flutter analyze`) and should run in the team's objectbox CI. **Run `flutter test --tags objectbox --run-skipped` on a machine with the native lib to confirm.**

**Is P1-002 fully fixed?**
- **Mark as Sent:** ✅ fully wired.
- **Mark as Paid (full):** ✅ fully wired; status/payment now always consistent.
- **Home status→paid inconsistency:** ✅ fixed (reconciles).
- **Partial payment (with amount entry):** ⚠️ *partial.* The data path supports it (`markAsPaid(paidAmount:)`, `InvoicePayment.pay`, partial test), but **no amount-input UI** was added (kept out of scope — "smallest safe version"). Exposed only as full payment in the UI.
- **Mark as Unpaid / reversing a payment:** ❌ not implemented — the app had no such concept; left as future work. Consequently, reverting a *paid* invoice to a non-paid status via the home dialog still leaves `paymentStatus`/`paidAmount` as paid (forward consistency is fixed; reverse is future work).

**Remaining risks after Stage 2**
- Relation preservation on `markAsPaid`/`markAsSent` relies on the same `updateInvoiceFields` (`copyWith`+`put`) path the shipped `updateInvoiceStatus` already uses on item-bearing invoices; an objectbox-tagged test now asserts items survive, but it was not run here.
- Partial-payment UI and Mark-as-Unpaid are future work.
- All P1-003 (quantity/schema), P2-001/002 (orphans/@Backlink), P2-003/004/006/007 and P3 items remain.

---

## Stage 2B — Completed (2026-06-09) — close the reverse-transition gap (P1-002)

Closes the remaining divergence: reverting a paid invoice to a non-paid status no longer leaves the payment fields reading "paid". No ObjectBox schema/generated-file changes; no quantity/@Backlink work; no dependency changes; no partial-payment UI added.

**Behaviour now enforced (single invariant)**
`status == paid  ⟺  fully paid` ; `status != paid  ⟹  unpaid`. Every status-changing UI funnels through `InvoiceFormNotifier.updateInvoiceStatus`, which routes:
- `paid` → `markAsPaid` (paid=total, balance=0, paymentStatus=paid).
- `sent` → `markAsSent` (status+sentDate; payment reconciled to unpaid).
- any other status → `markAsUnpaid(status:)` (payment reconciled to unpaid: paid=0, balance=total, paymentStatus=unpaid).

**Fixes completed**
- New pure invariant helper `InvoicePayment.forStatus(status, totalCents)` — the store-free source of truth (paid→paid, else→unpaid).
- `InvoiceLocalSource`: new private `_applyStatusReconcilingPayment` (uses `forStatus`); `markAsSent` now reconciles payment; new `markAsUnpaid(id, {status})`. `markAsPaid` unchanged (still supports partial + paidDate).
- `InvoiceRepository`: new `markAsUnpaid` (`Result`).
- `InvoiceFormNotifier.updateInvoiceStatus`: three-way routing (paid / sent / other) — all reconcile.
- **Entry-point audit:** the only status-writing UIs are the home "Change Status" dialog (`updateInvoiceStatus`) and the detail actions (`markInvoiceAsSent`/`markInvoiceAsPaid`); both already route through the notifier. The invoice list partial only navigates; `home_page` `setStatus` is the list *filter*, not a status write. No UI mutates status directly.

**Files changed**
- `lib/features/invoice/invoice_payment.dart` — `forStatus`.
- `lib/features/invoice/data/invoice_local_source.dart` — `_applyStatusReconcilingPayment`, `markAsSent` (reconciles), `markAsUnpaid`.
- `lib/features/invoice/data/invoice_repository.dart` — `markAsUnpaid`.
- `lib/features/invoice/providers/invoice_notifier.dart` — `updateInvoiceStatus` three-way reconciling routing.
- `test/features/invoice/invoice_payment_test.dart` — `forStatus` invariant group.
- `test/features/invoice/invoice_repository_objectbox_test.dart` — paid→sent, paid→draft, and item-preservation-on-unpaid (objectbox-tagged).

**Tests added**
- 2 pure unit tests (`forStatus`: paid→paid; every non-paid status→unpaid) — default suite.
- 3 ObjectBox integration tests (paid→sent reconciles, paid→draft reconciles, markAsUnpaid preserves items) — **objectbox-tagged**.

**Test result**
- `flutter analyze` → **No issues found**.
- `flutter test` → **99 passed, 1 skipped** (was 97; +2).
- ⚠️ ObjectBox-tagged tests still **could not run here** (`libobjectbox.dylib` unavailable). They compile (verified by analyze). **Run `flutter test --tags objectbox --run-skipped` on a machine with the native lib** to confirm Step 2 + 2B integration tests.

**Decisions / conservative rules (as requested)**
- **No partial-payment entry UI exists**, so any non-paid status maps to *fully* unpaid. A hypothetical partial payment (only creatable via the data-layer `markAsPaid(paidAmount:)`, not the UI) would be reset on a status revert — acceptable given no partial UI; revisit if/when partial-payment UI lands.
- `cancelled` / `refunded` are treated as non-paid → unpaid under the uniform rule. There is no payment-history feature, so the prior paid amount is not retained. Flagged as a future nuance (a real `refunded` flow would keep a record).
- `paidDate` is **not cleared** on revert (the `copyWith`-based `updateInvoiceFields` can't write null without touching shared semantics/schema). It's cosmetic and not shown on the detail screen; the meaningful fields (status/paidAmount/balanceDue/paymentStatus) are reconciled. Noted as minor future cleanup.

**Is P1-002 now fully closed?**
- **Yes for status/payment consistency** — forward (→paid) and reverse (paid→any) transitions are reconciled across all entry points; status and payment can no longer diverge. Covered by pure unit tests (invariant) + objectbox-tagged integration tests (persistence; pending a native-lib run).
- **Remaining (separate, non-divergence) future work:** a real partial-payment **amount-entry UI**, a payment-history/refund model, and clearing `paidDate` on revert. These are enhancements, not the consistency bug.

**Remaining risks after Stage 2B**
- ObjectBox-tagged tests unverified in this environment (need native lib).
- Relation preservation continues to rely on the existing shared `updateInvoiceFields` path (now asserted by tagged tests, not run here).
- `cancelled`/`refunded` semantics simplified to unpaid; `paidDate` retained on revert.
- All P1-003/P2/P3 items remain untouched.

---

## Stage 3A — Verification of P1-004 (signature nullable `@Unique`)

Verification-only. No schema, generated-file, dependency, or app-code changes — just characterisation tests + this finding.

**What was inspected**
- `signature_model.dart` — `@Unique() String? email;`, `@Unique() String? phone;`.
- `objectbox-model.json` — email/phone `flags: 2080` = `UNIQUE (0x20) | INDEX_HASH64 (0x800)`, **no `NOT_NULL (0x4)`** ⇒ both **unique and nullable**.
- `signature_form_page.dart` — email **and** phone are `isRequired: true` with "is required" validators; blanks are normalised to `null` via `StringUtils.nullIfBlank` (not `""`).
- `signature_local_source.insertSignature` / `SignatureRepository.create` — a put failure (incl. `UniqueViolationException`) is caught and surfaced as `Err`, not thrown.
- Schema sweep of all entities (see table below).

**Entities sharing the pattern (global `@Unique`, nullable):**

| Entity | email | phone |
|--------|-------|-------|
| Business | unique | unique |
| Client | unique | not unique |
| Signature | unique | unique |

**Findings**
1. **Confirmed:** email/phone on Signature are `@Unique` + nullable (and the same global-unique pattern exists on Business and Client.email).
2. **The originally-feared symptom is NOT reachable via the UI.** The signature form *requires* non-empty email and phone, so a contactless signature can't be created through the app — the "second contactless signature blocked by null-unique" scenario can't occur in normal use.
3. **Empty-string conflict is avoided** at the form layer: blanks become `null` (`nullIfBlank`), so two blank-contact signatures would store `null`, not `""`. (The *model/repository* do **not** normalise `""`→`null`; a non-UI caller passing `""` could still collide. Optional hardening below.)
4. **The real latent defect is GLOBAL uniqueness, not null handling.** Because the unique index is app-wide, a user cannot:
   - reuse the same email/phone for signatures across their **own multiple businesses**, or
   - have two signatures (or businesses/clients) share contact info,
   even though that is legitimate. This is almost certainly the bug worth fixing, and it is **per-entity scope / index design** — a **schema change**.
5. **Null-unique runtime behaviour is UNVERIFIED here** (no native `libobjectbox.dylib`). Best-known ObjectBox behaviour is that a unique index permits multiple null values; the added tagged tests assert this and will fail if it doesn't hold.

**Tests added** (`test/features/signature/signature_unique_objectbox_test.dart`, objectbox-tagged):
- two null email+phone signatures both succeed (expected rule);
- two null-contact signatures under the same business both succeed;
- duplicate non-empty email rejected (characterises current global uniqueness);
- same email across different businesses rejected (demonstrates uniqueness is global, not per-business).

**Verification commands**
- `flutter analyze` → No issues found (compiles the new tagged test).
- `flutter test` → unchanged default suite (tagged tests skipped).
- **Run the verification on a machine with the native lib:** `flutter test --tags objectbox --run-skipped`.

**Is P1-004 confirmed?**
- The annotation (nullable `@Unique`) is **confirmed**.
- The *UI-blocking* symptom is **not confirmed** (email/phone are required, so contactless signatures aren't created via the app).
- The *meaningful* defect — **global uniqueness preventing legitimate reuse of contact info across businesses** — is **confirmed by inspection** and characterised by tagged tests (pending a native-lib run).

**Does it need a schema change?** **Yes** — the fix (drop `@Unique`, or replace with app-level/per-business uniqueness) changes the ObjectBox model. Per scope, **not done here.**

### Proposed Step 3B (schema-safe fix — needs approval)
- **Decide the rule** per field: (a) drop uniqueness on contact fields entirely (simplest; rely on app validation), or (b) enforce uniqueness per `businessId` at the app layer (query-before-save) while removing the DB `@Unique`.
- **Apply to Business, Client.email, Signature** consistently.
- **Schema/migration:** removing `@Unique` drops the unique index → bumps `objectbox-model.json` + regenerates `objectbox.g.dart`. ObjectBox tolerates dropping an index without data migration, but the model id/uid bookkeeping must be regenerated via the build runner (not hand-edited). Risk: low-to-moderate (index removal is non-destructive to row data; must regenerate, not edit, generated files).
- **Optional non-schema hardening (could ship first):** normalise `""`→`null` for contact fields in the repositories/models so non-UI callers can't trip the index with empty strings.
- **Tests:** flip the duplicate-email tagged tests to assert the chosen rule; add per-business uniqueness tests if option (b).

**Remaining risks after 3A**
- Tagged tests unverified in this environment (need native lib).
- Global-unique defect remains until Step 3B.
- `""`→`null` normalisation only at the form layer (non-UI callers unguarded).

---

## Stage 3B — Completed (2026-06-09) — remove Signature global contact uniqueness (P1-004)

Scope: **Signature only.** Business and Client uniqueness, invoice quantity/schema, @Backlink/orphan work — all untouched.

**Decision applied:** Signature `email`/`phone` are contact fields, not identity fields → DB-level global `@Unique` removed; no per-business DB constraint added. Multiple signatures may share contact info (within or across businesses), and contactless signatures are permitted. Existing form validation (email/phone still `isRequired`) is unchanged — no contactless-signature UI introduced.

**Schema change made (via generator, not hand-edited)**
- `signature_model.dart`: removed `@Unique()` from `email` and `phone` (now plain, non-unique, non-indexed `String?`).
- Regenerated with `dart run build_runner build` (objectbox generator). Result (verified): `Signature.email`/`phone` `flags 2080 → 0` (unique + hash64 index dropped). `Business` (email+phone) and `Client.email` remain `flags 2080` — **unchanged**.
- Generated diff is small/surgical: `objectbox-model.json` (−unique flags, index UIDs retired) and `objectbox.g.dart` (property flag/reader changes).

**Why it's safe / non-destructive**
- Dropping a unique index is **not** a data migration: existing rows are untouched; ObjectBox just stops enforcing/maintaining that index (the index UIDs are retired in the model so the ids aren't reused).
- No field added/removed/retyped; no entity renamed. The store opens against the existing data unchanged.
- Generated files were produced by the generator, not edited by hand.

**Defensive normalisation (repository layer)**
- `SignatureRepository.create`/`update` now run contact fields through `StringUtils.nullIfBlank` (trim; blank → null) via a private `_normalizeContact` (builds a normalised instance, since `copyWith` can't set null). This protects non-UI callers, not just the form.

**Files changed**
- `lib/features/signature/data/signature_model.dart` — removed `@Unique` on email/phone.
- `lib/core/database/objectbox-model.json`, `lib/core/database/objectbox.g.dart` — regenerated.
- `lib/features/signature/data/signature_repository.dart` — `_normalizeContact` + `StringUtils` import, applied in create/update.
- `test/features/signature/signature_unique_objectbox_test.dart` — flipped to assert duplicates allowed + normalisation (objectbox-tagged).
- `test/core/string_utils_test.dart` — **new** pure unit tests for `nullIfBlank`.

**Tests added/updated**
- 6 pure unit tests (`StringUtils.nullIfBlank`: null/blank/whitespace → null; trims email/phone; clean value unchanged) — default suite.
- ObjectBox-tagged (rewritten): two null-contact allowed; same email same business allowed; same email across businesses allowed; same phone across businesses allowed; blank → null persisted; whitespace trimmed. Removed the old duplicate-rejection assertions.

**Test result**
- `flutter analyze` → **No issues found**.
- `flutter test` → **105 passed, 2 skipped** (was 99; +6).
- ⚠️ ObjectBox-tagged tests **could not run here** (`libobjectbox.dylib` unavailable). They compile (verified by analyze). **Run on a machine with the native lib: `flutter test --tags objectbox --run-skipped`** — this also exercises the regenerated model against a real store.

**Is P1-004 closed (for Signature)?** Yes — global contact uniqueness removed, normalisation added, behaviour characterised by tests (tagged run pending native lib).

### Future work — Step 3C (Business / Client contact uniqueness)
`Business.email`, `Business.phone`, and `Client.email` still carry the same **global `@Unique`** (flags 2080) and the same latent defect (can't reuse contact info / duplicates blocked app-wide). If the same "contact ≠ identity" decision applies, repeat this exact recipe per entity (remove `@Unique`, regenerate, normalise in repo, flip tests). **Out of scope for 3B; needs its own approval** (those forms/uniqueness expectations may differ from Signature).

**Remaining risks after 3B**
- ObjectBox-tagged tests unverified in this environment (need native lib) — including confirming the regenerated model opens cleanly against existing data.
- Business/Client global uniqueness remains (Step 3C).
- All P1-003/P2/P3 items remain.

---

## Stage 3C — Completed (2026-06-09) — remove Business & Client global contact uniqueness (P1-004)

Scope: **Business.email, Business.phone, Client.email** (uniqueness) + defensive contact normalisation. Signature untouched (already done in 3B); invoice quantity/schema, @Backlink/orphan, invoice/payment/PDF flows — all untouched.

**Decision applied:** email/phone are contact fields, not identity → DB-level global `@Unique` removed on Business.email, Business.phone, Client.email. No per-business DB constraint added; no new app-level duplicate-blocking (none existed — confirmed no `getByEmail`/`isEmailAvailable`/uniqueness checks anywhere). `Business.name` **remains `@Unique`** (genuine identity field) — deliberately kept. Existing form validation unchanged.

**Schema change made (via generator, not hand-edited)**
- `business_model.dart`: removed `@Unique()` from `phone` and `email` (kept it on `name`).
- `client_model.dart`: removed `@Unique()` from `email`.
- Regenerated with `dart run build_runner build`. Verified flags: `Business.email`/`phone` `2080 → 0`; `Client.email` `2080 → 0`; `Business.name` stays `2080`; `Signature.*` stay `0` (from 3B).
- Generated diff small/surgical: `objectbox-model.json` (unique flags removed, index UIDs retired) + `objectbox.g.dart` (flag/reader changes).

**Why it's safe / non-destructive**
- Dropping a unique index is not a data migration: rows untouched; ObjectBox stops maintaining the index and retires the index UIDs (not reused).
- No field added/removed/retyped; no entity renamed; `Business.name` uniqueness preserved.
- Generated files came from the generator.

**Defensive normalisation (repository layer)**
- `BusinessRepository` and `ClientRepository` `create`/`update` now run email/phone through `StringUtils.nullIfBlank` via a private `_normalizeContact`.
- To set null through the hand-written `copyWith` (which uses `?? this`), added `clearEmail`/`clearPhone` optional flags to `Business.copyWith` and `Client.copyWith` — matching the codebase's existing `clear*` idiom (e.g. `clearSignature`). No field-list duplication, so no risk of dropping fields.

**Files changed**
- `lib/features/business/data/business_model.dart` — removed `@Unique` (email/phone); `clearEmail`/`clearPhone` in copyWith.
- `lib/features/client/data/client_model.dart` — removed `@Unique` (email); `clearEmail`/`clearPhone` in copyWith.
- `lib/features/business/data/business_repository.dart` — `_normalizeContact` + `StringUtils` import, applied in create/update.
- `lib/features/client/data/client_repository.dart` — same.
- `lib/core/database/objectbox-model.json`, `lib/core/database/objectbox.g.dart` — regenerated.
- `test/features/business/business_unique_objectbox_test.dart` — **new** (objectbox-tagged).
- `test/features/client/client_unique_objectbox_test.dart` — **new** (objectbox-tagged).

**Tests added/updated**
- ObjectBox-tagged Business: same email allowed; same phone allowed; **name stays unique** (guards scope); blank → null; whitespace trimmed.
- ObjectBox-tagged Client: same email allowed; same email across businesses allowed; blank → null; whitespace trimmed.
- No new pure tests — normalisation reuses `StringUtils.nullIfBlank` (already unit-tested in 3B).

**Test result**
- `flutter analyze` → **No issues found**.
- `flutter test` → **105 passed, 4 skipped** (the 4 skips are the objectbox-tagged suites: signature, invoice-repo, business, client).
- ⚠️ ObjectBox-tagged tests **could not run here** (`libobjectbox.dylib` unavailable). They compile (verified by analyze). **Run on a machine with the native lib: `flutter test --tags objectbox --run-skipped`** — also confirms the regenerated model opens cleanly against existing data.

**Is P1-004 fully closed?** Yes — Signature (3B) + Business + Client (3C) contact uniqueness removed and normalised; characterised by tagged tests (pending native-lib run). No global contact-uniqueness defect remains. `Business.name` uniqueness intentionally retained.

**Remaining risks after 3C**
- ObjectBox-tagged tests + regenerated-model-open unverified in this environment (need native lib).
- All P1-003 (quantity/schema), P2-001/002 (orphans/@Backlink), and P2/P3 items remain untouched.

---

## Stage 4A — Plan created (P1-003 quantity + P2 item relation/orphans)

Planning only — **no app code, no ObjectBox schema, no generated files changed.**

- Wrote `doc/plans/step-4-quantity-relation-migration-plan.md` covering: current state (line items stored via the standalone `Invoice.items` ToMany; quantity overloaded onto `Item.stockQuantity`; a second dead `Item.invoiceId` ToOne with no `@Backlink`; orphans because `clear` drops links not rows), confirmed problems, business rules, target design, options, quantity representation, schema/migration/read-switch/orphan-cleanup plans, tests, QA, risks/rollback, ordering, and impacted files.
- **Recommended design:** dedicated **`InvoiceLine`** entity (Option A) with a single `@Backlink` relation, snapshot fields (name/desc/unit/unitPrice/tax), `sortOrder`, and decimal **`quantityMilli` (int, 1.000 = 1000)**; line total via exact integer half-up rounding. (Option C — embedded serialized lines — documented as the simpler fallback.)
- **Recommended next stage:** **4B** (additive `InvoiceLine` + `@Backlink` + idempotent backfill, regenerate via build_runner, objectbox-tagged tests) — needs its own approval and a native-lib test run; nothing is deleted until 4D.

---

## Stage 4B — Completed (2026-06-09) — additive InvoiceLine schema + idempotent backfill

Additive only. The legacy `Invoice.items` / `Item.stockQuantity` path **still drives all app reads/writes** (form, composer/totals, detail, list, PDF) — nothing was switched, removed, or deleted.

**What was added**
- New entity **`InvoiceLine`** (`lib/features/invoice/data/invoice_line_model.dart`): `id`, `ToOne<Invoice> invoice`, `sourceItemId?`, `name`, `description?`, `unit?`, `currency?`, `unitPriceCents` (cents), `quantityMilli` (`1000 = 1.000`), `taxRateBasisPoints?` (snapshot), `sortOrder`, `createdAt/updatedAt`.
- **`@Backlink() ToMany<InvoiceLine> lines` on `Invoice`** (canonical, single relation to the line's `ToOne`). `Invoice.items` kept intact.
- Pure helper **`InvoiceLineMath`**: `quantityMilliFromLegacy`, `lineTotalCents` (integer half-up), `formatQuantity`.
- **`InvoiceLineBackfill`** + report (mirrors `S3MoneyBackfill`), wired into `main()` after the money backfill.

**Backfill behaviour** (idempotent, non-destructive)
- Per invoice: skip if it already has `lines`; skip if it has no legacy `items`; else create one `InvoiceLine` per `Item` in legacy order (`sortOrder = index`), snapshotting `name/description/unit/currency`, `unitPriceCents = item.effectiveUnitPriceCents`, `quantityMilli = (stockQuantity ?? 1 / ≤0) → *1000`, tax rate as basis points.
- Never deletes/mutates `Item` rows; never changes invoice totals or the `items` relation; safe to run on every launch.

**Schema / generated files changed (via build_runner — not hand-edited)**
- `objectbox-model.json` + `objectbox.g.dart`: added `InvoiceLine` entity (+ its `invoiceId` ToOne backlinked by `Invoice.lines`). Verified `Invoice.items/taxes/terms` unchanged; purely additive diff.

**Files changed**
- New: `invoice_line_model.dart`, `invoice_line_math.dart`, `data/invoice_line_backfill.dart`.
- Edited: `invoice_model.dart` (import + `lines` backlink), `main.dart` (run backfill).
- Regenerated: `objectbox-model.json`, `objectbox.g.dart`.
- Tests: new `invoice_line_math_test.dart` (pure), new `invoice_line_backfill_objectbox_test.dart` (tagged).

**Tests added**
- Pure (16): `quantityMilliFromLegacy` (null/0/neg → 1000; 2→2000; 5→5000), `lineTotalCents` (whole/decimal/half-up/boundary/zero), `formatQuantity`.
- ObjectBox-tagged: creates one line per legacy item w/ order + snapshot; idempotent; doesn't delete Item rows; skips empty invoices; invalid qty → one unit; store opens with regenerated model.

**Test result**
- `flutter analyze` → **No issues found**.
- `flutter test` → **121 passed, 5 skipped** (was 105; +16 pure; +1 skipped tagged suite).
- ⚠️ ObjectBox-tagged tests **could not run here** (`libobjectbox.dylib` unavailable). Compile-verified by analyze. **Run on a native-lib machine: `flutter test --tags objectbox --run-skipped`** — this also confirms the regenerated model opens against existing data and the backfill behaves.

**Remaining risks after 4B**
- Tagged tests + regenerated-model-open + backfill behaviour unverified in this environment (need native lib) — **run before shipping**.
- App still reads/writes the legacy `items` path (intended); `InvoiceLine` data is written but not yet consumed.
- 4C (switch reads/writes), 4D (orphan cleanup), 4E (retire legacy relation) remain; all P2/P3 items remain.

---

## QA Checkpoint — Settings list freshness (2026-06-09)

- **Latest commit:** `052bd6f` — fix(settings): refresh lists after mutations.
- **Settings list refresh fix: completed.** Targeted `ref.invalidate(<feature>ListProvider)` added after successful create/update/delete (and signature set-default/activate/deactivate via `onUpsert`) in the five settings form pages, guarded by `mounted`. Defense-in-depth over the existing ObjectBox `watch` streams; no schema/generated/list-page changes.
- **Branch health:** `flutter analyze` → No issues found; `flutter test` → 121 passed, 7 skipped (the 7 skips are objectbox-tagged suites). Working tree clean.
- **Manual QA: still required** (see checklist below) — the runtime staleness was UI/runtime-path, so it must be confirmed on a device/emulator.
- **ObjectBox tagged tests: still pending** on a machine with native `libobjectbox.dylib`.
- **Step 4C (invoice quantity read/write switch): NOT started.** Invoice quantity/schema untouched.

### Manual QA checklist — Settings list freshness
- [ ] Add Term → list shows latest immediately
- [ ] Edit Term → list updates immediately
- [ ] Delete Term → item removed immediately
- [ ] Add Signature → list shows latest immediately
- [ ] Edit Signature → list updates immediately
- [ ] Delete Signature → item removed immediately
- [ ] Set default Signature → badge/status updates immediately
- [ ] Add/Edit/Delete Tax → list updates immediately
- [ ] Add/Edit/Delete Client → list updates immediately
- [ ] Add/Edit/Delete Business → list updates immediately
- [ ] Pull-to-refresh still works
- [ ] No duplicate items
- [ ] No stale item after delete

### ObjectBox runtime verification (run on a machine with `libobjectbox.dylib`)
- [ ] Run `flutter test --tags objectbox --run-skipped`
- [ ] Confirm InvoiceLine backfill tests pass
- [ ] Confirm signature/business/client uniqueness tests pass
- [ ] Confirm settings reactivity tests pass (`term`/`signature` watch emits after create/update/delete)

---

## Stage 4C-1 — Completed (2026-06-09) — InvoiceLine read adapter

Pure read adapter only — **no consumer switched, no writes changed, no schema/generated changes.**

- **Added:** `InvoiceLineView` (unified read shape) + `InvoiceLineReader` (`lib/features/invoice/invoice_line_view.dart`).
- **Fallback rule:** `resolve(lines, items)` → prefer `lines` (sorted by `sortOrder`); else legacy `items` in relation order (`sortOrder = index`). `fromInvoice(invoice)` wraps the ToMany for future consumers. Legacy quantity + line totals reuse `InvoiceLineMath` (no duplicated rounding); the Item→view mapping mirrors the 4B backfill.
- **Files:** new `invoice_line_view.dart`; new `test/features/invoice/invoice_line_view_test.dart` (11 pure tests); docs (`AUDIT_REPORT.md`, plan).
- **Tests:** prefers lines / falls back to items / empty→empty / legacy qty mapping (null/0/2) / line totals / order preserved / mixed→lines-only. All pure (no native store).
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 132 passed, 7 skipped (+11).
- **Not done (as scoped):** form/detail/PDF/composer/notifier untouched; no write switch; no orphan cleanup; `Invoice.items`/`Item`/`Item.invoiceId` retained.
- **Next:** Stage 4C-2 — switch the first read consumer (totals/composer or detail) to `InvoiceLineReader` behind this fallback, with tests; PDF/form later.

---

## Stage 4C-2 — Completed (2026-06-09) — invoice detail line-items via InvoiceLineReader

First read consumer switched. **Detail display only** — totals/composer, PDF, form, and the write path are untouched.

- **Changed:** `invoice_detail_page.dart` `_LineItemsSection` renders `InvoiceLineReader.fromInvoice(invoice)` → `InvoiceLineView` (`name`, `displayQuantity` × unit price, `lineTotalCents`) instead of mapping raw `Item` rows.
- **Fallback preserved:** legacy invoices (no lines) → `items` with identical whole-quantity display + totals; backfilled invoices → `lines`; both present → lines only; empty → unchanged empty state. No visual redesign.
- `data.items` still backs the `_ActionSection` "Mark as Sent" guard (unchanged).
- **Files:** `invoice_detail_page.dart` (import + `_LineItemsSection`); new objectbox-tagged `invoice_line_reader_objectbox_test.dart`; docs.
- **Tests:** the 4C-1 pure adapter tests cover the mapping/fallback; the new tagged test exercises `fromInvoice` against a real store (legacy fallback / backfilled-prefers-lines / empty). No native lib needed for the default suite.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 132 passed, 8 skipped (+1 tagged).
- **Not done (as scoped):** PDF (`invoice_generator`), totals (`invoice_composer`/notifier), form, and all writes untouched; no schema/generated changes; no orphan cleanup.
- **Next:** Stage 4C-3 — switch the next read consumer (totals/composer or PDF) behind the same fallback.

---

## Stage 4C-3 — Completed (2026-06-09) — PDF item table via InvoiceLineReader

PDF item table read path switched. **Item table only** — PDF totals, the composer/totals source of truth, the form, and the write path are untouched.

- **Changed:** `invoice_generator.dart` — `generateInvoice` resolves `InvoiceLineReader.fromInvoice(invoice)` once; empty-guard checks the resolved views; `_buildItemsTable` now takes `List<InvoiceLineView>` and renders `name` / `description` / `displayQuantity` (decimal-aware) / `unitPriceCents` / `lineTotalCents`. Removed the now-unused `item_model` import.
- **No totals mismatch:** `_buildTotalsSection` still uses stored `invoice.effective*Cents` + `invoice.taxes`. Legacy per-row totals are unchanged (whole qty); backfilled Σ line totals equal the stored subtotal (backfill copied unit price/qty faithfully). If a future change makes totals derive from lines, that's a separate, deliberate step (4C-4).
- **Fallback:** legacy `items` / new `lines` / both → lines / empty → throws (as before). Decimal quantity now prints (e.g. `2.5`).
- **Files:** `invoice_generator.dart`; `pdf_generation_test.dart` (+1 default-suite test: generate from in-memory `InvoiceLine` decimal rows, lines-preferred); docs.
- **Tests:** new default PDF test for the lines path; existing item-based PDF tests pass via fallback; 4C-1 pure tests cover mapping. `flutter analyze` → No issues found; `flutter test` → 133 passed, 8 skipped (+1).
- **Not done (as scoped):** totals/composer/notifier, form, writes untouched; no schema/generated changes; no orphan cleanup; `Invoice.items`/`Item`/`Item.invoiceId` retained.
- **Next:** Stage 4C-4 — switch totals/composer to derive from `InvoiceLineReader` (source-of-truth change) or add the form decimal-quantity input.

---

## Stage 4C-4A — Completed (2026-06-09) — totals/composer parity audit + tests

Audit + tests only — **no write/totals/form/PDF-totals/schema changes.** (Full detail in `doc/plans/step-4-quantity-relation-migration-plan.md` → "Step 4C-4A".)

- **Calculation flow traced:** subtotal/discount/tax/total via `InvoiceComposer` (quantity = `item.stockQuantity ?? 1`); cents written on save by `invoice_form_page._onSubmit`, legacy doubles dual-written by `repository._withDualWrittenMoney`; PDF/detail/dashboard read the stored `effective*Cents` snapshot; PDF per-tax rows recompute from **live** `invoice.taxes`.
- **Parity result:** Σ `InvoiceLineView.lineTotalCents` **exactly equals** the composer subtotal for legacy whole-quantity invoices (proven algebraically + by `invoice_line_parity_test.dart`). The single divergence is invalid `qty ≤ 0` (composer→0, adapter→1 unit) — already blocked by `InvoiceValidation`; add a defensive guard before the totals switch.
- **Taxes:** invoice-level (`invoice.taxes`), not per-line; per-line `taxRateBasisPoints` captured but unused. The PDF-rows-vs-stored mismatch on post-invoice tax edits (P2-003) is pre-existing and unrelated to lines.
- **Recommendation (writes-first):** 4C-4B dual-write `lines` on save (totals unchanged) → 4C-4C totals derive from `InvoiceLineReader` (guard qty ≤ 0) → 4C-4D form decimal input → 4D orphan cleanup → 4E retire legacy. Do **not** change stored totals until writes reliably create `lines`.
- **Files:** `test/features/invoice/invoice_line_parity_test.dart` (new, 13 pure tests); docs.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 143 passed, 8 skipped (+10).
- **Next:** Stage 4C-4B — dual-write `Invoice.lines` on save (first write-path change; run the pending objectbox-tagged suites on a native-lib machine first).

---

## Stage 4C-4B — Completed (2026-06-09) — dual-write Invoice.lines on save

First write-path change. On create/update the app **continues writing legacy `Invoice.items` exactly as before** and now **also writes/replaces `Invoice.lines`** from the same submitted items. **Totals, the stored snapshot, form UI, and PDF totals are unchanged.**

- **Builder:** `InvoiceLineBuilder.fromItems` (pure) — mirrors the 4B backfill mapping (`quantityMilli` via `InvoiceLineMath`, effective `unitPriceCents`, tax→basis points, order, `sourceItemId` when persisted).
- **Local source:** `replaceInvoiceLines(invoiceId, lines)` — deletes existing owned `InvoiceLine` rows (no orphans) then writes the fresh set with `invoice.target`. Idempotent.
- **Repository:** `replaceInvoiceLines` passthrough.
- **Notifier `onUpsert`:** after the legacy items loop, dual-writes lines via `replaceInvoiceLines(InvoiceLineBuilder.fromItems(state.items))` (built post-loop so `sourceItemId` reflects assigned ids).
- **Effect:** new/edited invoices carry `Invoice.lines`; detail + PDF (already on the reader since 4C-2/4C-3) consume them — identical output for whole-quantity invoices. Legacy `items` retained; no `Item` rows deleted.
- **Transaction note:** lines persist as one more sequential step alongside items/taxes/terms (existing non-transactional save pattern); `replaceInvoiceLines` batches via `removeMany`/`putMany`. Single-transaction save is future hardening.
- **Files:** `invoice_line_builder.dart` (new); `invoice_local_source.dart`, `invoice_repository.dart`, `invoice_notifier.dart`; tests `invoice_line_builder_test.dart` (pure) + `invoice_line_dualwrite_objectbox_test.dart` (tagged); docs.
- **Tests:** pure builder mapping/order/quantity/parity; tagged create-writes-both / edit-replaces (no dup/orphan) / empty-clears-lines-keeps-items / idempotent / stored-subtotal-unchanged.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 147 passed, 9 skipped (+4 pure; +1 tagged).
- ⚠️ **ObjectBox-tagged tests still unrun here** (`libobjectbox.dylib`). Run `flutter test --tags objectbox --run-skipped` on a native-lib machine to validate the write/replace behaviour against a real store before relying on lines.
- **Not done (as scoped):** totals/composer source of truth, form UI/decimal input, PDF totals untouched; no schema/generated changes; no orphan cleanup; `Invoice.items`/`Item`/`Item.invoiceId` retained.
- **Next:** Stage 4C-4C — switch totals/composer to derive from `InvoiceLineReader` (guard qty ≤ 0), keeping the stored snapshot.

---

## Stage 4C-4C — Completed (2026-06-09) — subtotal from InvoiceLineReader

Subtotal calculation switched to the unified line adapter; the rest of the money flow is unchanged.

- **Subtotal** now = `InvoiceLineReader.subtotalCents(lines, items)` (Σ `InvoiceLineView.lineTotalCents`, lines-preferred / items-fallback) — the same source as the detail/PDF item rows and the dual-written lines. **Discount/tax/total/balance still flow through `InvoiceComposer`.**
- `InvoiceComposer.compose` gained `subtotalCentsOverride` (+ `lines` now optional); override wins, else computes from `lines` (back-compat). `invoice_notifier.calculateSubtotalCents` + form `_onSubmit` feed the line-derived subtotal.
- **qty ≤ 0 guard:** adapter maps invalid/≤0 legacy qty to one unit (validation still blocks qty ≤ 0 at save); documented + tested.
- **Parity:** for valid whole-quantity invoices, override-subtotal == legacy composer subtotal → all downstream totals byte-identical. Stored `effective*Cents` snapshot remains the persisted source for PDF/detail/dashboard; tax/discount/payment unchanged.
- **Files:** `invoice_line_view.dart` (`subtotalCents`), `invoice_composer.dart` (`subtotalCentsOverride`), `invoice_notifier.dart`, `invoice_form_page.dart` (`_onSubmit` + import); new `invoice_subtotal_source_test.dart`; docs.
- **Tests:** subtotal source (lines/items/empty/invalid-qty) + compose override-vs-lines parity (with discount+tax+paid) + decimal subtotal flow. Existing `invoice_composer_test` passes via the `lines` path. `flutter analyze` → No issues found; `flutter test` → 153 passed, 9 skipped (+6).
- ⚠️ ObjectBox-tagged tests still unrun here (`libobjectbox.dylib`) — run `flutter test --tags objectbox --run-skipped` on a native-lib machine.
- **Not done (as scoped):** form UI/decimal input, PDF totals rendering, payment, schema/generated, orphan cleanup — all untouched; `Invoice.items`/`Item`/`Item.invoiceId` retained.
- **Next:** Stage 4C-4D — form decimal-quantity input (writes fractional lines; subtotal already line-based).

---

## Checkpoint — Invoice line migration (pre-4C-4D) (2026-06-09)

State of the 4B→4C line migration before the first user-visible change (decimal quantity UI):

| Stage | Status |
|-------|--------|
| 4B — `InvoiceLine` schema + idempotent backfill | done (`dac779d`) |
| 4C-1 — `InvoiceLineReader`/`InvoiceLineView` read adapter | done (`3c851f8`) |
| 4C-2 — invoice **detail** item rows read lines (fallback) | done (`e789f23`) |
| 4C-3 — **PDF** item table reads lines (fallback) | done (`3c9b813`) |
| 4C-4A — totals/composer parity audit + tests | done (`7509163`) |
| 4C-4B — **dual-write** `Invoice.lines` on save | done (`de60366`) |
| 4C-4C — **subtotal** derived from lines | done (`3e5e559`) |
| 4C-4D — decimal-quantity form input | **NOT started** |
| 4D — orphan cleanup / 4E — retire legacy `items` | not started |

- **Reads on lines:** detail, PDF item table, subtotal. **Writes:** legacy `items` + `Invoice.lines` (dual-write). **Stored snapshot:** unchanged source for PDF/detail/dashboard totals. **Form UI:** still integer quantity. **Legacy `Invoice.items` / `Item` / `Item.invoiceId`:** retained; no orphan cleanup.
- **Branch health:** `flutter analyze` → No issues found; `flutter test` → **153 passed, 9 skipped** (the 9 skips are the objectbox-tagged suites). Working tree clean.
- **ObjectBox-tagged tests: PENDING.** `libobjectbox.dylib` is not present on this machine's loader paths; not installed (per instruction). The 9 tagged suites — backfill, dual-write/replace, line reader, uniqueness (3B/3C), settings reactivity — **have not been run against a real store.**
- **Manual QA needed** (before/with 4C-4D): on a device, create + edit invoices and confirm detail, PDF, and subtotal match the legacy values for existing (pre-migration) and new invoices; verify edit replaces lines (no dup/orphan).
- **Risk of proceeding to 4C-4D without the tagged run:** 4C-4D makes totals + persisted lines user-visible for fractional quantities. The pure tests prove the math/adapter, but the **store-level** write/replace, backfill, and reader behaviour are still unverified on a real ObjectBox store. **Recommended:** run `flutter test --tags objectbox --run-skipped` on a native-lib machine before 4C-4D.

---

## Stage 4C-4D-1 — Completed (2026-06-09) — decimal quantity parser/formatter

Pure helper only — **no UI/state/write/totals/PDF/schema changes.**

- **Added:** `InvoiceQuantityInput` + `QuantityParseResult` (`lib/features/invoice/invoice_quantity_input.dart`), non-throwing.
- **Parse rules:** dot decimal only (**comma rejected**), ≤ 3 decimals (more **rejected**, not rounded), min `0.001` (no max), trim whitespace, leading/trailing zeros OK, leading-dot `.5` allowed; **rejected:** empty, `0`, `0.000`, negative, non-numeric, `.`, `..`, `1.`. Returns `success(quantityMilli)` / `failure(message)` with specific messages.
- **Format:** delegates to `InvoiceLineMath.formatQuantity` (`1000→"1"`, `1500→"1.5"`, `1→"0.001"`) — no duplicated logic.
- **Files:** new `invoice_quantity_input.dart`; new `invoice_quantity_input_test.dart` (valid/invalid/messages/format/round-trip); docs.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 183 passed, 9 skipped (+30).
- **Next:** Stage 4C-4D-2 — wire the parser/formatter into the form's item quantity field + form state (decimal end to end), keeping the existing dual-write.

---

## Stage 4C-4D-2A — Completed (2026-06-09) — form state carries quantityMilli

In-memory state plumbing only — **no UI/write/subtotal/PDF/schema changes; no visible behaviour change.**

- **Added:** `InvoiceFormLine` (`invoice_form_line.dart`) — pairs a form `Item` with `quantityMilli`; `legacyQuantity` getter (`~/1000`, truncation documented); `fromItem`/`fromLine`; static `resolve(items, lines)` (prefers `Invoice.lines` by `sortOrder` when count matches, else legacy items).
- **State:** `InvoiceFormState` gained additive `List<InvoiceFormLine>? lines` (default `[]`), synced by the notifier (`resetItems`/`addItem`/`updateItem`/`removeItem`) and populated on load (`getInvoiceById` via `InvoiceFormLine.resolve`).
- **Not consumed yet:** UI reads `items`, `_onSubmit` writes from `items`, subtotal resolves from `items`. `lines` is the precise-quantity carrier only.
- **Compat rule:** integer path uses `legacyQuantity = quantityMilli ~/ 1000`; new/edited items derive `quantityMilli` from `stockQuantity × 1000`; loaded-from-lines quantities preserved without loss (none fractional pre-UI).
- **Files:** new `invoice_form_line.dart`; `invoice_state.dart`, `invoice_notifier.dart`; new `invoice_form_line_test.dart` (10 pure tests); docs.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 193 passed, 9 skipped (+10).
- **Not done (as scoped):** form UI/decimal input, write path, subtotal source, PDF, schema/generated, orphan cleanup — all untouched.
- **Next:** Stage 4C-4D-2B — wire the decimal field + parser/formatter into the form UI and persist `quantityMilli` on the line.

---

## Stage 4C-4D-2C — Completed (2026-06-09) — totals/write consume state.lines

Order swapped (per decision): persistence/totals first, decimal UI next. **No UI change; no visible behaviour change** (UI still integer → all quantities whole → identical to before).

- **Subtotal:** `notifier.calculateSubtotalCents` = `InvoiceFormLine.subtotalCents(state.lines)`; form `_onSubmit` feeds it via `subtotalCentsOverride`. Discount/tax/total/balance unchanged (composer).
- **Persistence:** `onUpsert` builds `Invoice.lines` via `InvoiceLineBuilder.fromFormLines(state.lines)` — preserves `quantityMilli` exactly; legacy `Item.stockQuantity` no longer drives lines/totals. `fromItems` retained (delegates to `fromFormLines`).
- **Authoritative = `InvoiceFormLine.quantityMilli`.** Legacy compat rule: `legacyQuantity = quantityMilli ~/ 1000` (truncation, documented); whole quantities → line-based == item-based (parity), so save/totals are byte-identical today.
- **Files:** `invoice_form_line.dart` (`subtotalCents`), `invoice_line_builder.dart` (`fromFormLines`; `fromItems` delegates), `invoice_notifier.dart` (subtotal + persistence + import cleanup), `invoice_form_page.dart` (`_onSubmit` override + removed `invoice_line_view` import); tests `invoice_form_line_test.dart` (+subtotalCents), `invoice_line_builder_test.dart` (+fromFormLines), `invoice_line_dualwrite_objectbox_test.dart` (+decimal persistence); docs.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 200 passed, 9 skipped (+7).
- ⚠️ ObjectBox-tagged tests still unrun here (`libobjectbox.dylib`) — run `flutter test --tags objectbox --run-skipped` on a native-lib machine; the decimal-persistence + write/replace behaviour is store-level.
- **Decimal UI is now safe to implement** — totals + persistence already read `quantityMilli`.
- **Not done (as scoped):** form UI/decimal input, PDF totals, payment, schema/generated, orphan cleanup — untouched; `Invoice.items`/`Item`/`Item.invoiceId` retained.
- **Next:** Stage 4C-4D-2B — decimal quantity field in the form UI.

---

## Stage 4C-4D-2B — Completed (2026-06-09) — decimal quantity UI (end-to-end)

The invoice item quantity is now decimal end-to-end (input → state → totals → persistence → reopen → detail/PDF). First user-visible change of the line migration.

- **Input:** item dialog quantity field is decimal (`numberWithOptions(decimal: true)`), validated by `InvoiceQuantityInput.parse` (accepts `1`, `1.5`, `0.25`, `.5`, `2.250`; rejects empty/`0`/negative/`abc`/`1.2345`/`1,5`/`1.` with specific messages); prefilled via `InvoiceQuantityInput.format`.
- **State/persistence:** `addItem`/`updateItem` now take `quantityMilli` → stored on `InvoiceFormLine`; saved exactly via `fromFormLines` (2C). `Item.stockQuantity = legacyQuantityFor(quantityMilli)` = `max(1, floor(qty))` — compat only (keeps legacy `InvoiceValidation` passing for sub-unit quantities), never drives totals/lines.
- **Display:** form item list + pricing summary iterate `state.lines` (decimal quantity + `lineTotalCents`); live subtotal/discount/tax/total reflect decimals (2C). Detail + PDF already read lines (4C-2/4C-3). Edit prefills the decimal from `Invoice.lines` (2A load).
- **Files:** `invoice_form_line.dart` (`legacyQuantityFor` clamp, `lineTotalCents`), `invoice_notifier.dart` (`addItem`/`updateItem` signatures), `invoice_form_page.dart` (dialog field/validator/keyboard/submit + list/summary read `state.lines`); `invoice_form_line_test.dart` (+clamp/lineTotal/pipeline); docs.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 206 passed, 9 skipped (+6).
- ⚠️ ObjectBox-tagged tests still unrun here (`libobjectbox.dylib`) — run `flutter test --tags objectbox --run-skipped` on a native-lib machine, plus manual QA (enter 1.5 / 0.25, save, reopen, check detail + PDF).
- **Not done (as scoped):** schema/generated, orphan cleanup, legacy-path retirement, payment, settings refresh — untouched; `Invoice.items`/`Item`/`Item.invoiceId` retained. Add-item sheet still legacy `DraggableScrollableSheet` (P2-007, cosmetic).
- **Remaining work:** native-lib tagged run + manual QA → **4D** orphan cleanup → **4E** retire legacy `items`.

---

## QA Checkpoint — Decimal quantity (2026-06-09)

- **Latest commit:** `15ce962` — decimal item quantity is now end-to-end (input → state → totals → persistence → reopen/edit → detail/PDF).
- **Branch health:** `flutter analyze` → No issues found; `flutter test` → 206 passed, 9 skipped (the 9 skips are the objectbox-tagged suites).
- **Manual QA: required** (UI/device — the input + round-trip can't be fully covered by the host suite).
- **ObjectBox-tagged tests: PENDING** on a machine with native `libobjectbox.dylib` (decimal persistence, backfill, dual-write/replace, reader).
- **4D (orphan `Item` cleanup): NOT started. 4E (retire legacy `Invoice.items`/`Item.invoiceId`): NOT started.**
- Unrelated `home_page.dart`/`simple_list.dart` WIP remains uncommitted (untouched).

### Manual QA checklist — Decimal quantity
- [ ] Create invoice with qty 1.5 and price RM10 → line total RM15
- [ ] Create invoice with qty 0.25 and price RM100 → line total RM25
- [ ] Save invoice → reopen edit → decimal quantity persists
- [ ] Detail page shows decimal quantity
- [ ] PDF preview/share shows decimal quantity and correct totals
- [ ] Edit invoice qty 1.5 → 2.25 → save → reopen → correct
- [ ] Invalid qty 0 rejected
- [ ] Invalid qty -1 rejected
- [ ] Invalid qty 1.2345 rejected
- [ ] Invalid qty 1,5 rejected
- [ ] Whole quantity 1/2 still works as before

### ObjectBox runtime verification (native-lib machine)
- [ ] Run `flutter test --tags objectbox --run-skipped`
- [ ] Confirm decimal persistence tests pass
- [ ] Confirm backfill / dual-write / reader tests pass

---

## Stage 4D — Completed (2026-06-09) — orphan legacy Item cleanup (P2-001)

Delete-capable cleanup for orphaned legacy `Item` rows. **Not run automatically** (no silent deletion); `main.dart` unchanged.

- **Ownership verified safe:** `Item` is invoice-owned only — no catalog feature (no route/list/repository/standalone creation), `Item.invoiceId` never set, only read-only backfill touches the box. So unreferenced Items are true orphans.
- **Service:** `OrphanItemCleanup` (`lib/features/invoice/data/invoice_item_orphan_cleanup.dart`), `run({required bool dryRun})` → `OrphanItemCleanupReport(scannedItems, referencedItems, orphanItems, deletedItems, skippedItems, warnings)`.
- **Safety rule:** preserve an Item if referenced by any `Invoice.items` **or** any `InvoiceLine.sourceItemId` (provenance guard); delete the rest via `removeMany` in a write transaction. Idempotent.
- **Startup:** disabled — explicit/tested call only.
- **Files:** new `invoice_item_orphan_cleanup.dart`; tests `invoice_item_orphan_cleanup_test.dart` (pure report), `invoice_item_orphan_cleanup_objectbox_test.dart` (tagged: no-orphan/dry-run/delete/referenced-preserved/multi-invoice/idempotent/sourceItemId-guard).
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 207 passed, 10 skipped (+1 pure, +1 tagged suite).
- ⚠️ ObjectBox-tagged tests unrun here (`libobjectbox.dylib`) — run `flutter test --tags objectbox --run-skipped` on a native-lib machine; do a **dry-run on real data** before any production delete.
- **Not done (as scoped):** no schema/generated changes; legacy `Invoice.items`/`Item`/`Item.invoiceId` retained (4E); no UI/totals/PDF/payment changes; no automatic cleanup wiring.
- **Next:** Stage 4E — retire the legacy `Invoice.items` relation + `Item`/`Item.invoiceId` (after a production dry-run/cleanup and the native-lib tagged run).

---

## Stage 4D-2 — Completed (2026-06-10) — guarded manual cleanup entry point

A safe, explicit, **debug-only** UI to run the Stage 4D `OrphanItemCleanup`. **Never automatic.**

- **Where:** Settings → **Maintenance** section, gated behind `kDebugMode` (not customer-facing); opens `LegacyItemCleanupPage` via `MaterialPageRoute`.
- **Dry Run:** `OrphanItemCleanup.run(dryRun: true)` → shows the report (total/referenced/orphans/deleted/skipped/warnings) + a headline; mutates nothing.
- **Delete Orphans:** enabled **only after a dry-run that found orphans**, and behind a confirmation dialog ("This will permanently delete orphan legacy invoice item rows. It will not delete invoices or invoice lines."); then `run(dryRun: false)` and shows the final report. Failures are caught → error snackbar, no crash.
- **Files:** new `legacy_item_cleanup_page.dart` (+ pure `cleanupHeadline`/`cleanupReportRows`); `settings_page.dart` (Maintenance section + imports); new `test/features/setting/legacy_item_cleanup_format_test.dart`.
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 212 passed, 10 skipped (+5).
- **Not done (as scoped):** no automatic/startup cleanup; no schema/generated changes; `Invoice.items`/`Item`/`Item.invoiceId` retained; no PDF/totals/payment/decimal-UI changes; Stage 4E not started.
- **Next:** Stage 4E — retire legacy `Invoice.items` + `Item`/`Item.invoiceId` (after a native-lib tagged run, decimal manual QA, and a production dry-run/cleanup via this screen).

---

# Stage 4D-3 Verification Gate

## Branch State

* Branch: dev
* Working tree: clean before this audit-report update
* Stage 4E: not started

## Default Verification

* flutter analyze: passed — No issues found
* flutter test: passed — 212 passed, 10 skipped

## ObjectBox Tagged Tests

* Command: `flutter test --tags objectbox --run-skipped`
* Result:
  * failed due to missing `libobjectbox.dylib`
* Note:
  * Error summary: host Dart VM tests could not load `libobjectbox.dylib`; `dlopen` searched Flutter engine, `/usr/local/lib`, `/usr/lib`, and local library paths and reported "no such file".
  * This is an environment/native dependency issue.
  * It does not prove ObjectBox store migration/backfill/cleanup logic at runtime.
  * Tagged tests still need to run on a machine with ObjectBox native library installed.

## Manual QA Gate Before Stage 4E

Decimal quantity:

* [ ] Create invoice qty 1.5, price RM10 -> line total RM15
* [ ] Create invoice qty 0.25, price RM100 -> line total RM25
* [ ] Save invoice -> reopen edit -> decimal quantity persists
* [ ] Detail page shows decimal quantity
* [ ] PDF preview/share shows decimal quantity and correct totals
* [ ] Edit qty 1.5 -> 2.25 -> save -> reopen -> correct
* [ ] Whole qty 1/2 still works
* [ ] Invalid qty 0 rejected
* [ ] Invalid qty -1 rejected
* [ ] Invalid qty 1.2345 rejected
* [ ] Invalid qty 1,5 rejected

Legacy Item cleanup:

* [ ] Debug build only: Settings -> Maintenance visible
* [ ] Release build: Maintenance action hidden
* [ ] Dry Run runs without deleting
* [ ] Dry Run report is understandable
* [ ] Delete Orphans disabled when no orphans
* [ ] Delete Orphans requires confirmation
* [ ] Delete Orphans does not delete invoices
* [ ] Delete Orphans does not delete Invoice.lines
* [ ] Run dry-run on production-like data before real delete

ObjectBox runtime:

* [ ] Backfill tests pass
* [ ] Dual-write tests pass
* [ ] InvoiceLine reader tests pass
* [ ] Decimal persistence tests pass
* [ ] Uniqueness tests pass
* [ ] Settings reactivity tests pass
* [ ] Orphan cleanup tests pass

## Stage 4E Gate

Do not start Stage 4E until:

1. default analyze/test are green,
2. ObjectBox tagged tests pass on a machine with `libobjectbox.dylib`,
3. decimal quantity manual QA passes,
4. legacy item cleanup dry-run is reviewed,
5. real orphan delete, if run, is confirmed safe.

---

## Severity Legend

- **P0 Critical**: data loss, app crash, broken core invoice flow, security/privacy issue
- **P1 High**: major bug, wrong invoice amount, broken PDF/share, migration risk
- **P2 Medium**: UX issue, edge case, inconsistent state, maintainability issue
- **P3 Low**: cleanup, naming, minor refactor, small UI consistency

## Findings Table

| ID | Severity | Area | File(s) | Problem | Impact | Recommended Fix | Test Needed |
|----|----------|------|---------|---------|--------|-----------------|-------------|
| P1-001 | P1 | Invoice/runtime | `invoice_form_page.dart:148,163,168,171`; `item_model.dart:337,433,445` | Enums parsed with `.values.byName()` (throws on unknown) instead of safe `fromName` | Opening edit/view (or rendering unit/type) of a legacy/corrupt invoice **crashes** | Route all stored-enum parsing through safe `fromName`/guarded lookups | Widget/unit test opening an invoice with an unknown `status`/`invoiceType`/`unit` |
| P1-002 | P1 | Invoice flow | `invoice_detail_page.dart:269-278`; `invoice_local_source.dart:307-349` (dead) | "Mark as Sent"/"Record Payment" disabled; status→paid doesn't set paid/balance/paymentStatus | Core lifecycle (sent/paid/partial) is **incomplete**; "Paid" invoices still show balance due | Wire `markAsSent`/`markAsPaid(amount)` to UI; make status changes update payment fields atomically | Repo+notifier tests for sent/paid/partial transitions |
| P1-003 | P1 | Money/data model | `item_model.dart`; `invoice_form_page.dart:560,713-723`; `invoice_composer.dart`; PDF/detail | Line quantity stored in `Item.stockQuantity`; integer-only; no dedicated `quantity` field | Semantic overload; **no fractional quantities** (hours, kg); fragile | Add explicit `quantity`/`quantityX1000` field; migrate `stockQuantity`→quantity for invoice items | Composer/persistence test for fractional + round-trip |
| P1-004 | P1 (needs verification) | ObjectBox | `signature_model.dart:27-31` | `@Unique` on nullable `email` and `phone` | If ObjectBox rejects duplicate nulls, **a 2nd signature without email/phone fails to save** | Verify ObjectBox null-unique behavior; if needed, drop `@Unique` or make conditional | Insert two signatures with null email/phone |
| P0/P1-SEC | P1 (P0 by data sensitivity) | Security/privacy | `objectbox_database.dart:9-25` | Store persists PII unencrypted at rest | Plaintext PII readable on rooted/backed-up device | Encrypted edition + keystore key (already planned); blocked by open-source lib | Manual: inspect store file on device |
| P2-001 | P2 | ObjectBox/data | `invoice_notifier.dart:292-297`; `invoice_local_source.dart:452-457` | `clearItemsFromInvoice` clears the relation but never deletes `Item` entities | **Orphaned `Item` rows accumulate** on every invoice edit → DB bloat | Delete removed items, or use a backlinked relation with cascade semantics | Repo test: edit invoice removing an item, assert Item box count |
| P2-002 | P2 | ObjectBox/schema | `invoice_model.dart:196`; `item_model.dart:77` | Two relations between Invoice & Item: `ToMany items` (used) + `ToOne invoice` (never set, no `@Backlink`) | Redundant schema; root cause of orphans; confusing | Make `items` a `@Backlink()` of `Item.invoice`, set the ToOne on save | Schema/round-trip test |
| P2-003 | P2 | PDF/calculation | `invoice_generator.dart:517-528` | PDF tax rows recompute from **live** `tax.rate`; total uses stored snapshot | If a tax is edited/deleted after invoicing, PDF tax lines ≠ PDF total | Render tax breakdown from stored amounts, or snapshot tax name+rate per invoice | PDF test: edit tax rate after invoice, assert lines sum to total |
| P2-004 | P2 | Startup/perf | `main.dart:12`; `invoice_money_backfill.dart:43-72` | Backfill `getAll()` over all invoices+items on every cold start, synchronously before `runApp` | Slows startup on large datasets even when nothing to do | Gate behind a "done" flag / version marker; or run async | Test: backfill no-ops on second run (flag set) |
| P2-005 | P2 | Money/UI | `item_model.dart:397,403`; `invoice_model.dart:505-537` | `currency ?? '$'`/currency-code used as the display **symbol** | Item price shows e.g. `MYR1000.00` not `RM1000.00`; inconsistent with `CurrencyUtils.getSymbol` | Use `CurrencyUtils.getSymbol(code)` everywhere | Golden/string test on formatting |
| P2-006 | P2 | State mgmt | `invoice_preview_page.dart:48-49,62-116` | Preview reuses the shared non-autoDispose `invoiceFormProvider` | Loading preview mutates form state; coupling + retained memory | Give preview its own (autoDispose family) provider / use `invoiceDetailProvider` | Provider test: preview load doesn't clobber form |
| P2-007 | P2 | UI/UX | `invoice_form_page.dart:568-749` | Add-item sheet uses fixed `DraggableScrollableSheet(0.48)` + prints `"null"` qty when `stockQuantity==null` | Overflow on small screens; stray "null" in field | Migrate to `AppDynamicBottomSheet.showCustom`; guard null qty | Widget test small screen + null-qty edit |
| P2-008 | P2 | Export/file | `invoice_generator.dart:761,783,802-803` | PDF filename = raw prefix+number (may contain `/`, `:`) | `saveInvoice` write/share can fail for numbers like `INV/2024/001` | Sanitize filename (replace illegal chars) | Unit test sanitizer |
| P2-009 | P2 | State mgmt | `invoice_form_page.dart:377,808` | `ref.watch(...)` called inside non-build callbacks | Anti-pattern; can throw / unexpected rebuild semantics | Use `ref.read(...)` in callbacks | Lint/review |
| P3-001 | P3 | Dead code | `invoice_local_source.dart:307-376`; `invoice_model.dart:472-477,524-537`; all `*_local_source.dart` singleton factories | `markAsSent/markAsPaid/markAsViewed/updatePaymentStatus/updateInvoiceAmounts`, `sortedItems`, `Invoice.formatted*`, singleton `factory X()` + `ObjectBoxDatabase.instance` path — all unused | Maintenance noise; confusion | Remove after confirming no use (grep done — unused) | n/a |
| P3-002 | P3 | Numbering | `invoice_numbering.dart:4,8-21` | Only `INV-####` recognized; custom prefixes reset sequence; no concurrency guard | Wrong "next number" for custom schemes; rare collision | Make pattern prefix-aware; document single-user assumption | Numbering test w/ custom prefix |
| P3-003 | P3 | UX | `invoice_form_page.dart:1518` | Long-press deletes a line item with no confirmation | Accidental deletion | Add confirm / undo snackbar | Widget test |
| P3-004 | P3 | UX | `invoice_form_page.dart:331-353` | Discount rate/amount `onChanged` don't trigger summary rebuild | Summary lags until another rebuild | Call `setState`/`_refreshPricingCalculations` | Widget test |
| P3-005 | P3 | Navigation | `generate_route.dart:246,254` | `invoiceId!` force-unwrap | Crash if route arg missing | Guard + route to `no_route_page` | Route test with null arg |
| P3-006 | P3 | State | `invoice_state.dart:54` | `copyWith` always overwrites `error` with the (defaulted-null) param | Error silently cleared by unrelated `copyWith` calls | Use a sentinel / `clearError` flag | Notifier test |

## Detailed Findings

### P1-001: Stored enums parsed with `.values.byName()` (crash on legacy/unknown values)
- **Severity:** P1
- **Area:** Invoice / runtime safety, legacy data
- **Files:** `lib/features/invoice/presentation/pages/invoice_form_page.dart:148,163,168,171`; `lib/features/item/item_model.dart:337,433,445`
- **Current behavior:** The model defines safe parsers (`InvoiceStatusExtension.fromName`, etc.) that fall back to a default on unknown/null. But the **form** bypasses them: `InvoiceType.values.byName(...)`, `InvoiceStatus.values.byName(...)`, `PaymentStatus.values.byName(...)`, `RecurringFrequency.values.byName(...)`. `item_model` does the same in `displayUnit`, `itemTypeDisplay`, `unitDisplay`.
- **Risk:** `Enum.values.byName('')`/unknown **throws `ArgumentError`**. Any invoice/item whose stored enum string doesn't match the current enum (older build, renamed value, corruption) crashes the edit/view screen or item rendering.
- **Recommended fix:** Replace every `.values.byName(stored)` on a *persisted* value with the safe `fromName` pattern (or a guarded `tryByName`).
- **Suggested implementation:** Add `RecurringFrequencyExtension.fromName` (missing) mirroring the others; swap the four form call-sites and three item getters.
- **Suggested test:** Build an `Invoice`/`Item` with `status:'archived'`, `unit:'furlong'`, pump the form / call the getter, assert no throw and a sane fallback.
- **Priority reason:** Direct crash on real legacy data in the core edit path.

### P1-002: Sent/Paid/Partial lifecycle incomplete; "Paid" doesn't reconcile balances
- **Severity:** P1
- **Area:** Invoice flow / state correctness
- **Files:** `invoice_detail_page.dart:269-278` (disabled buttons); `invoice_local_source.dart:307-349` (`markAsSent`, `markAsPaid` present but **never called**); `home_page.dart:124-284` (status dialog sets `status` only)
- **Current behavior:** "Mark as Sent" and "Record Payment" are `onPressed: null`. The only status path (home "Change Status") calls `updateStatus(id, status)`, which writes `status` but not `paidAmount`/`balanceDue`/`paymentStatus`/`paidDate`.
- **Risk:** An invoice set to `status = paid` still has `balanceDue == total` and `paymentStatus == unpaid`. The dashboard's paid/outstanding counts (which key off `isFullyPaid`/balance) are wrong; PDF shows a balance due on a "paid" invoice.
- **Recommended fix:** Wire `markAsSent` and a "record payment (amount)" action that updates the payment fields atomically; when status is set to `paid` from any path, reconcile `paidAmount=total`, `balanceDue=0`, `paymentStatus=paid`, `paidDate`.
- **Suggested test:** Notifier/repo tests: mark sent sets `sentDate`+status; record full/partial payment updates `paidAmountCents`/`balanceDueCents`/`paymentStatus`.
- **Priority reason:** Core invoicing lifecycle is a primary feature and currently produces contradictory state.

### P1-003: Line quantity overloaded onto `Item.stockQuantity` (int-only, fragile)
- **Severity:** P1
- **Area:** Money / data model
- **Files:** `item_model.dart` (no `quantity` field); `invoice_form_page.dart:560,713-723`; `invoice_composer.dart:6`; `invoice_detail_page.dart:428`; `invoice_generator.dart:421`
- **Current behavior:** The invoice line quantity is written to and read from `Item.stockQuantity` (an inventory concept), as an `int`.
- **Risk:** (1) No fractional quantities (2.5 hours, 1.25 kg) — a real invoicing limitation. (2) Semantic overload couples line quantity to inventory. (3) Reusing the same `Item` shape for catalog items and invoice lines is confusing and error-prone.
- **Recommended fix:** Introduce an explicit quantity field for invoice lines (e.g., `quantityMilli`/`int quantityX1000` for 3-dp fractional, or a dedicated `InvoiceLine` entity). Migrate existing `stockQuantity` line values. **This is a schema change — stage it separately from UI cleanup.**
- **Suggested test:** Composer test with fractional qty; backfill/migration test mapping `stockQuantity`→quantity.
- **Priority reason:** Affects calculation correctness/expressiveness and is the root of P2-001/002.

### P1-004 (Needs verification): `@Unique` on nullable signature `email`/`phone`
- **Severity:** P1 (suspected)
- **Files:** `signature_model.dart:27-31`
- **Current behavior:** `@Unique() String? email;` and `@Unique() String? phone;`.
- **Risk:** If ObjectBox treats multiple nulls as a uniqueness conflict, creating a second signature without email/phone throws `UniqueViolationException` and the save fails. (Business/Client models should be checked for the same pattern.)
- **Recommended fix:** Verify behavior; if confirmed, drop `@Unique` from optional contact fields or enforce uniqueness only when non-empty at the app layer.
- **Suggested test:** Insert two `Signature(name:'a')` and `Signature(name:'b')` both with null email/phone into a test store; assert both succeed.

### P0/P1-SEC: Unencrypted data-at-rest (PII)
- **Severity:** P1 (P0 by data-sensitivity; blocked by ObjectBox edition)
- **Files:** `objectbox_database.dart:9-25` (already documented)
- **Current behavior:** Store opened without encryption; PII (businesses, clients, addresses, invoices, signatures) in plaintext under app documents.
- **Risk:** Readable on rooted/jailbroken devices and in unencrypted backups.
- **Recommended fix:** As documented — encrypted edition + per-install key in keystore/keychain, with a deliberate one-time migration. Not code-fixable today.
- **Priority reason:** Privacy exposure; tracked, but should remain visible.

### P2-001 / P2-002: Orphaned `Item` rows + duplicate Invoice↔Item relation
- **Files:** `invoice_model.dart:196`, `item_model.dart:77`, `invoice_notifier.dart:292-297`, `invoice_local_source.dart:452-457`, `objectbox-model.json` (Invoice relations `items/taxes/terms`; no `@Backlink`)
- **Current behavior:** On save, the notifier clears the `items` relation and re-adds each item. `clearItemsFromInvoice` only clears the relation links; the `Item` entities persist. `Item.invoice` (`ToOne`) is declared but never assigned (no `@Backlink` ties it to `Invoice.items`).
- **Risk:** Every edit that removes a line leaves an orphaned `Item` row forever → unbounded DB growth; the two parallel relations are a correctness trap.
- **Recommended fix:** Convert `Invoice.items` to `@Backlink()` of `Item.invoice` (set the ToOne on save), or explicitly delete removed items in `clearItemsFromInvoice`. Stage as a schema change.
- **Suggested test:** Create invoice with 3 items, edit to 2, assert `Item` box count drops by 1.

### P2-003: PDF tax breakdown uses live tax rates while total is a snapshot
- **Files:** `invoice_generator.dart:517-528`; relation `Invoice.taxes` references shared mutable `Tax` entities
- **Current behavior:** Per-tax rows are computed as `(taxable * tax.rate/100)` from the *current* `Tax`; `effectiveTotalCents` is the value composed at save time.
- **Risk:** Editing or deleting a tax after an invoice exists makes the PDF tax lines disagree with the printed total; historical invoices silently change.
- **Recommended fix:** Snapshot tax name+rate (and amount) onto the invoice at save, and render the breakdown from the snapshot. (Same consideration for terms content.)
- **Suggested test:** Generate PDF, mutate tax rate, regenerate, assert tax rows still sum to stored total.

*(P2-004…P3-006 are described in the table above; each has a concrete file, fix, and test.)*

## Confirmed vs Suspected

- **Confirmed (read in code):** P1-001, P1-002, P1-003, P2-001, P2-002, P2-003, P2-004, P2-005, P2-006, P2-008, P2-009, all P3 dead-code items, P3-002…P3-006.
- **Suspected / Needs verification:** P1-004 (ObjectBox null-unique semantics), P2-007 small-screen overflow (needs device/widget repro), exact ObjectBox behavior when a related `Tax`/`Term`/`Signature` target is deleted (dangling relation vs auto-prune).

## Quick Wins (safe, low-risk)

1. Swap form/item `.values.byName(stored)` → safe `fromName` (P1-001) — pure, additive.
2. Sanitize PDF filename (P2-008) — pure helper.
3. Use `CurrencyUtils.getSymbol` in `Item.formattedPrice*` (P2-005).
4. `ref.watch`→`ref.read` in the two callbacks (P2-009).
5. Guard `existingItem.stockQuantity` "null" string in the add-item sheet (P2-007 partial).
6. Delete confirmed dead code (P3-001) — after the grep already done.
7. Add `RecurringFrequencyExtension.fromName` (supports P1-001).

## High Risk Areas (handle carefully)

- **Any ObjectBox schema change** (P1-003 quantity field, P2-002 `@Backlink`): bumps `objectbox-model.json` + regenerates `objectbox.g.dart`; needs a migration/backfill and on-device verification. **Never bundle with UI cleanup.**
- **Payment/status reconciliation** (P1-002): touches money fields and dashboard aggregates; needs tests before/after.
- **Backfill changes** (P2-004): runs at startup over all data — get it provably idempotent.

## Suggested Fix Order

1. **P0/security** — keep the encryption item tracked (no code fix available now).
2. **P1 data/calculation/PDF** — P1-001 (enum crash, quick), P2-003 (PDF tax snapshot), P2-005 (currency symbol), P2-008 (filename).
3. **P1 migration/state** — P1-002 (payment lifecycle), P1-003 + P2-001/002 (quantity field + relation/backfill) as a *single isolated schema stage*; verify P1-004.
4. **P2 UX/state** — P2-006 (preview provider), P2-007 (add-item sheet), P2-004 (backfill gate), P2-009.
5. **P3 cleanup** — dead code removal, numbering, confirmations, route guards, copyWith error sentinel.

## Test Plan

**Unit (extend existing suite)**
- Enum safe-parse: unknown `status/invoiceType/paymentStatus/recurringFrequency/unit/itemType` → fallback, no throw.
- Payment lifecycle: markSent, full pay, partial pay → correct `paid/balance/paymentStatus/dates`.
- Composer with fractional quantity (after P1-003).
- PDF filename sanitizer.
- Numbering with custom prefix.

**Widget**
- Open edit/view on a legacy invoice (unknown enums) — no crash.
- Add-item sheet on a small screen (no overflow) + null-qty edit.
- Pricing summary updates live on discount change.

**Repository / ObjectBox**
- Edit invoice removing a line → no orphaned `Item` rows (after P2-002).
- Two signatures with null email/phone both insert (P1-004).
- Backfill no-ops on second run (after P2-004 gate).

**Integration / Manual QA**
- Create → edit → delete → preview → share → print across light/dark + small device.
- "Paid"/"Sent" reflected consistently in list, detail, dashboard, PDF.

**PDF Manual QA**
- 1 item, 100 items (pagination), long description/notes/terms (overflow), missing signature, deleted business/client/signature, edited tax rate (lines vs total).

**ObjectBox Migration QA**
- Backup an old store (double-only money, `stockQuantity` quantities, null cents) → launch → verify backfill + quantity migration + no data loss; verify rollback story.

---

*Next step: awaiting approval before implementing any fixes. If approved, I will start with P1 quick wins (no schema), keep schema changes (P1-003/P2-002) in a separate staged change with backfill + tests, and run `flutter analyze` + `flutter test` after each stage.*
