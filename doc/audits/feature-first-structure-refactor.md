# Feature-First Structure Refactor

> Date: 2026-06-11 · Branch: `dev` · Structure/naming only — **zero behavior
> change**. Follow-up to `invois-full-audit-fix-summary.md`.

## Goal

Organize `lib/` into a consistent feature-first layout, dissolve the
catch-all `configs/` and `features/shared/` folders, group the invoice
feature's loose root files into a `domain/` layer, and fix the few naming
inconsistencies — without touching business logic, calculations,
payment/status rules, ObjectBox schema, PDF output, routing behavior, or UI.

## Final structure

```
lib/
  main.dart
  core/
    constants/  database/  l10n/  models/   money/
    providers/  result/    routing/ utils/  widgets/
  features/
    business/  client/  signature/  tax/  term/   each:
        data/          (model + query + local source + repository)
        providers/     (state + notifier + providers)
        presentation/  (pages/, widgets/ where present)
        <feature>.dart (barrel)
    invoice/
        data/          (invoice_model, invoice_line_model, query,
                        local source, repository, money backfill)
        domain/        (composer, payment, numbering, validation,
                        form_line, line_builder, line_math, line_view,
                        quantity_input — pure Dart, no persistence)
        pdf/           (generator, tax breakdown, fonts — invoice-specific)
        providers/  presentation/  invoice.dart
    settings/  home/  splash/      (presentation/pages/ aligned)
```

## Moves

| From | To |
|---|---|
| `lib/configs/routes/{routes_name,generate_route}.dart` | `lib/core/routing/` |
| `lib/configs/l10n/**` (+ `l10n.yaml` paths) | `lib/core/l10n/**` |
| `lib/core/error/failure_mapper.dart` | `lib/core/result/` (co-located with `AppFailure`/`Result`) |
| `lib/features/shared/widgets/*` (19 files) | `lib/core/widgets/` |
| `lib/features/shared/pages/no_route_page.dart` | `lib/core/routing/` (the router's fallback page) |
| `lib/features/shared/models/address_model.dart` | `lib/core/models/` (shared by business + client) |
| `lib/features/setting/**` | `lib/features/settings/**` (folder now matches its `settings_*.dart` files; barrel `setting.dart` → `settings.dart`) |
| `lib/features/home/pages/` | `lib/features/home/presentation/pages/` |
| `lib/features/splash/splash_page.dart` | `lib/features/splash/presentation/pages/` |
| Invoice root loose files (7) + `data/{invoice_numbering,invoice_validation}.dart` | `lib/features/invoice/domain/` |
| `test/features/setting/` | `test/features/settings/` |
| `test/features/shared/app_bottom_sheet_test.dart` | `test/core/widgets/` |

Also removed two empty leftover directories (`lib/features/item/`,
`lib/features/home/widgets/`).

## Renames (functions)

- `_showAddItemDialog` → `_showLineItemSheet` (invoice form page — it opens a
  bottom sheet, not a dialog).
- `InvoiceFormNotifier.resetItems()` → `resetLines()` (it resets the
  `lines` draft; "items" is retired vocabulary from the legacy schema).

No other function renames — existing names are clear and conventional.

## Intentionally NOT changed (and why)

- **ObjectBox entity files stay in `features/*/data/`** (not `domain/models/`):
  this is the existing app-wide convention for all six entity features, and
  moving them would churn `objectbox.g.dart` imports for zero clarity gain.
  Only `address_model.dart` moved (its `shared` home was being dissolved).
- **`providers/` stays at feature level** (not `presentation/providers/`):
  the existing convention in all seven features; Riverpod providers here
  bridge data↔UI, and moving 21 files under presentation adds churn, not
  clarity.
- **`features/invoice/pdf/` stays** as the invoice-specific PDF home (the
  target's "clear invoice PDF folder" option) — no separate `pdf` feature, as
  nothing else generates PDFs.
- **No `data/local/` + `data/repositories/` subfolders**: every feature has
  exactly one local source and one repository; single-file subfolders are
  over-nesting for this app's size.
- **No file renames** (`*_model.dart`, `*_local_source.dart`,
  `*_repository.dart`, `*_page.dart` are already consistent app-wide).
- **No ObjectBox class/field/relation renames; no route name changes; no
  public API renames** beyond the two functions above.
- **Test files keep their names and flat per-feature layout** (already
  feature-first; splitting into domain/data/presentation subfolders would
  obscure history for no gain).

## ObjectBox safety notes

- `objectbox-model.json`: **zero diff** (verified).
- `objectbox.g.dart`: regenerated via
  `dart run build_runner build --delete-conflicting-outputs` solely because
  `address_model.dart` (an `@Entity`) moved. The entire diff is **one import
  line** (`features/shared/models/` → `core/models/`) — inspected before
  keeping. No entities, persisted fields, annotations, or relations changed.
- `flutter gen-l10n` re-ran after the l10n move; output identical apart from
  location.
- The 51 objectbox-tagged tests pass against the regenerated bindings.

## Test updates

- Import paths updated across all 31 test files (package-path moves only).
- `test/features/setting` → `test/features/settings`;
  `app_bottom_sheet_test` follows its widget to `test/core/widgets/`.
- The architecture guard test needed **no changes**: its patterns
  (`/presentation/`, `lib/core/database/objectbox.g.dart`, legacy-item
  patterns) are location-stable under this refactor.
- No tests deleted, weakened, or skipped.

## Verification (real output)

```
dart format .                                → 166 files, 0 changed
flutter analyze                              → No issues found
flutter test                                 → 188 passed, 7 skipped
flutter test --tags objectbox --run-skipped  → 51 passed
```

Identical pass counts to before the refactor — behavior preserved.

## Remaining risks

- Git history: moves are recorded as renames (`git mv`, ~46 R entries);
  `git log --follow` works per file.
- Any un-merged local branches touching moved files will need rebase
  conflict resolution against the new paths.
- IDE run configs or scripts hardcoding old paths (none found in the repo)
  would need updating.
