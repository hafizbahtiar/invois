import 'package:flutter/material.dart';

/// A draggable bottom sheet with a customizable list of items.
///
/// This widget creates a modal bottom sheet with a draggable scrollable content
/// that can be resized by the user through dragging.
class SimpleDragList extends StatelessWidget {
  /// The list of widgets to display in the sheet.
  final List<Widget> items;

  /// Builder function to create a separator between items.
  final Widget Function(BuildContext, int)? separatorBuilder;

  /// Initial size of the sheet as a fraction of the screen height.
  final double initialChildSize;

  /// Minimum size of the sheet as a fraction of the screen height.
  final double minChildSize;

  /// Maximum size of the sheet as a fraction of the screen height.
  final double maxChildSize;

  /// Optional title to display at the top of the sheet.
  final Widget? title;

  /// Whether to show the drag handle at the top of the sheet.
  final bool showDragHandle;

  /// Creates a [SimpleDragList].
  const SimpleDragList({
    super.key,
    required this.items,
    this.separatorBuilder,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.9,
    this.title,
    this.showDragHandle = true,
  });

  /// Shows the simple drag list as a modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required List<Widget> items,
    Widget Function(BuildContext, int)? separatorBuilder,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.9,
    Widget? title,
    bool showDragHandle = true,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            borderRadius ??
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SimpleDragList(
        items: items,
        separatorBuilder: separatorBuilder,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        title: title,
        showDragHandle: showDragHandle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (title != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: title!,
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: separatorBuilder != null
                    ? ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        separatorBuilder: separatorBuilder!,
                        itemBuilder: (context, index) => items[index],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        itemBuilder: (context, index) => items[index],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Extension to provide a default separator for the [SimpleDragList].
extension SimpleDragListExtensions on SimpleDragList {
  /// Creates a [SimpleDragList] with a default line separator.
  static Widget Function(BuildContext, int) defaultSeparator(
    BuildContext context,
  ) {
    return (_, __) => Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}
