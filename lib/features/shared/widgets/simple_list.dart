import 'package:flutter/material.dart';
import 'package:invois/features/shared/widgets/my_empty_state.dart';

/// A simple, reusable, and composable list widget for most use cases.
///
/// Features:
/// - Generic item type
/// - Custom itemBuilder
/// - Optional separator
/// - Header/footer widgets
/// - Empty/loading/error states
/// - Pull-to-refresh
/// - Scroll controller
/// - Custom padding
/// - Optional skeleton loading (pass skeletonBuilder)
/// - Clean, idiomatic Flutter API
class SimpleList<T> extends StatelessWidget {
  /// The list of items to display.
  final List<T> items;

  /// Called to build each item in the list.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Optional separator builder between items.
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// Widget to show above the list (not scrolled).
  final Widget? header;

  /// Widget to show below the list (not scrolled).
  final Widget? footer;

  /// Whether the list is currently loading.
  final bool isLoading;

  /// Whether the list is currently refreshing.
  final bool isRefreshing;

  /// Error message to display, if any.
  final String? errorMessage;

  /// Message to display if the list is empty.
  final String? emptyMessage;

  /// Widget to show for empty state (overrides [emptyMessage]).
  final Widget? emptyWidget;

  /// Widget to show for error state (overrides [errorMessage]).
  final Widget? errorWidget;

  /// Called when pull-to-refresh is triggered.
  final Future<void> Function()? onRefresh;

  /// Scroll controller for the list.
  final ScrollController? controller;

  /// Padding for the list.
  final EdgeInsetsGeometry? padding;

  /// If true, show skeletons when loading (use [skeletonBuilder]).
  final bool useSkeleton;

  /// Number of skeleton items to show when loading.
  final int skeletonCount;

  /// Builder for skeleton item (if [useSkeleton] is true).
  final Widget Function(BuildContext context, int index)? skeletonBuilder;

  /// Creates a [SimpleList].
  const SimpleList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.separatorBuilder,
    this.header,
    this.footer,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.emptyMessage,
    this.emptyWidget,
    this.errorWidget,
    this.onRefresh,
    this.controller,
    this.padding,
    this.useSkeleton = false,
    this.skeletonCount = 7,
    this.skeletonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildStateWidget({required Widget child}) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: child,
          ),
        ),
      );
    }

    Widget buildRefreshableStateWidget({required Widget child}) {
      final stateWidget = buildStateWidget(child: child);
      if (onRefresh == null) return stateWidget;

      return RefreshIndicator.adaptive(
        onRefresh: onRefresh!,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;

            return ListView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [SizedBox(height: viewportHeight, child: stateWidget)],
            );
          },
        ),
      );
    }

    if (isLoading && useSkeleton && skeletonBuilder != null) {
      return ListView.builder(
        controller: controller,
        padding: padding ?? const EdgeInsets.all(16),
        itemCount:
            skeletonCount + (header != null ? 1 : 0) + (footer != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header!;
          if (header != null) index--;
          if (footer != null &&
              index == skeletonCount + (header != null ? 1 : 0)) {
            return footer!;
          }
          return skeletonBuilder!(context, index);
        },
      );
    }

    if (isLoading && !useSkeleton) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return buildStateWidget(
        child:
            errorWidget ??
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onRefresh != null) ...[
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                    onPressed: onRefresh,
                  ),
                ],
              ],
            ),
      );
    }

    if (items.isEmpty) {
      return buildRefreshableStateWidget(
        child:
            emptyWidget ??
            MyEmptyState(
              icon: Icons.inbox,
              title: 'No data found.',
              description: 'No data found.',
            ),
      );
    }

    Widget listView = separatorBuilder != null
        ? ListView.separated(
            controller: controller,
            physics: onRefresh != null
                ? const AlwaysScrollableScrollPhysics()
                : null,
            padding: padding ?? const EdgeInsets.all(16),
            itemCount:
                items.length +
                (header != null ? 1 : 0) +
                (footer != null ? 1 : 0),
            separatorBuilder: (context, index) {
              // Only separate between items, not before header or after footer
              if (header != null && index == 0) return const SizedBox.shrink();
              if (footer != null &&
                  index == items.length - 1 + (header != null ? 1 : 0)) {
                return const SizedBox.shrink();
              }
              return separatorBuilder!(context, index);
            },
            itemBuilder: (context, index) {
              if (header != null && index == 0) return header!;
              if (header != null) index--;
              if (footer != null &&
                  index == items.length + (header != null ? 1 : 0)) {
                return footer!;
              }
              return itemBuilder(context, items[index], index);
            },
          )
        : ListView.builder(
            controller: controller,
            physics: onRefresh != null
                ? const AlwaysScrollableScrollPhysics()
                : null,
            padding: padding ?? const EdgeInsets.all(16),
            itemCount:
                items.length +
                (header != null ? 1 : 0) +
                (footer != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (header != null && index == 0) return header!;
              if (header != null) index--;
              if (footer != null &&
                  index == items.length + (header != null ? 1 : 0)) {
                return footer!;
              }
              return itemBuilder(context, items[index], index);
            },
          );

    if (onRefresh != null) {
      return RefreshIndicator.adaptive(onRefresh: onRefresh!, child: listView);
    }
    return listView;
  }
}
