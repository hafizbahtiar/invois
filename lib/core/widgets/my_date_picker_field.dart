import 'package:flutter/material.dart';
import 'package:invois/core/utils/date_utils.dart' as app_date_utils;

class MyDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String? hintText;
  final VoidCallback? onTap;
  final bool isReadOnly;
  final Widget? leading;
  final IconData? icon;
  final Function(DateTime)? onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? dateFormat;
  final bool showClearButton;
  final VoidCallback? onClear;
  final String? locale;

  // Date range mode
  final bool isRangeMode;
  final DateTimeRange? dateRange;
  final Function(DateTimeRange)? onDateRangeSelected;

  const MyDatePickerField({
    super.key,
    required this.label,
    this.value,
    this.hintText,
    this.onTap,
    this.isReadOnly = false,
    this.leading,
    this.icon = Icons.calendar_today,
    this.onDateSelected,
    this.firstDate,
    this.lastDate,
    this.dateFormat,
    this.showClearButton = true,
    this.onClear,
    this.locale,
    this.isRangeMode = false,
    this.dateRange,
    this.onDateRangeSelected,
  }) : assert(
         (onTap != null) ||
             (!isRangeMode && onDateSelected != null) ||
             (isRangeMode && onDateRangeSelected != null),
         'Either provide onTap or appropriate callbacks based on isRangeMode',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasValue = isRangeMode ? dateRange != null : value != null;
    final canClear =
        !isReadOnly && hasValue && showClearButton && onClear != null;

    void handleTap() {
      if (isReadOnly) return;

      if (onTap != null) {
        onTap!();
        return;
      }

      if (isRangeMode) {
        _showDateRangePicker(context);
      } else {
        _showDatePicker(context);
      }
    }

    String getDisplayText() {
      if (isRangeMode) {
        if (dateRange == null) {
          return hintText ?? '-';
        }

        final startFormatted = _formatDate(dateRange!.start);
        final endFormatted = _formatDate(dateRange!.end);
        return '$startFormatted - $endFormatted';
      } else {
        if (value == null) {
          return hintText ?? '-';
        }
        return _formatDate(value!);
      }
    }

    return InkWell(
      onTap: isReadOnly ? null : handleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isReadOnly
                          ? theme.disabledColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getDisplayText(),
                    style: hasValue
                        ? theme.textTheme.bodyLarge?.copyWith(
                            color: isReadOnly
                                ? theme.disabledColor
                                : theme.colorScheme.onSurfaceVariant,
                          )
                        : TextStyle(
                            color: isReadOnly
                                ? theme.disabledColor
                                : theme.hintColor,
                          ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (canClear)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isReadOnly
                        ? theme.disabledColor
                        : theme.colorScheme.onSurfaceVariant,
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

  String _formatDate(DateTime date) {
    if (dateFormat != null) {
      return app_date_utils.DateUtils.format(
        date,
        pattern: dateFormat!,
        locale: locale,
      );
    }
    return app_date_utils.DateUtils.formatReadable(date, locale: locale);
  }

  Future<void> _showDatePicker(BuildContext context) async {
    if (onDateSelected == null) return;

    final now = DateTime.now();
    final initialDate = value ?? now;
    final firstDateValue = firstDate ?? DateTime(2000);
    final lastDateValue = lastDate ?? DateTime(2100);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDateValue,
      lastDate: lastDateValue,
    );

    if (pickedDate != null) {
      onDateSelected!(pickedDate);
    }
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    if (onDateRangeSelected == null) return;

    final now = DateTime.now();
    final firstDateValue = firstDate ?? DateTime(2000);
    final lastDateValue = lastDate ?? DateTime(2100);

    final initialDateRange =
        dateRange ??
        DateTimeRange(start: now, end: now.add(const Duration(days: 7)));

    final pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: firstDateValue,
      lastDate: lastDateValue,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      onDateRangeSelected!(pickedDateRange);
    }
  }
}
