import 'package:flutter/material.dart';

class MyDropdownMenu<T> extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final List<DropdownMenuEntry<T>>? entries;
  final T? initialSelection;
  final ValueChanged<T?>? onSelected;
  final bool enableSearch;
  final double borderRadius;
  final double? width;
  final bool isReadOnly;
  final bool isRequired;
  final int? Function(List<DropdownMenuEntry<T>>, String)? searchCallback;
  final EdgeInsetsGeometry? padding;

  const MyDropdownMenu({
    super.key,
    required this.label,
    this.leadingIcon,
    required this.entries,
    this.initialSelection,
    this.onSelected,
    this.enableSearch = false,
    this.borderRadius = 12,
    this.width,
    this.isReadOnly = false,
    this.padding,
    this.isRequired = false,
    this.searchCallback,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = entries == null || entries!.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = width ?? constraints.maxWidth;
        final isSearching =
            enableSearch && entries != null && entries!.isNotEmpty;
        return SizedBox(
          width: effectiveWidth,
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 0.0),
            child: isEmpty
                ? InputDecorator(
                    decoration: InputDecoration(
                      labelText: label,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (leadingIcon != null) ...[
                          Icon(
                            leadingIcon,
                            color: isReadOnly
                                ? Theme.of(context).disabledColor
                                : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'No options available',
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : DropdownMenu<T>(
                    enabled: !isReadOnly,
                    width: effectiveWidth,
                    menuStyle: MenuStyle(
                      maximumSize: WidgetStateProperty.all(
                        Size(effectiveWidth, double.infinity),
                      ),
                      minimumSize: WidgetStateProperty.all(
                        Size(effectiveWidth, 40),
                      ),
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                      ),
                    ),
                    alignmentOffset: const Offset(0, 2),
                    initialSelection: initialSelection,
                    textStyle: TextStyle(
                      color: isReadOnly
                          ? Theme.of(context).disabledColor
                          : null,
                    ),
                    searchCallback: searchCallback,
                    enableSearch: isSearching,
                    leadingIcon: leadingIcon != null ? Icon(leadingIcon) : null,
                    label: Text(label),
                    enableFilter: isSearching,
                    menuHeight: 400,
                    dropdownMenuEntries: entries!,
                    onSelected: onSelected,
                  ),
          ),
        );
      },
    );
  }
}
