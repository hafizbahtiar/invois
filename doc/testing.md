# Testing — Invois

## Running the suite

Default run (no native dependencies, used by CI by default):

```sh
~/flutter/bin/flutter test
```

This runs every test **except** those tagged `objectbox`, which are skipped via
[`dart_test.yaml`](../dart_test.yaml) so the suite stays green on any machine.

## Test tiers (blueprint §14)

| Tier | What | Where |
|---|---|---|
| **MUST** | Money spine — `InvoiceComposer` (totals/discount/multi-tax/rounding) | `test/features/invoice/invoice_composer_test.dart` |
| **MUST** | `Money` value object + S3 cents backfill | `test/core/money/`, `invoice_money_backfill_test.dart` |
| **MUST** | `Result` algebra | `test/core/result_test.dart` |
| **MUST** | Repository CRUD + reactive `watch` (real ObjectBox) | `invoice_repository_objectbox_test.dart` *(tagged `objectbox`)* |
| **MUST** | Signature export pipeline | `test/features/signature/signature_service_test.dart` |
| SHOULD | Query/filter notifier semantics | `invoice_query_test.dart` |

Pure, dependency-free units (composer, Money, Result) are the highest-ROI and
always run. The repository tests exercise the actual ObjectBox boundary
(in-query filtering, `watch` re-emission, dual-write) and therefore need the
native library — see below.

## ObjectBox-tagged tests (native library required)

Tests tagged `@Tags(['objectbox'])` open a real in-memory store:

```dart
Store(getObjectBoxModel(), directory: 'memory:...')
```

`flutter test` runs on the Dart VM, which does **not** bundle the ObjectBox C
library (`objectbox_flutter_libs` only ships it inside the Flutter app build).
The store constructor throws `loadObjectBoxLib` failures without it, so these
tests are **skipped by default**.

### One-time host / CI setup

Install the native lib once per machine (puts `libobjectbox.dylib` /
`.so` in `/usr/local/lib`):

```sh
bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
```

(See the ObjectBox Dart repo for the current `install.sh` URL and platform
notes. On macOS you may need to allow the unsigned dylib in System Settings →
Privacy & Security.)

### Running them once the lib is installed

```sh
~/flutter/bin/flutter test --tags objectbox --run-skipped
```

`--run-skipped` overrides the default skip from `dart_test.yaml`. CI that has
the lib installed should add a dedicated step with this command.

## Notes

- Invoice deletion is a **hard** delete (`Box.remove`); there is no soft-delete
  flag on `Invoice`, so the repository tests assert removal, not row-hiding.
- The PDF generator has a smoke test (`pdf_generation_test.dart`) asserting it
  produces a non-trivial document for a large, signed invoice without throwing.
  A pixel golden was evaluated but deferred — see that file's header.
