import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom tile widget with enhanced UI/UX and splash effects
class MyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Widget? trailing;
  final bool showChevron;
  final bool isRounded;
  final bool isFirst;
  final bool isLast;
  final Widget? leading;
  final bool isReadOnly;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? selectionIndicator;

  /// When true, shows a checkbox for selection instead of using selectionIndicator
  final bool isSelectable;

  const MyTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onLongPress,
    this.color,
    this.trailing,
    this.showChevron = true,
    this.isRounded = false,
    this.isFirst = false,
    this.isLast = false,
    this.leading,
    this.isReadOnly = false,
    this.selected = false,
    this.onSelected,
    this.selectionIndicator,
    this.isSelectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    void handleTap() {
      if (isSelectable && onSelected != null && !isReadOnly) {
        onSelected!(!selected);
      } else if (selectionIndicator != null &&
          onSelected != null &&
          !isReadOnly) {
        onSelected!(!selected);
      } else if (onTap != null && !isReadOnly) {
        HapticFeedback.lightImpact();
        onTap?.call();
      }
    }

    void handleLongPress() {
      if (onLongPress != null && !isReadOnly) {
        HapticFeedback.heavyImpact();
        onLongPress?.call();
      }
    }

    // Build the leading widget with selection indicator if needed
    Widget buildLeading() {
      Widget leadingWidget;

      if (leading != null) {
        leadingWidget = leading!;
      } else {
        leadingWidget = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: effectiveColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: effectiveColor, size: 22),
        );
      }

      if (selectionIndicator != null && !isSelectable) {
        return Stack(
          children: [
            leadingWidget,
            Positioned(left: -4, top: -4, child: selectionIndicator!),
          ],
        );
      }

      return leadingWidget;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst || isRounded ? const Radius.circular(16) : Radius.zero,
          bottom: isLast || isRounded ? const Radius.circular(16) : Radius.zero,
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              (!isReadOnly &&
                  (isSelectable && onSelected != null ||
                      selectionIndicator != null && onSelected != null ||
                      onTap != null))
              ? handleTap
              : null,
          onLongPress: (onLongPress != null && !isReadOnly)
              ? handleLongPress
              : null,
          splashColor: effectiveColor.withAlpha(30),
          highlightColor: effectiveColor.withAlpha(15),
          borderRadius: BorderRadius.vertical(
            top: isFirst || isRounded ? const Radius.circular(16) : Radius.zero,
            bottom: isLast || isRounded
                ? const Radius.circular(16)
                : Radius.zero,
          ),
          child: Opacity(
            opacity: isReadOnly ? 0.7 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (isSelectable) ...[
                    Checkbox(
                      value: selected,
                      onChanged: isReadOnly
                          ? null
                          : (value) => onSelected?.call(value ?? false),
                      activeColor: effectiveColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isSelectable) ...[
                    buildLeading(),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 8),
                  ],
                  if (showChevron &&
                      onTap != null &&
                      !isReadOnly &&
                      !isSelectable)
                    Icon(
                      Icons.arrow_forward_ios,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
