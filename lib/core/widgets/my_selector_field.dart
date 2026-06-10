import 'package:flutter/material.dart';
import 'package:invois/core/widgets/my_multi_select_bottom_sheet.dart';
import 'package:invois/core/widgets/my_select_bottom_sheet.dart';

class MySelectorField<T> extends StatelessWidget {
  final String label;
  final String? value;
  final String? hintText;
  final VoidCallback? onTap;
  final bool isReadOnly;
  final Widget? leading;
  final IconData? icon;
  final bool isMultiSelect;
  final int? selectedCount;
  final bool showBadge;

  // For single select
  final T? selectedValue;
  final List<SelectItem<T>>? selectItems;
  final Function(T)? onSelected;

  // For multi select
  final List<T>? selectedValues;
  final List<MultiSelectItem<T>>? multiSelectItems;
  final Function(List<T>)? onMultiSelected;

  // Shared properties
  final String? searchHint;
  final bool searchable;
  final Map<String, List<SelectItem<T>>>? groupedItems;
  final Map<String, List<MultiSelectItem<T>>>? groupedMultiItems;

  // Clear functionality
  final bool showClearButton;
  final VoidCallback? onClear;

  // Form validation
  final String? Function(String?)? validator;
  final bool isRequired;
  final AutovalidateMode autovalidateMode;

  const MySelectorField({
    super.key,
    required this.label,
    this.value,
    this.hintText,
    this.onTap,
    this.isReadOnly = false,
    this.leading,
    this.icon,
    this.isMultiSelect = false,
    this.selectedCount,
    this.showBadge = true,
    this.selectedValue,
    this.selectItems,
    this.onSelected,
    this.selectedValues,
    this.multiSelectItems,
    this.onMultiSelected,
    this.searchHint,
    this.searchable = true,
    this.groupedItems,
    this.groupedMultiItems,
    this.showClearButton = true,
    this.onClear,
    this.validator,
    this.isRequired = false,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : assert(
         (onTap != null) ||
             (isMultiSelect &&
                 multiSelectItems != null &&
                 onMultiSelected != null) ||
             (!isMultiSelect && selectItems != null && onSelected != null),
         'Either provide onTap or appropriate items and callbacks based on isMultiSelect',
       );

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator:
          validator ??
          (isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$label is required';
                  }
                  return null;
                }
              : null),
      autovalidateMode: autovalidateMode,
      initialValue: value,
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectorWidget(context, field),
            if (field.hasError) ...[
              const SizedBox(height: 8),
              Text(
                field.errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSelectorWidget(
    BuildContext context,
    FormFieldState<String> field,
  ) {
    final theme = Theme.of(context);

    final hasValue = value != null && value!.isNotEmpty;
    final canClear =
        !isReadOnly && hasValue && showClearButton && onClear != null;

    void handleTap() {
      if (isReadOnly) return;

      if (onTap != null) {
        onTap!();
        return;
      }

      if (isMultiSelect &&
          multiSelectItems != null &&
          onMultiSelected != null) {
        _showMultiSelectBottomSheet(context);
      } else if (!isMultiSelect && selectItems != null && onSelected != null) {
        _showSelectBottomSheet(context);
      }
    }

    void handleClear() {
      if (onClear != null) {
        onClear!();
        field.didChange(null);
      }
    }

    return InkWell(
      onTap: isReadOnly ? null : handleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: field.hasError
                ? theme.colorScheme.error
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (leading != null || icon != null) ...[
              leading ??
                  Icon(
                    icon,
                    color: isReadOnly
                        ? theme.disabledColor
                        : theme.colorScheme.primary,
                  ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRequired ? '$label *' : label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isReadOnly
                          ? theme.disabledColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  value == null || value!.isEmpty
                      ? Text(
                          hintText ?? 'Select $label',
                          style: TextStyle(
                            color: isReadOnly
                                ? theme.disabledColor
                                : theme.hintColor,
                          ),
                        )
                      : Text(value!, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            if (canClear)
              InkWell(
                onTap: handleClear,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (isMultiSelect &&
                selectedCount != null &&
                selectedCount! > 0 &&
                showBadge)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$selectedCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!isReadOnly) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMultiSelectBottomSheet(BuildContext context) async {
    if (multiSelectItems == null || onMultiSelected == null) return;

    final result = await MyMultiSelectBottomSheet.show<T>(
      context: context,
      title: label,
      items: multiSelectItems!,
      initialSelectedValues: selectedValues ?? [],
      searchable: searchable,
      searchHint: searchHint ?? 'Search',
      groupedItems: groupedMultiItems,
    );

    if (result != null) {
      onMultiSelected!(result);
    }
  }

  Future<void> _showSelectBottomSheet(BuildContext context) async {
    if (selectItems == null || onSelected == null) return;

    final result = await MySelectBottomSheet.show<T>(
      context: context,
      title: label,
      items: selectItems!,
      initialSelectedValue: selectedValue,
      searchable: searchable,
      searchHint: searchHint ?? 'Search',
      groupedItems: groupedItems,
    );

    if (result != null) {
      onSelected!(result);
    }
  }
}

class SelectItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? icon;

  const SelectItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}

class MultiSelectItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? icon;

  const MultiSelectItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}
