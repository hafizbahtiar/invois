import 'package:flutter/material.dart';

/// A reusable widget for displaying section headers with icon, title, and subtitle
class FormSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final EdgeInsetsGeometry? margin;
  final Color? iconBackgroundColor;
  final Color? iconColor;
  final Color? titleColor;
  final Color? subtitleColor;
  final bool isReadOnly;

  const FormSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.margin,
    this.iconBackgroundColor,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 20, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isReadOnly
                        ? theme.disabledColor
                        : titleColor ?? theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isReadOnly
                          ? theme.disabledColor
                          : subtitleColor ?? theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
