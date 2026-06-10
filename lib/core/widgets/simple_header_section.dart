import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A versatile and rich simple header section widget with multiple variants
/// Supports different styles, animations, and customization options
class SimpleHeaderSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final SimpleHeaderVariant variant;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool animate;
  final Duration animationDuration;
  final Color? accentColor;
  final Color? backgroundColor;
  final double? height;
  final BorderRadius? borderRadius;
  final List<Widget>? actions;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final bool isReadOnly;

  const SimpleHeaderSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.variant = SimpleHeaderVariant.primary,
    this.margin,
    this.padding,
    this.onTap,
    this.showDivider = false,
    this.animate = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.accentColor,
    this.backgroundColor,
    this.height,
    this.borderRadius,
    this.actions,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccentColor = accentColor ?? theme.colorScheme.primary;
    final effectiveBackgroundColor = backgroundColor ?? Colors.transparent;

    Widget headerContent = _buildHeaderContent(
      context,
      theme,
      effectiveAccentColor,
    );

    if (animate) {
      headerContent = headerContent
          .animate()
          .fadeIn(duration: animationDuration, curve: Curves.easeInOut)
          .scale(duration: animationDuration, curve: Curves.easeInOut);
    }

    Widget header = Container(
      margin: margin ?? const EdgeInsets.only(top: 10, bottom: 1),
      padding: padding ?? const EdgeInsets.all(10),
      height: height,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: borderRadius,
        border: variant == SimpleHeaderVariant.outlined
            ? Border.all(color: effectiveAccentColor.withValues(alpha: 0.2))
            : null,
        boxShadow: variant == SimpleHeaderVariant.elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: headerContent,
    );

    if (onTap != null) {
      header = InkWell(onTap: onTap, borderRadius: borderRadius, child: header);
    }

    return Column(
      children: [
        header,
        if (showDivider)
          Divider(
            color: effectiveAccentColor.withValues(alpha: 0.1),
            height: 1,
            thickness: 1,
          ),
      ],
    );
  }

  Widget _buildHeaderContent(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    switch (variant) {
      case SimpleHeaderVariant.primary:
        return _buildPrimaryVariant(context, theme, effectiveAccentColor);
      case SimpleHeaderVariant.minimal:
        return _buildMinimalVariant(context, theme, effectiveAccentColor);
      case SimpleHeaderVariant.iconic:
        return _buildIconicVariant(context, theme, effectiveAccentColor);
      case SimpleHeaderVariant.outlined:
        return _buildOutlinedVariant(context, theme, effectiveAccentColor);
      case SimpleHeaderVariant.elevated:
        return _buildElevatedVariant(context, theme, effectiveAccentColor);
      case SimpleHeaderVariant.gradient:
        return _buildGradientVariant(context, theme, effectiveAccentColor);
    }
  }

  Widget _buildPrimaryVariant(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: effectiveAccentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions != null) ...[const SizedBox(width: 8), ...actions!],
      ],
    );
  }

  Widget _buildMinimalVariant(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions != null) ...[const SizedBox(width: 8), ...actions!],
      ],
    );
  }

  Widget _buildIconicVariant(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: effectiveAccentColor),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions != null) ...[const SizedBox(width: 8), ...actions!],
      ],
    );
  }

  Widget _buildOutlinedVariant(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: effectiveAccentColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: effectiveAccentColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (actions != null) ...[const SizedBox(width: 8), ...actions!],
      ],
    );
  }

  Widget _buildElevatedVariant(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: effectiveAccentColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: effectiveAccentColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon ?? Icons.star, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions != null) ...[const SizedBox(width: 8), ...actions!],
      ],
    );
  }

  Widget _buildGradientVariant(
    BuildContext context,
    ThemeData theme,
    Color effectiveAccentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            effectiveAccentColor.withValues(alpha: 0.1),
            effectiveAccentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: effectiveAccentColor),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[const SizedBox(width: 8), ...actions!],
        ],
      ),
    );
  }
}

/// Different variants for the SimpleHeaderSection
enum SimpleHeaderVariant {
  /// Primary variant with accent bar
  primary,

  /// Minimal variant with clean typography
  minimal,

  /// Iconic variant with icon
  iconic,

  /// Outlined variant with border
  outlined,

  /// Elevated variant with shadow
  elevated,

  /// Gradient variant with background gradient
  gradient,
}
