import 'package:flutter/material.dart';

/// A beautiful, reusable bottom sheet widget with draggable functionality.
///
/// Features:
/// - Draggable with visual handle
/// - Customizable header with icon, title, and subtitle
/// - Flexible content area with scrolling
/// - Pre-built action buttons
/// - Theme-aware styling
///
/// Usage Examples:
///
/// ```dart
/// // Simple bottom sheet
/// MyBottomSheetHelper.show(
///   context: context,
///   title: 'Simple Title',
///   content: Text('Your content here'),
///   actions: [
///     MyBottomSheetActions.cancelButton(onPressed: () => Navigator.pop(context)),
///     MyBottomSheetActions.primaryButton(
///       onPressed: () => Navigator.pop(context),
///       text: 'Save',
///     ),
///   ],
/// );
///
/// // Advanced bottom sheet with custom styling
/// MyBottomSheetHelper.show(
///   context: context,
///   title: 'Advanced Title',
///   subtitle: 'Optional subtitle',
///   icon: Icons.settings,
///   content: YourCustomWidget(),
///   initialChildSize: 0.5,
///   maxChildSize: 0.9,
///   backgroundColor: Colors.blue.shade50,
///   actions: [
///     MyBottomSheetActions.deleteButton(onPressed: () => delete()),
///     MyBottomSheetActions.primaryButton(
///       onPressed: () => save(),
///       text: 'Save Changes',
///       backgroundColor: Colors.green,
///     ),
///   ],
/// );
/// ```

class MyBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget content;
  final List<Widget>? actions;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool showDragHandle;
  final bool showDivider;
  final EdgeInsets? contentPadding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const MyBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.content,
    this.actions,
    this.initialChildSize = 0.4,
    this.minChildSize = 0.3,
    this.maxChildSize = 0.8,
    this.showDragHandle = true,
    this.showDivider = true,
    this.contentPadding,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Theme.of(context).colorScheme.surface,
          borderRadius:
              borderRadius ??
              const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow:
              boxShadow ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
        ),
        child: Column(
          children: [
            // Drag handle
            if (showDragHandle)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            if (showDivider) const Divider(height: 32),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding:
                    contentPadding ??
                    const EdgeInsets.symmetric(horizontal: 24),
                child: content,
              ),
            ),
            // Action buttons
            if (actions != null && actions!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:
                      backgroundColor ?? Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: actions!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    return Expanded(
                      child: index > 0
                          ? Row(
                              children: [
                                const SizedBox(width: 12),
                                Expanded(child: action),
                              ],
                            )
                          : action,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper class for showing the bottom sheet
class MyBottomSheetHelper {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    required Widget content,
    List<Widget>? actions,
    double initialChildSize = 0.4,
    double minChildSize = 0.3,
    double maxChildSize = 0.8,
    bool showDragHandle = true,
    bool showDivider = true,
    EdgeInsets? contentPadding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
    bool isScrollControlled = true,
    bool isDismissible = true,
    String? barrierLabel,
    Color? barrierColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      barrierLabel: barrierLabel ?? 'Dismiss',
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
      backgroundColor: Colors.transparent,
      builder: (context) => MyBottomSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        content: content,
        actions: actions,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        showDragHandle: showDragHandle,
        showDivider: showDivider,
        contentPadding: contentPadding,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
    );
  }
}

// Pre-built action buttons for common use cases
class MyBottomSheetActions {
  static Widget cancelButton({
    required VoidCallback onPressed,
    String text = 'Cancel',
    Color? color,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  static Widget primaryButton({
    required VoidCallback onPressed,
    required String text,
    bool isEnabled = true,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
    FontWeight? fontWeight,
  }) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
          backgroundColor:
              backgroundColor ?? Theme.of(context).colorScheme.primary,
          foregroundColor: textColor ?? Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: fontWeight ?? FontWeight.w600,
            color: textColor ?? Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  static Widget deleteButton({
    required VoidCallback onPressed,
    String text = 'Delete',
    bool isEnabled = true,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
