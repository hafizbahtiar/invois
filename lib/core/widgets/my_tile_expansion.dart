import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MyTileExpansion extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool isReadOnly;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? childrenPadding;
  final bool isRequired;
  final Duration animationDuration;

  const MyTileExpansion({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    required this.children,
    this.initiallyExpanded = false,
    this.isReadOnly = false,
    this.contentPadding,
    this.childrenPadding,
    this.isRequired = false,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<MyTileExpansion> createState() => _MyTileExpansionState();
}

class _MyTileExpansionState extends State<MyTileExpansion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: .3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isReadOnly ? null : _toggleExpanded,
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
                child: Padding(
                  padding:
                      widget.contentPadding ??
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      if (widget.leading != null || widget.icon != null) ...[
                        widget.leading ??
                            Icon(widget.icon, color: theme.colorScheme.primary)
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .fadeIn(duration: widget.animationDuration)
                                .then()
                                .shimmer(
                                  duration: const Duration(seconds: 2),
                                  delay: const Duration(seconds: 1),
                                ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                  widget.isRequired
                                      ? '${widget.title} *'
                                      : widget.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: widget.animationDuration)
                                .slide(
                                  begin: const Offset(-0.1, 0),
                                  end: Offset.zero,
                                  duration: widget.animationDuration,
                                  curve: Curves.easeOutQuad,
                                ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                    widget.subtitle!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(
                                      milliseconds:
                                          widget
                                              .animationDuration
                                              .inMilliseconds ~/
                                          2,
                                    ),
                                    duration: widget.animationDuration,
                                  )
                                  .slide(
                                    begin: const Offset(-0.05, 0),
                                    end: Offset.zero,
                                    duration: widget.animationDuration,
                                    curve: Curves.easeOutQuad,
                                  ),
                            ],
                          ],
                        ),
                      ),
                      if (!widget.isReadOnly)
                        Transform.rotate(
                              angle: _isExpanded ? 3.1416 : 0.0,
                              child: const Icon(Icons.keyboard_arrow_down),
                            )
                            .animate(target: _isExpanded ? 1 : 0)
                            .rotate(
                              begin: 0.0,
                              end: 3.1416,
                              duration: widget.animationDuration,
                              curve: Curves.easeInOut,
                            )
                            .scaleXY(
                              begin: 1.0,
                              end: 1.2,
                              duration: const Duration(milliseconds: 150),
                            )
                            .then()
                            .scaleXY(
                              begin: 1.2,
                              end: 1.0,
                              duration: const Duration(milliseconds: 150),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: widget.animationDuration,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _isExpanded
                  ? Container(
                          key: const ValueKey('expanded'),
                          padding:
                              widget.childrenPadding ??
                              const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.children,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: widget.animationDuration)
                        .slide(
                          begin: const Offset(0, -0.1),
                          end: Offset.zero,
                          duration: widget.animationDuration,
                          curve: Curves.easeOutQuad,
                        )
                  : const SizedBox(
                      key: ValueKey('collapsed'),
                      height: 0,
                      width: double.infinity,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
}
