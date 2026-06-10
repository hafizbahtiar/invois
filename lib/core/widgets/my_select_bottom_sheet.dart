import 'package:flutter/material.dart';
import 'package:invois/core/widgets/my_selector_field.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MySelectBottomSheet<T> extends StatefulWidget {
  final String title;
  final List<SelectItem<T>> items;
  final T? initialSelectedValue;
  final Function(T) onConfirm;
  final Widget? selectedItemWidget;
  final bool searchable;
  final String? searchHint;
  final IconData? searchIcon;
  final IconData? confirmIcon;
  final String? confirmText;
  final String? cancelText;
  final ScrollController? scrollController;
  final bool showSelectedItem;
  final Map<String, List<SelectItem<T>>>? groupedItems;
  final bool enableStickyGroups;
  final bool closeOnSelect;

  const MySelectBottomSheet({
    super.key,
    required this.title,
    required this.items,
    this.initialSelectedValue,
    required this.onConfirm,
    this.selectedItemWidget,
    this.searchable = true,
    this.searchHint,
    this.searchIcon = Icons.search,
    this.confirmIcon = Icons.check,
    this.confirmText,
    this.cancelText,
    this.scrollController,
    this.showSelectedItem = false,
    this.groupedItems,
    this.enableStickyGroups = true,
    this.closeOnSelect = true,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<SelectItem<T>> items,
    T? initialSelectedValue,
    Widget? selectedItemWidget,
    bool searchable = true,
    String? searchHint,
    IconData searchIcon = Icons.search,
    IconData confirmIcon = Icons.check,
    String? confirmText,
    String? cancelText,
    ScrollController? scrollController,
    bool showSelectedItem = false,
    Map<String, List<SelectItem<T>>>? groupedItems,
    bool enableStickyGroups = true,
    bool closeOnSelect = true,
  }) async {
    return await showModalBottomSheet<T>(
      context: context,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: MySelectBottomSheet<T>(
                title: title,
                items: items,
                initialSelectedValue: initialSelectedValue,
                onConfirm: (value) {
                  Navigator.pop(context, value);
                },
                selectedItemWidget: selectedItemWidget,
                searchable: searchable,
                searchHint: searchHint ?? 'Search',
                searchIcon: searchIcon,
                confirmIcon: confirmIcon,
                confirmText: confirmText ?? 'Apply',
                cancelText: cancelText ?? 'Cancel',
                scrollController: scrollController,
                showSelectedItem: showSelectedItem,
                groupedItems: groupedItems,
                enableStickyGroups: enableStickyGroups,
                closeOnSelect: closeOnSelect,
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<MySelectBottomSheet<T>> createState() => _MySelectBottomSheetState<T>();
}

class _MySelectBottomSheetState<T> extends State<MySelectBottomSheet<T>>
    with SingleTickerProviderStateMixin {
  T? _selectedValue;
  List<SelectItem<T>> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<SelectItem<T>>>? _filteredGroupedItems;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialSelectedValue;
    _filteredItems = widget.items;
    _filteredGroupedItems = widget.groupedItems;

    _searchController.addListener(() {
      _filterItems();
    });
  }

  void _filterItems() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      if (searchQuery.isEmpty) {
        _filteredItems = widget.items;
        _filteredGroupedItems = widget.groupedItems;
      } else {
        _filteredItems = widget.items
            .where((item) => item.label.toLowerCase().contains(searchQuery))
            .toList();

        if (widget.groupedItems != null) {
          _filteredGroupedItems = {};
          widget.groupedItems!.forEach((key, items) {
            final filteredGroupItems = items
                .where((item) => item.label.toLowerCase().contains(searchQuery))
                .toList();
            if (filteredGroupItems.isNotEmpty) {
              _filteredGroupedItems![key] = filteredGroupItems;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title and actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showSelectedItem && _selectedValue != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getSelectedItemLabel() ?? '',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.cancelText ?? 'Cancel'),
              ),
            ],
          ),
        ),
        // Search field
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint ?? 'Search',
                prefixIcon: Icon(widget.searchIcon),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        // Selected item display
        if (widget.selectedItemWidget != null) widget.selectedItemWidget!,
        // Items list
        Expanded(
          child:
              _filteredItems.isEmpty &&
                  (_filteredGroupedItems == null ||
                      _filteredGroupedItems!.isEmpty)
              ? _buildEmptyState()
              : _buildItemsList(),
        ),
      ],
    );
  }

  String? _getSelectedItemLabel() {
    if (_selectedValue == null) return null;

    final selectedItem = widget.items.firstWhere(
      (item) => item.value == _selectedValue,
      orElse: () => SelectItem<T>(value: _selectedValue as T, label: ''),
    );

    return selectedItem.label;
  }

  Widget _buildItemsList() {
    // If we have grouped items, build a grouped list
    if (widget.groupedItems != null &&
        _filteredGroupedItems != null &&
        _filteredGroupedItems!.isNotEmpty) {
      return _buildGroupedList();
    }

    // Otherwise build a flat list
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildItemTile(_filteredItems[index]);
      },
    );
  }

  Widget _buildGroupedList() {
    final theme = Theme.of(context);

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredGroupedItems!.length,
      itemBuilder: (context, groupIndex) {
        final groupName = _filteredGroupedItems!.keys.elementAt(groupIndex);
        final groupItems = _filteredGroupedItems![groupName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupIndex > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Text(
                groupName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...groupItems.map((item) => _buildItemTile(item)),
          ],
        );
      },
    );
  }

  Widget _buildItemTile(SelectItem<T> item) {
    final theme = Theme.of(context);
    final isSelected = _selectedValue == item.value;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedValue = item.value;
          });

          // Auto-close if enabled
          if (widget.closeOnSelect) {
            Navigator.pop(context, item.value);
          }
        },
        leading: item.icon != null
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.icon,
              )
            : null,
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
        trailing: isSelected
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeInOut);
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No feature found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchController.text.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.clear),
              label: Text('Clear search'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
