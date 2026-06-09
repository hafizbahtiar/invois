# Stage 2 Implementation Plan — Invoice Core Flow

## Status

Planning only. Not implemented yet.

## Context

Stage 1 has been completed and verified:

- `flutter analyze` is clean.
- Tests are green.
- Dead code was removed.
- System, light, and dark theme behavior was fixed.
- Unsafe invoice status parsing was fixed.
- Delete snackbar stale-state behavior was fixed.
- Invoice preview dark mode was improved.
- `InvoiceStatusChip` was added.
- `shadcn_flutter` was removed.

Stage 2 exists to turn the core invoice workflow into an MVP-ready flow. The current app can create, edit, list, preview, and delete invoices, but important production behaviors are incomplete: invoices do not have a real detail screen, signatures are not persisted on invoices, invoice numbers are not generated per business, payment recording is not exposed, and create/edit validation is too loose.

## Product Decisions

### Item vs Product

- Do not build a product catalog yet.
- Treat invoice items as invoice line items only.
- Avoid large item/product schema refactors in Stage 2.

### Numbering Scheme

- Use per-business invoice numbering.
- Format: `INV-0001`, `INV-0002`, `INV-0003`.
- Auto-generate for new invoices.
- Keep invoice number editable.
- Enforce uniqueness per business.
- No yearly reset.

### Recurring / Estimate / Credit Note Scope

- Keep existing model fields if present.
- Hide or de-emphasize these from the main MVP create flow.
- Focus Stage 2 on normal invoices.
- Do not build a recurring scheduler.
- Do not build estimate or credit-note behavior.

### Currency Decision

- Use the existing Settings-level default currency as the primary default.
- Preserve existing per-invoice currency.
- Do not add business currency in Stage 2.
- Do not deeply refactor currency behavior.

### Shipping / Fees Decision

- Do not add a shipping or fees model.
- Users can add shipping or fees as normal invoice line items.

### Detail vs Edit Decision

- Replace invoice `FormType.view` usage with a real invoice detail screen.
- Tapping an invoice from Home should open `InvoiceDetailPage`.
- Edit mode should open only when the user explicitly taps Edit.

## Confirmed Current Code Findings

### Invoice Model

- `lib/features/invoice/data/invoice_model.dart`
  - `Invoice` has no `signatureId`.
  - `Invoice` has `businessId`, `clientId`, `invoiceNumber`, `invoiceNumberPrefix`, `status`, `paymentStatus`, `paidAmount`, `balanceDue`, `sentDate`, and `paidDate`.
  - `Invoice` has additive minor-unit money fields:
    - `subtotalCents`
    - `discountAmountCents`
    - `taxAmountCents`
    - `totalCents`
    - `paidAmountCents`
    - `balanceDueCents`
  - `InvoiceStatusExtension.fromName`, `PaymentStatusExtension.fromName`, and `InvoiceTypeExtension.fromName` safely parse stored enum names.
  - `Invoice.canSend` already depends on `draft` status and non-empty items.

### Invoice Local Source

- `lib/features/invoice/data/invoice_local_source.dart`
  - `InvoiceLocalSource.watchInvoices(InvoiceQuery)` uses ObjectBox query watching.
  - `getInvoiceById(int id)` exists.
  - `getInvoicesByBusinessId(int businessId)` exists but currently uses `getAll().where(...)`.
  - `countInvoices()` exists.
  - `updateInvoiceStatus(int id, InvoiceStatus status)` exists.
  - `updatePaymentStatus(int id, PaymentStatus paymentStatus)` exists.
  - `markAsSent(int id)` exists and sets:
    - `status = InvoiceStatus.sent.name`
    - `sentDate = DateTime.now()`
  - `markAsPaid(int id, {double? paidAmount})` exists and updates paid/balance/status fields.
  - `updateInvoiceFields(...)` does not yet include `signatureId`.

### Invoice Repository

- `lib/features/invoice/data/invoice_repository.dart`
  - `InvoiceRepository.getCompleteInvoice(int id)` loads invoice and eagerly touches `items`, `taxes`, and `terms`.
  - Exposes:
    - `watchInvoices`
    - `create`
    - `update`
    - `delete`
    - `updateStatus`
    - relation helpers for items, taxes, and terms
  - Does not yet expose:
    - `markAsSent`
    - payment update or record-payment method
    - invoice numbering helpers
    - invoice-number uniqueness validation
  - Dual-writes cents and legacy double fields in `_withDualWrittenMoney`.

### Invoice Providers / State

- `lib/features/invoice/providers/invoice_notifier.dart`
  - `InvoiceFormNotifier.init(int? invoiceId, FormType type)` resets items, loads invoice when editing/viewing, otherwise creates a blank invoice and loads default business.
  - `getInvoiceById(int id)` loads business and client through form providers, then loads items, taxes, and terms.
  - `setSignature(signature)` exists.
  - `onUpsert(Invoice invoice)` validates business/client only, then saves invoice and relations.
  - `updateInvoiceStatus(int id, InvoiceStatus status)` only wraps repository `updateStatus`.

- `lib/features/invoice/providers/invoice_state.dart`
  - `InvoiceFormState` already has `Signature? signature`.
  - Signature is transient because `Invoice` has no persisted link.

- `lib/features/invoice/providers/invoice_providers.dart`
  - `invoiceListProvider` is a reactive `StreamProvider.autoDispose<List<Invoice>>`.
  - There is no `invoiceDetailProvider`.

- `invoiceFormProvider`
  - Currently a single global `StateNotifierProvider`.
  - Not `autoDispose`.
  - Not `family`.
  - This creates state-bleed risk between multiple invoices, detail, preview, and form flows.

### Invoice Form Page

- `lib/features/invoice/presentation/pages/invoice_form_page.dart`
  - Uses `settingsProvider` to default `_selectedCurrency`.
  - Preserves existing invoice currency when editing.
  - Shows invoice type, status, payment status, sent/viewed/paid dates, and recurring controls in the main form.
  - Debug mode currently pre-fills invoice number/reference/notes/dates.
  - Existing validation covers some required text fields and item bottom sheet parsing, but not all Stage 2 rules.
  - Does not expose a signature selector.
  - Does not auto-generate invoice numbers.
  - Save constructs a new `Invoice` without `signatureId`.

### Preview / PDF

- `lib/features/invoice/presentation/pages/invoice_preview_page.dart`
  - Loads invoice data through `invoiceFormProvider.notifier.getInvoiceById`.
  - Passes `state.signature` to `InvoiceGenerator`.
  - `_canShowPreview()` only requires business and client.
  - Preview can work without a signature, but signature loading is currently not persisted.

- `lib/features/invoice/pdf/invoice_generator.dart`
  - `InvoiceGenerator.generateInvoice(...)` accepts optional `Signature?`.
  - Signature rendering already supports:
    - `Signature.imageBytes`
    - fallback rendering from legacy `Signature.signatureData`
  - `previewInvoice`, `printInvoice`, `shareInvoice`, and `saveInvoice` all accept optional `Signature?`.
  - Generator throws when invoice has no items.

### Signature

- `lib/features/signature/data/signature_model.dart`
  - `Signature` has:
    - `businessId`
    - `isDefault`
    - `isActive`
    - `imageBytes`
    - legacy `signatureData`

- `lib/features/signature/data/signature_local_source.dart`
  - `getSignatureById(int id)` exists.
  - `getDefaultSignaturesByBusinessId(int? businessId)` exists.
  - `unsetDefaultSignaturesExcept(...)` enforces default uniqueness for the same `businessId` or general null-business scope.
  - `watchSignatures(SignatureQuery)` supports search, active, and default filters.

- `lib/features/signature/data/signature_repository.dart`
  - Exposes `watchSignatures`, `getSignatureById`, `create`, `update`, and `delete`.
  - Does not expose default-signature lookup helpers yet.

- `lib/features/signature/providers/signature_providers.dart`
  - `signatureListProvider` is `StreamProvider.autoDispose.family<List<Signature>, SignatureQuery>`.

### Business

- `lib/features/business/data/business_model.dart`
  - `Business` has no currency field.
  - `Business` has no default-signature link.
  - `Business` has `isDefault` and `isActive`.

- `lib/features/business/data/business_repository.dart`
  - `getDefaultBusiness()` returns the first default business or null.

- `lib/features/business/providers/business_providers.dart`
  - `businessListProvider` is reactive and parameterized by `BusinessQuery`.

### Settings / Default Currency

- `lib/features/setting/data/settings_local_source.dart`
  - Stores default currency in SharedPreferences under `currency_code`.
  - Defaults to `USD`.

- `lib/features/setting/providers/settings_state.dart`
  - `SettingsState.currencyCode` defaults to `USD`.

- `lib/features/setting/presentation/pages/settings_page.dart`
  - Exposes Default Currency settings UI.

### Routes

- `lib/configs/routes/routes_name.dart`
  - Has `invoiceForm` and `invoicePreview`.
  - Does not have `invoiceDetail`.

- `lib/configs/routes/generate_route.dart`
  - Routes `RoutesName.invoiceForm` to `InvoiceFormPage`.
  - Routes `RoutesName.invoicePreview` to `InvoicePreviewPage`.
  - Does not route invoice detail yet.

### Home Tap Behavior

- `lib/features/home/pages/home_page.dart`
  - Tapping an invoice currently pushes `RoutesName.invoiceForm` with:
    - `type: FormType.view.name`
    - `invoiceId: invoice.id`
  - Home popup menu already has Edit, Preview, Change Status, and Delete actions.

- `lib/features/invoice/presentation/widgets/invoice_list_partial.dart`
  - Also routes invoice tap to `InvoiceFormPage(FormType.view)`.
  - This file appears retained as a reusable list partial even though the old invoice list page was removed.

### Existing Tests

- `test/features/invoice/invoice_repository_objectbox_test.dart`
  - Covers repository CRUD, status update, and reactive watch.

- `test/features/invoice/invoice_query_test.dart`
  - Covers invoice query value semantics and query notifier behavior.

- `test/features/invoice/invoice_composer_test.dart`
  - Covers money composition, discounts, taxes, paid amount, and current overpayment behavior.

- `test/features/invoice/invoice_money_backfill_test.dart`
  - Covers legacy double-to-cents conversion.

- `test/features/invoice/invoice_status_parse_test.dart`
  - Covers safe status/type/payment parsing.

- `test/features/invoice/pdf_generation_test.dart`
  - Covers PDF generation with and without signature.
  - Covers no-item invoice exception.

- `test/features/signature/signature_service_test.dart`
  - Covers signature export empty failure.
  - Covers `Signature.imageBytes` JSON round-trip.

## Stage 2 Goals

- Add a real Invoice Detail Screen.
- Wire signatures end-to-end into invoice creation, editing, detail, preview, and PDF.
- Add auto invoice numbering per business.
- Add Record Payment flow.
- Add Mark as Sent flow.
- Improve core invoice validation.
- Reduce create/edit form confusion without a full redesign.

## Out of Scope

- Product catalog.
- Recurring scheduler.
- Estimate or credit-note behavior.
- Shipping or fees model.
- Deep currency refactor.
- Full form redesign.
- Stage 3 preview/PDF polish beyond required signature support.
- Stage 4 visual polish.

## User Flows After Stage 2

### Create Invoice

1. User taps Add Invoice.
2. Form preselects default business and default client where available.
3. Currency defaults from Settings-level default currency.
4. Invoice number auto-generates after business is known.
5. Default signature for the selected business is selected if available.
6. User edits fields, items, taxes, terms, currency, and signature.
7. Save validates the full invoice.
8. Invoice is persisted with relations and `signatureId`.

### View Invoice Detail

1. User taps invoice on Home.
2. App opens `InvoiceDetailPage`.
3. Detail provider loads invoice, business, client, items, taxes, terms, and signature.
4. User sees status, payment status, totals, dates, line items, business/client, signature, notes, and terms.
5. User can choose Edit, Preview/Share, Mark as Sent, Record Payment, or Delete.

### Edit Invoice

1. User taps Edit from detail or Home menu.
2. App opens `InvoiceFormPage(FormType.edit)`.
3. Existing invoice number, signature, currency, dates, items, taxes, and terms are loaded.
4. User updates the invoice.
5. Save revalidates uniqueness and totals.

### Select / Default Signature

1. New invoice selects the active default signature for selected business.
2. If none exists, app may fall back to active general default signature where `businessId == null`.
3. User can manually choose another active signature.
4. Invoice stores selected signature through `signatureId`.

### Mark As Sent

1. User opens invoice detail.
2. User taps Mark as Sent.
3. App updates `status` to `sent`.
4. App sets `sentDate` to current time.
5. Detail refreshes and shows success feedback.

### Record Payment

1. User opens invoice detail.
2. User taps Record Payment.
3. Bottom sheet asks for amount and paid date.
4. App validates the amount.
5. App updates paid amount, balance due, payment status, invoice status, and paid date.

### Preview / Share PDF

1. User opens invoice detail or preview route.
2. App loads complete invoice aggregate and persisted signature.
3. App passes `Signature?` to `InvoiceGenerator`.
4. PDF renders with signature if one exists.
5. User can preview, print, share, or save.

## Files To Change

| File | Change | Reason | Risk |
| --- | --- | --- | --- |
| `lib/features/invoice/data/invoice_model.dart` | Add nullable `signatureId`; update constructor, `props`, `copyWith`, `toMap`, `fromMap`, and possibly `toString`. | Persist invoice-signature link. | Medium: ObjectBox schema change. |
| `lib/core/database/objectbox-model.json` | Regenerate after model change. | ObjectBox model metadata must include `signatureId`. | Medium: model UID/migration safety. |
| `lib/core/database/objectbox.g.dart` | Regenerate after model change. | Generated ObjectBox bindings must include `signatureId`. | Medium: generated churn. |
| `lib/features/invoice/data/invoice_local_source.dart` | Add `signatureId` to field updates; add numbering and uniqueness helpers; expose safer payment/status helpers. | Support signature persistence, numbering, and payment actions. | Medium. |
| `lib/features/invoice/data/invoice_repository.dart` | Expose `markAsSent`, record payment, numbering helpers, and invoice-number availability validation. | Move Stage 2 write rules behind repository boundary. | Medium. |
| `lib/features/invoice/providers/invoice_notifier.dart` | Add signature/default-number initialization and stronger validation, or move some action logic into new providers. | Support create/edit Stage 2 behavior. | High: current global provider can bleed state. |
| `lib/features/invoice/providers/invoice_state.dart` | Add validation/detail fields if needed. | Represent form errors and selected persisted signature. | Low-medium. |
| `lib/features/invoice/providers/invoice_providers.dart` | Add `invoiceDetailProvider` family, possibly numbering provider. | Load complete detail/preview aggregate without shared form state. | Medium. |
| `lib/features/invoice/presentation/pages/invoice_form_page.dart` | Add signature selector, auto-numbering behavior, stricter validators, and hide/de-emphasize non-MVP controls. | MVP create/edit flow. | High: large file. |
| `lib/features/invoice/presentation/pages/invoice_preview_page.dart` | Load persisted signature via detail provider or repository path. | Avoid relying on transient form state. | Medium. |
| `lib/features/invoice/pdf/invoice_generator.dart` | Likely minimal or no changes. | Already accepts `Signature?`; only adjust if call path requires. | Low. |
| `lib/features/signature/data/signature_repository.dart` | Expose default signature lookup helpers. | Let invoice flow choose business default signature. | Low. |
| `lib/features/signature/data/signature_local_source.dart` | Add single-result/default-active helper if useful. | Avoid duplicating selection logic. | Low. |
| `lib/features/signature/data/signature_query.dart` | Consider adding `businessId` filter. | Cleaner signature selector filtering. | Low. |
| `lib/configs/routes/routes_name.dart` | Add `invoiceDetail`. | Route real detail screen. | Low. |
| `lib/configs/routes/generate_route.dart` | Route `invoiceDetail` to `InvoiceDetailPage`. | Navigation support. | Low. |
| `lib/features/home/pages/home_page.dart` | Change invoice row tap to detail route; preserve explicit Edit route. | Detail vs edit decision. | Low-medium. |
| `lib/features/invoice/presentation/widgets/invoice_list_partial.dart` | Change tap to detail route if still used. | Keep reusable list behavior consistent. | Low. |
| `lib/features/invoice/invoice.dart` | Export new detail page/provider if needed. | Maintain feature barrel exports. | Low. |

## New Files To Add

| File | Responsibility | Notes |
| --- | --- | --- |
| `lib/features/invoice/presentation/pages/invoice_detail_page.dart` | Read-only invoice detail screen and primary invoice actions. | `ConsumerWidget` or `ConsumerStatefulWidget`; watches `invoiceDetailProvider(invoiceId)`. |
| `lib/features/invoice/providers/invoice_detail_state.dart` | Typed detail DTO/state. | Example: `InvoiceDetailData(invoice, business, client, signature)`. Optional if kept in `invoice_providers.dart`. |
| `lib/features/invoice/presentation/widgets/record_payment_sheet.dart` | Bottom sheet for payment amount/date entry. | Optional but recommended to keep detail page smaller. |

## Data Model / Schema Changes

- Add nullable `int? signatureId` to `Invoice`.
- Keep it as a simple integer reference for Stage 2.
- Do not add an ObjectBox relation unless there is a clear local pattern for this relationship.
- Old invoices should remain valid with `signatureId == null`.
- Do not add `Business.currency`.
- Do not add `Business.defaultSignatureId`.
- Do not make `invoiceNumber` globally unique.
- Enforce invoice-number uniqueness per business in repository/local-source validation.

### Numbering Uniqueness

- Required uniqueness scope: `(businessId, invoiceNumber)`.
- Current ObjectBox model cannot express composite uniqueness directly in the existing simple model.
- Implement uniqueness check in repository/local source.
- Exclude current invoice ID when validating an edit.

### ObjectBox Migration Risk

- `Invoice` currently has ObjectBox `lastPropertyId` 38 in `objectbox-model.json`.
- Adding `signatureId` creates a new property and requires regenerating:
  - `lib/core/database/objectbox.g.dart`
  - `lib/core/database/objectbox-model.json`
- Review generated model diff carefully.
- Do not hand-edit ObjectBox UIDs unless ObjectBox requests a migration UID decision.

## Repository / Local Source Changes

### Invoice Local Source

Add or update:

- `updateInvoiceFields(...)`
  - Include `int? signatureId`.

- `getInvoicesByBusinessId(int businessId)`
  - Prefer ObjectBox query on `Invoice_.businessId` instead of full scan.

- `isInvoiceNumberAvailable({required int businessId, required String invoiceNumber, int? excludingInvoiceId})`
  - Query matching business and invoice number.
  - Return false if any match is not the excluded invoice.

- `nextInvoiceNumber(int businessId)`
  - Load invoices for business.
  - Parse matching `INV-####` invoice numbers.
  - Return next padded number.

- Payment helper
  - Prefer cents-based update over `double? paidAmount`.
  - Use existing money spine.

### Invoice Repository

Add:

- `Future<Result<void>> markAsSent(int id)`
- `Future<Result<Invoice>> recordPayment(int id, {required int amountCents, required DateTime paidDate})`
- `Future<Result<String>> nextInvoiceNumber(int businessId)`
- `Future<Result<bool>> isInvoiceNumberAvailable(...)`
- Possibly `Future<Result<void>> validateInvoiceForSave(...)`

Rules:

- Validate number uniqueness immediately before create/update.
- Keep money dual-write behavior in repository.
- Use cents for payment calculations.
- Return `ValidationFailure` for validation errors.
- Return `DatabaseFailure` for persistence failures.

### Signature Repository

Add:

- `Future<Signature?> getDefaultSignatureByBusinessId(int? businessId)`
- Optionally `Future<List<Signature>> getActiveSignaturesForBusiness(int? businessId)`

Selection logic should prefer:

1. Active default signature for selected business.
2. Active general default signature with `businessId == null`.
3. No signature.

## Provider / State Changes

### Recommended Minimum Safe Stage 2 Approach

- Add `invoiceDetailProvider` as `FutureProvider.autoDispose.family<InvoiceDetailData, int>`.
- Use it in:
  - `InvoiceDetailPage`
  - `InvoicePreviewPage`
- Keep `invoiceFormProvider` temporarily, but reset it carefully during form init.

### Better Stage 2 Approach

Convert:

- `invoiceFormProvider`

From:

- `StateNotifierProvider<InvoiceFormNotifier, InvoiceFormState>`

To:

- `StateNotifierProvider.autoDispose.family<InvoiceFormNotifier, InvoiceFormState, InvoiceFormArgs>`

Benefits:

- Avoids state bleed between invoices.
- Avoids preview/detail mutating form state.
- Makes create/edit lifecycle clearer.

### Detail Provider

`invoiceDetailProvider(invoiceId)` should load:

- `Invoice`
- `Business?`
- `Client?`
- `List<Item>`
- `List<Tax>`
- `List<Term>`
- `Signature?`

It should:

- Load persisted `invoice.signatureId` when present.
- Apply old-invoice fallback when `signatureId == null`.
- Avoid using form providers as lookup services.
- Prefer repositories for aggregate loading.

## UI Changes

### Invoice Detail Page

Display:

- Invoice number.
- Status chip.
- Payment status.
- Total.
- Paid amount.
- Balance due.
- Issue date.
- Due date.
- Sent date when present.
- Paid date when present.
- Business.
- Client.
- Line items.
- Taxes.
- Terms.
- Notes.
- Signature.

Actions:

- Edit.
- Preview / Share.
- Mark as Sent.
- Record Payment.
- Delete.

### Home Tap Behavior

- Row tap opens `RoutesName.invoiceDetail`.
- Edit popup menu opens `RoutesName.invoiceForm` with `FormType.edit`.
- Preview popup menu can continue opening `RoutesName.invoicePreview`.

### Invoice Form Page

Adjust main MVP flow:

- Keep normal invoice creation front and center.
- Add signature selector.
- Auto-fill invoice number once business is known.
- Keep currency selector but reduce prominence if needed.
- Hide or de-emphasize:
  - invoice type
  - manual status
  - manual payment status
  - sent/viewed/paid dates
  - recurring controls

### Signature Selector

- Show active signatures relevant to selected business.
- Include general active signatures if appropriate.
- Show selected signature name/title.
- Allow no signature if no signatures exist.

### Record Payment Bottom Sheet

Fields:

- Amount.
- Paid date, default today.

Display:

- Current balance due.
- Optional computed remaining balance after payment.

### Mark As Sent Action

- Available from detail.
- Prefer no confirmation for MVP.
- Show snackbar success/failure.
- Hide or disable if invoice is already sent, paid, cancelled, or refunded.

## Validation Rules

- Invoice number is required.
- Invoice number must be unique per business.
- Business is required.
- Client is required.
- At least one line item is required.
- Quantity must be greater than 0.
- Price must be greater than or equal to 0.
- Discount amount must be less than or equal to subtotal.
- Due date must be greater than or equal to issue date.
- Paid amount must be less than or equal to total unless explicit overpayment handling is added.
- Record payment amount must be greater than 0.
- Record payment amount must be less than or equal to current balance due unless overpayment handling is intentionally supported.

## Signature Wiring Plan

### New Invoice Default Selection

When business is selected:

1. Look for an active default signature with matching `businessId`.
2. If none, look for an active general default signature where `businessId == null`.
3. If found, set `InvoiceFormState.signature`.
4. On save, persist `invoice.signatureId = state.signature?.id`.

### Manual Selection

- User chooses active signature from selector.
- Form state updates `signature`.
- Save writes selected signature ID.

### Edit Existing Invoice

- If `invoice.signatureId` exists:
  - Load that signature.
  - Show it as selected.
- If `invoice.signatureId == null`:
  - Show fallback default signature as suggested selection.
  - Do not persist fallback until user saves.

### Detail / Preview / PDF

- Detail provider loads `Signature?`.
- Preview page uses detail provider or same aggregate load path.
- `InvoiceGenerator` receives `Signature?`.
- Existing PDF generator can already render the optional signature.

### Old Invoice Fallback

For old invoices with no `signatureId`:

- Prefer business default signature if available.
- Else prefer general default signature if available.
- Else render no signature.

## Auto-Numbering Plan

### Storage Format

Recommended for new invoices:

- Store full number in `invoiceNumber`: `INV-0001`.
- Leave `invoiceNumberPrefix` null or empty.

Reason:

- Current PDF concatenates `invoiceNumberPrefix` and `invoiceNumber`.
- Storing `invoiceNumberPrefix = 'INV'` and `invoiceNumber = '0001'` can produce formatting ambiguity.
- Storing full `INV-0001` in `invoiceNumber` avoids accidental double-prefix rendering.

### Calculation

For selected `businessId`:

1. Load existing invoices for that business.
2. Match invoice numbers with `^INV-(\d{4,})$`.
3. Parse numeric suffix.
4. Take max suffix.
5. Return `INV-${next.toString().padLeft(4, '0')}`.

### User Edits

- If user edits the generated number, preserve the custom value.
- Validate uniqueness before save.
- Do not auto-overwrite a manually edited number when other fields change.

### Duplicate Avoidance

- Validate when generated.
- Validate again immediately before create/update.
- For offline-only local ObjectBox, repository-level validation is acceptable MVP.
- If simultaneous invoice creation becomes possible, wrap number generation and insert in a store transaction.

## Record Payment Plan

### UI Fields

- Payment amount.
- Paid date, default today.

Do not add payment method or payment notes unless there is a model field to store them.

### Calculation

Use cents:

- `newPaidAmountCents = invoice.effectivePaidAmountCents + paymentAmountCents`
- `newBalanceDueCents = invoice.effectiveTotalCents - newPaidAmountCents`

### Status Logic

- If `newPaidAmountCents == 0`:
  - `paymentStatus = unpaid`
- If `newPaidAmountCents < totalCents`:
  - `paymentStatus = partiallyPaid`
- If `newPaidAmountCents == totalCents`:
  - `paymentStatus = paid`
  - `status = paid`

### Partial Payment

- Keep invoice status as-is unless the product explicitly requires changing it.
- Payment status carries partial state.

### Full Payment

- Set `paymentStatus = paid`.
- Set `status = paid`.
- Set `paidDate = selected paid date`.

### Paid Date Behavior

Because there is no payment ledger:

- MVP recommendation: update `paidDate` to the latest recorded payment date.
- For final payment, `paidDate` should definitely reflect the selected date.

## Mark As Sent Plan

### UI Action

- Place on `InvoiceDetailPage`.
- Show for draft invoices that can be sent.
- Hide or disable for sent, paid, cancelled, and refunded invoices.

### Update

Call repository method that updates:

- `status = InvoiceStatus.sent.name`
- `sentDate = DateTime.now()`
- `updatedAt = DateTime.now()`

### Confirmation

- No confirmation required for MVP.
- Show success/failure snackbar.

## Migration / Backward Compatibility Risks

- Adding `Invoice.signatureId` changes ObjectBox schema.
- Existing invoices must continue loading with `signatureId == null`.
- Old invoices should still preview and generate PDFs without signatures.
- Old invoices may use split `invoiceNumberPrefix` and `invoiceNumber`; new numbering should avoid breaking old display/PDF paths.
- Existing invoices with custom numbers should not affect `INV-####` suffix calculation unless they match the pattern.
- `invoiceFormProvider` global state may cause stale signature/business/client data if not isolated.
- `Signature.email` and `Signature.phone` are globally unique; not directly Stage 2, but signature creation can still fail on duplicates.
- Existing `InvoiceComposer` test documents overpayment as producing negative balance. Stage 2 validation should decide whether UI rejects overpayment while composer remains mathematically permissive.

## Tests To Add

### Unit Tests

- Invoice number parser:
  - Parses `INV-0001`.
  - Ignores custom numbers.
  - Handles gaps.
  - Pads to four digits.

- Invoice validation:
  - Missing business.
  - Missing client.
  - Missing invoice number.
  - Duplicate invoice number in same business.
  - Same invoice number in different business allowed.
  - No items.
  - Quantity <= 0.
  - Price < 0.
  - Discount > subtotal.
  - Due date before issue date.
  - Paid amount > total.

- Payment calculation:
  - Partial payment updates payment status.
  - Full payment updates invoice status and paid date.
  - Overpayment rejected if chosen.

### ObjectBox / Repository Tests

- `nextInvoiceNumber` returns `INV-0001` for first business invoice.
- `nextInvoiceNumber` is scoped per business.
- `isInvoiceNumberAvailable` excludes current invoice on edit.
- `markAsSent` sets status and sent date.
- `recordPayment` dual-writes cents and doubles.
- Invoice create/update persists `signatureId`.

### Provider Tests

- `invoiceDetailProvider` loads invoice aggregate.
- `invoiceDetailProvider` loads persisted signature.
- Old invoice without `signatureId` falls back to default signature or null.

### Widget Tests

- Home invoice tap routes to detail route.
- Detail page shows invoice number, status, totals, line items.
- Record payment sheet validates amount.
- Form shows selected signature.

### PDF Tests

- Existing signed PDF test should continue passing.
- Add test that loaded/persisted signature path passes a signature into generation if provider-level test coverage is practical.

## Manual QA Checklist

- [ ] Create first invoice for a business; number is `INV-0001`.
- [ ] Create second invoice for same business; number is `INV-0002`.
- [ ] Create first invoice for another business; number is `INV-0001`.
- [ ] Edit invoice number manually; save works when unique.
- [ ] Duplicate number in same business is rejected.
- [ ] Same number in different business is allowed.
- [ ] New invoice selects business default signature.
- [ ] New invoice falls back gracefully when no signature exists.
- [ ] Edit invoice preserves selected signature.
- [ ] Detail page loads after tapping invoice from Home.
- [ ] Edit opens only after tapping Edit.
- [ ] Mark as Sent updates status and sent date.
- [ ] Record partial payment updates payment status and balance.
- [ ] Record full payment updates status to paid.
- [ ] Preview/share PDF includes selected signature.
- [ ] Old invoice without signature still previews.
- [ ] Form rejects missing business/client/items.
- [ ] Form rejects due date before issue date.
- [ ] Form rejects discount greater than subtotal.
- [ ] Form rejects overpayment if overpayment is not supported.
- [ ] Dark mode remains readable on detail, form, and preview.

## Step-by-Step Implementation Order

### Stage 2A — Invoice Detail Screen

#### Objective

Add a real read-only invoice detail route and stop using `InvoiceFormPage(FormType.view)` as the main invoice view.

#### Files

- `lib/features/invoice/presentation/pages/invoice_detail_page.dart`
- `lib/features/invoice/providers/invoice_detail_state.dart`
- `lib/features/invoice/providers/invoice_providers.dart`
- `lib/configs/routes/routes_name.dart`
- `lib/configs/routes/generate_route.dart`
- `lib/features/home/pages/home_page.dart`
- `lib/features/invoice/presentation/widgets/invoice_list_partial.dart`
- `lib/features/invoice/invoice.dart`

#### Steps

- [ ] Add `RoutesName.invoiceDetail`.
- [ ] Add route handling in `generate_route.dart`.
- [ ] Add `InvoiceDetailData` DTO.
- [ ] Add `invoiceDetailProvider(invoiceId)`.
- [ ] Build `InvoiceDetailPage`.
- [ ] Route Home row taps to invoice detail.
- [ ] Route reusable invoice list partial taps to invoice detail.
- [ ] Keep explicit Edit action routing to `InvoiceFormPage(FormType.edit)`.

#### Acceptance Criteria

- Tapping an invoice opens detail screen.
- Detail screen is read-only.
- Edit only opens from explicit Edit action.
- Detail screen displays core invoice aggregate data.

#### Tests

- Widget or route test for Home tap behavior.
- Provider test for loading invoice detail aggregate.

### Stage 2B — Signature Wiring

#### Objective

Persist selected signatures on invoices and load them consistently in detail, edit, preview, and PDF paths.

#### Files

- `lib/features/invoice/data/invoice_model.dart`
- `lib/core/database/objectbox-model.json`
- `lib/core/database/objectbox.g.dart`
- `lib/features/invoice/data/invoice_local_source.dart`
- `lib/features/invoice/data/invoice_repository.dart`
- `lib/features/invoice/providers/invoice_notifier.dart`
- `lib/features/invoice/providers/invoice_providers.dart`
- `lib/features/invoice/presentation/pages/invoice_form_page.dart`
- `lib/features/invoice/presentation/pages/invoice_preview_page.dart`
- `lib/features/signature/data/signature_repository.dart`
- `lib/features/signature/data/signature_local_source.dart`

#### Steps

- [ ] Add nullable `signatureId` to `Invoice`.
- [ ] Regenerate ObjectBox files.
- [ ] Add `signatureId` to map/copy/update paths.
- [ ] Expose default-signature lookup from signature repository.
- [ ] Load default signature when business is selected on new invoice.
- [ ] Add signature selector to invoice form.
- [ ] Persist selected signature ID on save.
- [ ] Load persisted signature on edit.
- [ ] Load persisted/fallback signature on detail and preview.

#### Acceptance Criteria

- New invoice can save with a selected signature.
- Edit invoice shows saved signature.
- Detail page shows saved signature.
- Preview/share PDF renders saved signature.
- Old invoices without `signatureId` still work.

#### Tests

- Repository test for persisting `signatureId`.
- Provider test for detail loading persisted signature.
- Provider or unit test for default signature fallback.
- Existing PDF tests remain green.

### Stage 2C — Auto-numbering + Validation

#### Objective

Generate per-business invoice numbers and enforce core invoice validation before saving.

#### Files

- `lib/features/invoice/data/invoice_local_source.dart`
- `lib/features/invoice/data/invoice_repository.dart`
- `lib/features/invoice/providers/invoice_notifier.dart`
- `lib/features/invoice/presentation/pages/invoice_form_page.dart`
- Optional test helper file for invoice-number parsing.

#### Steps

- [ ] Add invoice-number parsing helper.
- [ ] Add `nextInvoiceNumber(businessId)`.
- [ ] Add `isInvoiceNumberAvailable(...)`.
- [ ] Auto-generate invoice number when business is known.
- [ ] Preserve user-edited invoice numbers.
- [ ] Add repository/form validation.
- [ ] Hide or de-emphasize non-MVP form controls.
- [ ] Validate again immediately before save.

#### Acceptance Criteria

- First business invoice gets `INV-0001`.
- Second business invoice gets `INV-0002`.
- Numbering is scoped per business.
- Duplicate same-business number is rejected.
- Core validation errors are shown clearly.

#### Tests

- Unit tests for number parsing/generation.
- ObjectBox repository tests for scoped numbering.
- Validation tests for required fields and invalid totals/dates.

### Stage 2D — Record Payment + Mark as Sent

#### Objective

Expose payment/status actions from invoice detail with correct money/status updates.

#### Files

- `lib/features/invoice/data/invoice_local_source.dart`
- `lib/features/invoice/data/invoice_repository.dart`
- `lib/features/invoice/providers/invoice_providers.dart`
- `lib/features/invoice/presentation/pages/invoice_detail_page.dart`
- `lib/features/invoice/presentation/widgets/record_payment_sheet.dart`
- Optional action notifier/state file.

#### Steps

- [ ] Expose `markAsSent` through repository.
- [ ] Add cents-based `recordPayment`.
- [ ] Add detail action for Mark as Sent.
- [ ] Add record-payment bottom sheet.
- [ ] Validate payment amount/date.
- [ ] Refresh/invalidate detail and list providers after actions.
- [ ] Show snackbar feedback.

#### Acceptance Criteria

- Draft invoice can be marked sent.
- Sent date is set.
- Partial payment updates paid amount, balance, and payment status.
- Full payment updates status to paid and sets paid date.
- Invalid payment amount is rejected.

#### Tests

- Repository tests for mark-as-sent.
- Repository tests for partial and full payment.
- Widget test for payment bottom sheet validation if practical.

## Risks / Things To Verify Before Coding

- Confirm whether new invoices should store `invoiceNumber = 'INV-0001'` and empty prefix, or preserve prefix/number split. Recommended: full number in `invoiceNumber`.
- Confirm whether old invoice fallback should actually use default signature in PDFs or show no signature until explicitly selected.
- Confirm whether overpayment should be rejected in UI while `InvoiceComposer` remains permissive.
- Verify ObjectBox code generation command and model UID handling before editing schema.
- Verify `invoiceFormProvider` can be converted to `autoDispose.family` without too much churn; otherwise isolate detail/preview first.
- Verify active signature filtering by business can be implemented without hiding useful general signatures.
- Verify debug form prefill should be removed or gated more safely for Stage 2.
- Verify whether `invoice_list_partial.dart` is still used; update it if retained.

## Approval Gate

Do not implement Stage 2 until this plan is reviewed and approved.
