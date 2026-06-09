import 'package:flutter/material.dart';

/// A single, content-responsive bottom sheet used across the app.
///
/// Height behaviour (see [AppBottomSheet]):
/// - Short content takes only the height it needs (no forced half/full screen).
/// - Long content is capped at ~95% of the screen height and scrolls inside.
/// - The footer stays pinned and visible while the body scrolls.
///
/// Use the [AppDynamicBottomSheet] entry points rather than constructing
/// [AppBottomSheet] directly:
///
/// - [AppDynamicBottomSheet.show] — a selectable list.
/// - [AppDynamicBottomSheet.showRadio] — a single-choice radio list.
/// - [AppDynamicBottomSheet.showInfo] — a title/description confirmation sheet.
/// - [AppDynamicBottomSheet.showCustom] — arbitrary content with optional actions.

/// A footer / confirmation button description.
class AppBottomSheetAction {
  final String label;
  final VoidCallback? onPressed;

  /// Renders as the filled, emphasised button. Secondary actions render outlined.
  final bool isPrimary;

  /// Renders with the theme error color (filled when primary, text when not).
  final bool isDestructive;
  final IconData? icon;
  final bool enabled;

  const AppBottomSheetAction({
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isDestructive = false,
    this.icon,
    this.enabled = true,
  });
}

/// The reusable layout shell. Owns the sheet chrome (handle, header, search
/// slot, scrollable body, pinned footer) and the responsive-height recipe.
class AppBottomSheet extends StatelessWidget {
  final String? title;

  /// Replaces the default title row entirely when provided.
  final Widget? header;
  final bool showCloseButton;

  /// Optional pinned widget (typically a search field) shown below the header
  /// and above the scrollable body.
  final Widget? pinned;

  /// The scrollable / sized content. Placed inside a loose [Flexible] so it
  /// wraps short content and scrolls when it would exceed [maxHeightFactor].
  final Widget body;
  final List<AppBottomSheetAction> actions;
  final bool showDragHandle;

  /// Fraction of the screen height the sheet may grow to. Defaults to 0.95 so
  /// it still reads as a bottom sheet, not a full-screen page.
  final double maxHeightFactor;

  const AppBottomSheet({
    super.key,
    this.title,
    this.header,
    this.showCloseButton = false,
    this.pinned,
    required this.body,
    this.actions = const [],
    this.showDragHandle = true,
    this.maxHeightFactor = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * maxHeightFactor;

    return Padding(
      // Lift the whole sheet above the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle) const _DragHandle(),
                if (header != null)
                  header!
                else if (title != null || showCloseButton)
                  _Header(title: title, showCloseButton: showCloseButton),
                ?pinned,
                // Loose Flexible = wraps short content, caps + scrolls long content.
                Flexible(child: body),
                if (actions.isNotEmpty) _Footer(actions: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? title;
  final bool showCloseButton;

  const _Header({this.title, this.showCloseButton = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                title ?? '',
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final List<AppBottomSheetAction> actions;

  const _Footer({required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _ActionButton(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AppBottomSheetAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPressed = action.enabled ? action.onPressed : null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const padding = EdgeInsets.symmetric(vertical: 16);
    final label = action.icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 18),
              const SizedBox(width: 8),
              Text(action.label),
            ],
          )
        : Text(action.label);

    if (action.isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: padding,
          shape: shape,
          backgroundColor: action.isDestructive ? theme.colorScheme.error : null,
          foregroundColor: action.isDestructive
              ? theme.colorScheme.onError
              : null,
        ),
        child: label,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: padding,
        shape: shape,
        foregroundColor: action.isDestructive ? theme.colorScheme.error : null,
      ),
      child: label,
    );
  }
}

/// Dynamic bottom sheet entry points. Pick the variant that matches the content;
/// all share the same responsive [AppBottomSheet] shell.
abstract final class AppDynamicBottomSheet {
  /// Opens the [AppBottomSheet] shell as a modal. Internal helper shared by
  /// every public variant.
  static Future<T?> _open<T>({
    required BuildContext context,
    required Widget sheet,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  /// A selectable list. Returns the chosen item (callers usually pop in
  /// [onItemSelected]).
  ///
  /// ```dart
  /// await AppDynamicBottomSheet.show<Customer>(
  ///   context: context,
  ///   title: 'Select Customer',
  ///   items: customers,
  ///   itemBuilder: (context, customer, selected) => Text(customer.name),
  ///   onItemSelected: (customer) => Navigator.pop(context, customer),
  /// );
  /// ```
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required List<T> items,
    required Widget Function(BuildContext context, T item, bool selected)
    itemBuilder,
    required ValueChanged<T> onItemSelected,
    T? selectedValue,
    bool searchable = false,
    String Function(T item)? searchText,
    String? searchHint,
    bool Function(T item)? isDisabled,
    bool isLoading = false,
    Object? error,
    Widget? emptyPlaceholder,
    bool showCloseButton = false,
    List<AppBottomSheetAction> actions = const [],
  }) {
    return _open<T>(
      context: context,
      sheet: _ListBottomSheet<T>(
        title: title,
        items: items,
        itemBuilder: itemBuilder,
        onItemSelected: onItemSelected,
        selectedValue: selectedValue,
        searchable: searchable,
        searchText: searchText,
        searchHint: searchHint,
        isDisabled: isDisabled,
        isLoading: isLoading,
        error: error,
        emptyPlaceholder: emptyPlaceholder,
        showCloseButton: showCloseButton,
        actions: actions,
      ),
    );
  }

  /// A single-choice radio list.
  ///
  /// ```dart
  /// await AppDynamicBottomSheet.showRadio<InvoiceStatus>(
  ///   context: context,
  ///   title: 'Invoice Status',
  ///   value: currentStatus,
  ///   items: InvoiceStatus.values,
  ///   labelBuilder: (status) => status.label,
  ///   onChanged: (status) => Navigator.pop(context, status),
  /// );
  /// ```
  static Future<T?> showRadio<T>({
    required BuildContext context,
    String? title,
    required List<T> items,
    required T? value,
    required String Function(T item) labelBuilder,
    String Function(T item)? subtitleBuilder,
    ValueChanged<T>? onChanged,
    bool Function(T item)? isDisabled,
    bool searchable = false,
    String? searchHint,
    bool showCloseButton = false,
  }) {
    return _open<T>(
      context: context,
      sheet: _ListBottomSheet<T>(
        title: title,
        items: items,
        selectedValue: value,
        searchable: searchable,
        searchText: searchable ? labelBuilder : null,
        searchHint: searchHint,
        isDisabled: isDisabled,
        showCloseButton: showCloseButton,
        onItemSelected: (item) => onChanged?.call(item),
        itemBuilder: (context, item, selected) => _RadioRow(
          label: labelBuilder(item),
          subtitle: subtitleBuilder?.call(item),
          selected: selected,
        ),
      ),
    );
  }

  /// A title/description confirmation sheet with up to two actions.
  ///
  /// ```dart
  /// await AppDynamicBottomSheet.showInfo(
  ///   context: context,
  ///   title: 'Delete Invoice?',
  ///   description: 'This action cannot be undone.',
  ///   primaryAction: AppBottomSheetAction(
  ///     label: 'Delete', isDestructive: true, onPressed: () {},
  ///   ),
  ///   secondaryAction: AppBottomSheetAction(
  ///     label: 'Cancel', onPressed: () => Navigator.pop(context),
  ///   ),
  /// );
  /// ```
  static Future<T?> showInfo<T>({
    required BuildContext context,
    required String title,
    String? description,
    Widget? content,
    IconData? icon,
    AppBottomSheetAction? primaryAction,
    AppBottomSheetAction? secondaryAction,
  }) {
    return _open<T>(
      context: context,
      sheet: AppBottomSheet(
        title: title,
        // Secondary on the left, primary (emphasised) on the right.
        actions: [
          ?secondaryAction,
          ?primaryAction,
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
              ],
              if (description != null)
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ?content,
            ],
          ),
        ),
      ),
    );
  }

  /// Arbitrary content with optional footer actions.
  ///
  /// ```dart
  /// await AppDynamicBottomSheet.showCustom(
  ///   context: context,
  ///   title: 'Invoice Options',
  ///   child: Column(mainAxisSize: MainAxisSize.min, children: [...]),
  ///   actions: [...],
  /// );
  /// ```
  static Future<T?> showCustom<T>({
    required BuildContext context,
    String? title,
    required Widget child,
    List<AppBottomSheetAction> actions = const [],
    bool showCloseButton = false,
    EdgeInsets contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  }) {
    return _open<T>(
      context: context,
      sheet: AppBottomSheet(
        title: title,
        showCloseButton: showCloseButton,
        actions: actions,
        body: SingleChildScrollView(
          padding: contentPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Stateful body shared by [AppDynamicBottomSheet.show] and `showRadio`.
/// Handles search filtering and the loading / empty / error states.
class _ListBottomSheet<T> extends StatefulWidget {
  final String? title;
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool selected) itemBuilder;
  final ValueChanged<T> onItemSelected;
  final T? selectedValue;
  final bool searchable;
  final String Function(T item)? searchText;
  final String? searchHint;
  final bool Function(T item)? isDisabled;
  final bool isLoading;
  final Object? error;
  final Widget? emptyPlaceholder;
  final bool showCloseButton;
  final List<AppBottomSheetAction> actions;

  const _ListBottomSheet({
    super.key,
    this.title,
    required this.items,
    required this.itemBuilder,
    required this.onItemSelected,
    this.selectedValue,
    this.searchable = false,
    this.searchText,
    this.searchHint,
    this.isDisabled,
    this.isLoading = false,
    this.error,
    this.emptyPlaceholder,
    this.showCloseButton = false,
    this.actions = const [],
  });

  @override
  State<_ListBottomSheet<T>> createState() => _ListBottomSheetState<T>();
}

class _ListBottomSheetState<T> extends State<_ListBottomSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  late List<T> _filtered = widget.items;
  T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedValue;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
                .where(
                  (item) =>
                      (widget.searchText?.call(item) ?? '')
                          .toLowerCase()
                          .contains(q),
                )
                .toList();
    });
  }

  void _handleTap(T item) {
    setState(() => _selected = item);
    widget.onItemSelected(item);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: widget.title,
      showCloseButton: widget.showCloseButton,
      actions: widget.actions,
      pinned: widget.searchable ? _buildSearchField(context) : null,
      body: _buildBody(context),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: widget.searchHint ?? 'Search',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.isLoading) {
      return const _StatePlaceholder(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.error != null) {
      return _StatePlaceholder(
        child: _MessageState(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: widget.error.toString(),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return _StatePlaceholder(
        child: widget.emptyPlaceholder ??
            const _MessageState(
              icon: Icons.search_off,
              title: 'No results',
              message: 'Try adjusting your search.',
            ),
      );
    }

    return ListView.builder(
      // shrinkWrap lets the list size to its content; the parent Flexible caps
      // it at the sheet's max height, at which point it scrolls.
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final item = _filtered[index];
        final selected = item == _selected;
        final disabled = widget.isDisabled?.call(item) ?? false;
        final theme = Theme.of(context);

        return Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: disabled ? null : () => _handleTap(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: widget.itemBuilder(context, item, selected),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Centers a fixed-size state widget and gives the sheet a sensible minimum
/// height so loading/empty/error don't render as a thin strip.
class _StatePlaceholder extends StatelessWidget {
  final Widget child;

  const _StatePlaceholder({required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 160),
      child: Center(child: child),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Default row used by [AppDynamicBottomSheet.showRadio].
class _RadioRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;

  const _RadioRow({required this.label, this.subtitle, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
