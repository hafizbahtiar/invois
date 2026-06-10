import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A feature-rich, user-friendly, and highly customizable list widget.
/// Supports loading, empty, error, and no-connection states, pull-to-refresh,
/// skeleton loading, and custom item rendering.
class MyList<T> extends StatelessWidget {
  final List<T> items;
  final bool isLoading;
  final bool isRefreshing;
  final bool isNoConnection;
  final String? emptyMessage;
  final String? errorMessage;
  final Widget Function(T item, int index) itemBuilder;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onRetry;
  final ScrollController? controller;
  final bool usePadding;
  final bool useSkeleton;
  final int skeletonCount;
  final Widget? emptyIcon;
  final Widget? errorIcon;
  final Widget? noConnectionIcon;
  final EdgeInsetsGeometry? padding;
  final Widget? header;
  final Widget? footer;

  const MyList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isNoConnection = false,
    this.emptyMessage,
    this.errorMessage,
    this.onRefresh,
    this.onRetry,
    this.controller,
    this.usePadding = true,
    this.useSkeleton = false,
    this.skeletonCount = 7,
    this.emptyIcon,
    this.errorIcon,
    this.noConnectionIcon,
    this.padding,
    this.header,
    this.footer,
  });

  int _getItemCount() {
    if (isLoading && useSkeleton) return skeletonCount;
    if (!isLoading && items.isEmpty) return 1;
    return items.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    Widget buildStateWidget({
      required Widget icon,
      required String message,
      Widget? action,
    }) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              minHeight: mq.size.height * 0.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 28), action],
              ],
            ),
          ),
        ),
      );
    }

    if (isLoading && !useSkeleton) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (!isLoading && isNoConnection) {
      return buildStateWidget(
        icon:
            noConnectionIcon ??
            Icon(Icons.wifi_off, size: 64, color: theme.colorScheme.outline),
        message: errorMessage ?? "No connection. Please check your internet.",
        action: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text("Retry"),
          onPressed: onRetry ?? onRefresh,
        ),
      );
    }

    if (!isLoading && items.isEmpty) {
      return buildStateWidget(
        icon:
            emptyIcon ??
            Icon(Icons.inbox, size: 64, color: theme.colorScheme.outline),
        message: emptyMessage ?? "No data found.",
        action: onRefresh != null
            ? ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh"),
                onPressed: onRefresh,
              )
            : null,
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
        controller: controller,
        padding: padding ?? const EdgeInsets.all(16),
        itemCount:
            _getItemCount() +
            (header != null ? 1 : 0) +
            (footer != null ? 1 : 0),
        itemBuilder: (context, index) {
          int realIndex = index;
          if (header != null && index == 0) {
            return header!;
          }
          if (header != null) realIndex--;

          if (footer != null &&
              index == _getItemCount() + (header != null ? 1 : 0)) {
            return footer!;
          }

          if (isLoading && useSkeleton) {
            return Skeletonizer(
              enabled: true,
              effect: ShimmerEffect(
                duration: const Duration(milliseconds: 900),
                baseColor: theme.colorScheme.surface,
                highlightColor: theme.colorScheme.secondary.withValues(
                  alpha: 0.2,
                ),
              ),
              ignoreContainers: true,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: const CircleAvatar(),
                  title: Container(height: 18, width: 120, color: Colors.white),
                  subtitle: Container(
                    height: 14,
                    width: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }

          // Show actual item
          final T item = items[realIndex];
          return itemBuilder(item, realIndex);
        },
      ),
    );
  }
}
