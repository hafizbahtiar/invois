import 'package:flutter/material.dart';

enum MySnackbarType { success, warning, failed, info, normal }

class MySnackBar {
  /// Show a feature-rich, customizable snackbar.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    MySnackbarType type = MySnackbarType.normal,
    Color? messageColor,
    Color? backgroundColor,
    Color? iconColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.fixed,
    bool showCloseIcon = true,
    IconData? icon,
    double elevation = 8.0,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    bool dismissOnTap = false,
    bool showProgress = false,
    VoidCallback? onTap,
    VoidCallback? onDismissed,
  }) {
    final theme = Theme.of(context);
    final config = _getConfigForType(type, theme);

    final Color effectiveBackground = backgroundColor ?? config.backgroundColor;
    final Color effectiveMessageColor = messageColor ?? config.messageColor;
    final Color effectiveIconColor = iconColor ?? config.iconColor;
    final IconData effectiveIcon = icon ?? config.icon;

    // Only set margin if behavior is floating, otherwise pass null
    final EdgeInsetsGeometry? effectiveMargin =
        behavior == SnackBarBehavior.floating
        ? (margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12))
        : null;

    final snackBar = SnackBar(
      elevation: elevation,
      margin: effectiveMargin,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      backgroundColor: effectiveBackground,
      duration: duration,
      behavior: behavior,
      showCloseIcon: showCloseIcon,
      closeIconColor: effectiveMessageColor,
      action: action,
      onVisible: () {
        if (onTap != null) onTap();
      },
      content: InkWell(
        onTap: dismissOnTap
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (onTap != null) onTap();
              }
            : onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type != MySnackbarType.normal || icon != null) ...[
              Container(
                margin: const EdgeInsets.only(right: 12, top: 2),
                child: Icon(effectiveIcon, color: effectiveIconColor, size: 26),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null && title.trim().isNotEmpty)
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: effectiveMessageColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: effectiveMessageColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showProgress)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        backgroundColor: effectiveMessageColor.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          effectiveIconColor,
                        ),
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar).closed.then((_) {
      if (onDismissed != null) onDismissed();
    });
  }

  /// Configuration for each snackbar type
  static _SnackbarConfig _getConfigForType(
    MySnackbarType type,
    ThemeData theme,
  ) {
    switch (type) {
      case MySnackbarType.success:
        return _SnackbarConfig(
          backgroundColor: Colors.green[600]!,
          messageColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.check_circle_rounded,
        );
      case MySnackbarType.warning:
        return _SnackbarConfig(
          backgroundColor: Colors.orange[700]!,
          messageColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.warning_amber_rounded,
        );
      case MySnackbarType.failed:
        return _SnackbarConfig(
          backgroundColor: Colors.red[700]!,
          messageColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.error_outline_rounded,
        );
      case MySnackbarType.info:
        return _SnackbarConfig(
          backgroundColor: Colors.blue[700]!,
          messageColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.info_outline_rounded,
        );
      case MySnackbarType.normal:
        return _SnackbarConfig(
          backgroundColor: theme.colorScheme.surface,
          messageColor: theme.colorScheme.onSurfaceVariant,
          iconColor: theme.colorScheme.primary,
          icon: Icons.info_outline,
        );
    }
  }
}

class _SnackbarConfig {
  final Color backgroundColor;
  final Color messageColor;
  final Color iconColor;
  final IconData icon;

  const _SnackbarConfig({
    required this.backgroundColor,
    required this.messageColor,
    required this.iconColor,
    required this.icon,
  });
}
