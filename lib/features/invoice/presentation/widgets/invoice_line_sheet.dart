import 'package:flutter/material.dart';
import 'package:invois/core/money/money.dart';
import 'package:invois/features/shared/widgets/app_bottom_sheet.dart';
import 'package:invois/features/shared/widgets/my_text_field.dart';

import '../../invoice_form_line.dart';
import '../../invoice_quantity_input.dart';

/// Outcome of [InvoiceLineSheet.show]: a built/edited [line], or a request to
/// remove the existing line. Plain dismissal (drag down, tap outside, Cancel)
/// returns null.
class InvoiceLineSheetResult {
  final InvoiceFormLine? line;
  final bool removed;

  const InvoiceLineSheetResult.saved(InvoiceFormLine this.line)
    : removed = false;

  const InvoiceLineSheetResult.removed() : line = null, removed = true;
}

/// Add/edit sheet for one invoice line.
///
/// Built on the shared [AppBottomSheet] shell so it inherits the app-wide
/// sheet behaviour: content-sized when short, capped at [maxHeightFactor] and
/// scrollable when tall, lifted above the keyboard via `viewInsets`, footer
/// actions pinned and always reachable, SafeArea + dark mode via the theme.
/// (Replaces a fixed-fraction DraggableScrollableSheet that collapsed the
/// fields area to a sliver when the keyboard opened on small phones.)
class InvoiceLineSheet extends StatefulWidget {
  final InvoiceFormLine? existingLine;
  final String currencyCode;

  /// id given to a newly added line (the form's negative temporary id).
  final int temporaryLineId;

  const InvoiceLineSheet({
    super.key,
    this.existingLine,
    required this.currencyCode,
    required this.temporaryLineId,
  });

  static Future<InvoiceLineSheetResult?> show(
    BuildContext context, {
    InvoiceFormLine? existingLine,
    required String currencyCode,
    required int temporaryLineId,
  }) {
    return showModalBottomSheet<InvoiceLineSheetResult>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceLineSheet(
        existingLine: existingLine,
        currencyCode: currencyCode,
        temporaryLineId: temporaryLineId,
      ),
    );
  }

  @override
  State<InvoiceLineSheet> createState() => _InvoiceLineSheetState();
}

class _InvoiceLineSheetState extends State<InvoiceLineSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(
    text: widget.existingLine?.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existingLine?.description ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.existingLine == null
        ? ''
        : Money(
            widget.existingLine!.unitPriceCents,
            currencyCode: widget.currencyCode,
          ).toDouble().toStringAsFixed(2),
  );
  late final _quantityController = TextEditingController(
    text: widget.existingLine == null
        ? '1'
        : InvoiceQuantityInput.format(widget.existingLine!.quantityMilli),
  );

  bool get _isEditing => widget.existingLine != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price =
        Money.tryParseDecimalString(
          _priceController.text,
          currencyCode: widget.currencyCode,
        ) ??
        Money.zero(currencyCode: widget.currencyCode);
    final parsed = InvoiceQuantityInput.parse(_quantityController.text);
    // Validators already block invalid input; defensive.
    if (!parsed.isValid) return;

    final existing = widget.existingLine;
    final line = InvoiceFormLine(
      id: existing?.id ?? widget.temporaryLineId,
      name: _nameController.text,
      description: _descriptionController.text,
      unitPriceCents: price.minorUnits,
      currency: widget.currencyCode,
      quantityMilli: parsed.quantityMilli!,
      taxRateBasisPoints: existing?.taxRateBasisPoints,
      sortOrder: existing?.sortOrder ?? 0,
      sourceItemId: existing?.sourceItemId,
    );

    Navigator.pop(context, InvoiceLineSheetResult.saved(line));
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: _isEditing ? 'Edit Item' : 'Add Item',
      showCloseButton: _isEditing,
      maxHeightFactor: 0.9,
      actions: [
        if (_isEditing)
          AppBottomSheetAction(
            label: 'Remove',
            isPrimary: false,
            isDestructive: true,
            onPressed: () =>
                Navigator.pop(context, const InvoiceLineSheetResult.removed()),
          )
        else
          AppBottomSheetAction(
            label: 'Cancel',
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
        AppBottomSheetAction(
          label: _isEditing ? 'Update' : 'Add',
          onPressed: _submit,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyTextField(
                controller: _nameController,
                label: 'Name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              MyTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MyTextField(
                      controller: _priceController,
                      label: 'Price',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final parsed = Money.tryParseDecimalString(
                          value,
                          currencyCode: widget.currencyCode,
                        );
                        if (parsed == null) {
                          return 'Invalid number';
                        }
                        if (parsed.minorUnits < 0) {
                          return 'Must be 0 or more';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MyTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final result = InvoiceQuantityInput.parse(value ?? '');
                        return result.isValid ? null : result.error;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
