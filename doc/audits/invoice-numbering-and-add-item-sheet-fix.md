# Invoice Numbering Prefix-Awareness + Add-Item Sheet — Decision & Fix

> Date: 2026-06-11 · Branch: `dev` · Follow-up to
> `invois-full-audit-fix-summary.md` (the two items deferred as "product
> decisions").

## Part 1 — Prefix-aware invoice numbering

### Problem

`InvoiceNumbering.nextNumber` only recognised `^INV-(\d{4,})$`. Any custom
prefix (QUO-, EST-, INV2026-) restarted suggestions at `INV-0001`, `INV-1`
style numbers were ignored, and changing the prefix field in the form marked
the number as "manually edited", so the suggestion never re-scoped.

### Decision

**Generic trailing-digits parsing, no template engine.** A full number
(`invoiceNumberPrefix + invoiceNumber`) is split as *(leading text)(trailing
digits)*; the leading text is the scope, compared trimmed + case-insensitively.
This natively covers every format in use — `INV-0001`, `INV-001`, `INV-1`,
`INV2026-0001` (its own scope, not part of `INV-`), and plain legacy digits
(the empty scope) — and tolerates anything else by skipping it (`DRAFT`, `???`,
int-overflow digit runs). Sequence padding follows the widest existing number
in the scope (`INV-001` → `INV-002`; fresh scopes start at `0001`).

Contract through the layers (business-scoped, as before — candidates come from
`getInvoicesByBusinessId`):

- `InvoiceNumbering.tryParse / nextSequence / nextNumber` — pure, tested.
- `InvoiceLocalSource.nextInvoiceNumber(businessId, {prefix})` — with a
  non-empty prefix returns the **sequence part only** (the form composes
  `fullNumber = prefixField + numberField`); with an empty prefix it keeps the
  legacy default: a full `INV-XXXX` suggestion carried in the number field.
  Existing behaviour, tests, and stored data are untouched.
- Form: editing the **prefix field re-scopes the suggestion** (it is not a
  manual edit); editing the **number field** still marks it manual and stops
  all future suggestions. A stale-response guard drops suggestions whose
  prefix changed while the lookup was in flight.

### Explicitly preserved

- **Editing an existing invoice never regenerates its number**
  (`_suggestInvoiceNumberForBusiness` exits when `invoiceId > 0` — unchanged).
- **Manual numbers are respected** (`_isInvoiceNumberManuallyEdited` —
  unchanged for the number field).
- **Duplicate prevention unchanged** (`isAvailable` compares normalized full
  numbers per business; ObjectBox schema/uniqueness untouched — no
  `build_runner` needed).

## Part 2 — Add-item sheet

### Problem

The sheet was a fixed-fraction `DraggableScrollableSheet(initial: 0.48)` inside
a transparent modal. On small phones with the keyboard open, the sheet stayed
anchored at 48% of the screen while the keyboard covered most of it: the
action row (padded by `viewInsets`) survived, but the fields area collapsed to
a sliver. The sheet also lived inline in the 1,600-line form page, with its
controllers owned by the page state.

### Decision

**Reuse the shared `AppBottomSheet` shell** (the app-wide sheet component used
by every selector) instead of keeping a bespoke `DraggableScrollableSheet`. It
already implements the exact spec: content-sized when short (no forced
half-screen), capped and scrollable when tall (max set to **0.9** per spec),
the whole sheet lifted above the keyboard via `viewInsets`, footer actions
pinned and always reachable, `SafeArea`, drag handle, and dark mode through the
theme. One sheet pattern across the app, no nested-scroll tricks.

The sheet is now a self-contained widget, `InvoiceLineSheet`
(`presentation/widgets/invoice_line_sheet.dart`): it owns its controllers and
validators (identical rules: name required, price `Money`-parseable ≥ 0,
quantity via `InvoiceQuantityInput`), and returns an `InvoiceLineSheetResult`
(saved line / removed / dismissed) through `Navigator.pop`. The form page
consumes the result and keeps owning the notifier calls and temporary line
ids. Footer: Add mode → Cancel + Add; Edit mode → Remove (destructive) +
Update, with an ✕ close button in the header.

## Files changed

- `lib/features/invoice/data/invoice_numbering.dart` — rewritten prefix-aware
  (tryParse / nextSequence / nextNumber; `InvoiceNumberParts`).
- `lib/features/invoice/data/invoice_local_source.dart`,
  `data/invoice_repository.dart`, `providers/invoice_notifier.dart` — `prefix`
  parameter threaded through.
- `lib/features/invoice/presentation/pages/invoice_form_page.dart` — prefix
  field re-scopes suggestions; inline sheet (~200 lines) replaced by
  `InvoiceLineSheet.show` + result handling; item controllers removed.
- `lib/features/invoice/presentation/widgets/invoice_line_sheet.dart` — new.
- `test/features/invoice/invoice_numbering_test.dart` — +10 tests (scopes,
  case/trim, INV2026 isolation, width preservation, empty scope, malformed
  tolerance, tryParse).
- `test/features/invoice/invoice_repository_objectbox_test.dart` — +2 tagged
  tests (prefix scopes within a business; independence across businesses).
- `test/features/invoice/invoice_line_sheet_test.dart` — new, 7 widget tests
  (exact cents/milli round-trip, validation visible, **320×568 + 260px
  keyboard inset: surface lifted above the keyboard and Add hittable**, long
  names, edit prefill/Update, Remove, Cancel).

## Verification (real output)

```
dart format lib test                         → 166 files, clean
flutter analyze                              → No issues found
flutter test                                 → 188 passed, 7 skipped (was 171)
flutter test --tags objectbox --run-skipped  → 51 passed (was 49)
```

No ObjectBox schema change → no `build_runner` run needed.

## Remaining risks

- A business that uses **only plain numbers** (`0001`, `0002`) with an empty
  prefix field still gets the legacy `INV-0001` default suggestion (kept for
  back-compat). Typing any prefix — or nothing but a manual number — works as
  before. Revisit only if a real user hits it.
- Suggestion lookups run per prefix keystroke (one indexed per-business query
  on a local store); no debounce was added. Trivial cost at realistic invoice
  counts.
- Sheet keyboard behaviour is asserted in widget tests; real-device IME
  (autocorrect bars, floating keyboards) still deserves the manual QA below.

## Manual QA checklist

- [ ] Create invoice with default (empty) prefix → suggestion `INV-XXXX` continues the existing sequence
- [ ] Type prefix `QUO-` on a new invoice → number field re-suggests within QUO scope (starts `0001`)
- [ ] Switch prefix `QUO-` → `INV-` → back, before saving → suggestion follows each scope; no stale overwrite
- [ ] Edit an existing invoice → number/prefix unchanged on open and after save
- [ ] Type a manual custom number → it survives prefix changes and saves as typed
- [ ] Save a duplicate full number for the same business → blocked with the existing message
- [ ] Same number under a different business → allowed
- [ ] Add item on a small phone (SE-class) → all fields reachable, Add visible
- [ ] Add item with keyboard open → sheet lifts above keyboard; Add/Cancel tappable; fields scroll
- [ ] Add item with a very long name → no overflow; field scrolls horizontally
- [ ] Edit item → values prefilled; Update applies; Remove deletes; ✕ closes without changes
- [ ] Add-item sheet in dark mode → surface/labels/buttons themed correctly
- [ ] After adding items: totals update; preview/share PDF shows the same lines and totals
