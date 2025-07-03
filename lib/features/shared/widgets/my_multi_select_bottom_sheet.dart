import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'my_selector_field.dart';

class MyMultiSelectBottomSheet<T> extends StatefulWidget {
  final String title;
  final List<MultiSelectItem<T>> items;
  final List<T> initialSelectedValues;
  final Function(List<T>) onConfirm;
  final Widget? selectedItemsWidget;
  final bool searchable;
  final String? searchHint;
  final IconData? searchIcon;
  final IconData? confirmIcon;
  final String? confirmText;
  final String? cancelText;
  final ScrollController? scrollController;
  final bool showSelectedCount;
  final bool showChips;
  final bool enableSelectAll;
  final Map<String, List<MultiSelectItem<T>>>? groupedItems;
  final bool enableStickyGroups;
  final int? maxChips;

  const MyMultiSelectBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.initialSelectedValues,
    required this.onConfirm,
    this.selectedItemsWidget,
    this.searchable = true,
    this.searchHint,
    this.searchIcon = Icons.search,
    this.confirmIcon = Icons.check,
    this.confirmText,
    this.cancelText,
    this.scrollController,
    this.showSelectedCount = true,
    this.showChips = false,
    this.enableSelectAll = true,
    this.groupedItems,
    this.enableStickyGroups = true,
    this.maxChips,
  });

  static Future<List<T>?> show<T>({
    required BuildContext context,
    required String title,
    required List<MultiSelectItem<T>> items,
    required List<T> initialSelectedValues,
    Widget? selectedItemsWidget,
    bool searchable = true,
    String? searchHint,
    IconData searchIcon = Icons.search,
    IconData confirmIcon = Icons.check,
    String? confirmText,
    String? cancelText,
    ScrollController? scrollController,
    bool showSelectedCount = true,
    bool showChips = false,
    bool enableSelectAll = true,
    Map<String, List<MultiSelectItem<T>>>? groupedItems,
    bool enableStickyGroups = true,
    int? maxChips,
  }) async {
    return await showModalBottomSheet<List<T>>(
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
              child: MyMultiSelectBottomSheet<T>(
                title: title,
                items: items,
                initialSelectedValues: initialSelectedValues,
                onConfirm: (values) {
                  Navigator.pop(context, values);
                },
                selectedItemsWidget: selectedItemsWidget,
                searchable: searchable,
                searchHint: searchHint ?? 'Search',
                searchIcon: searchIcon,
                confirmIcon: confirmIcon,
                confirmText: confirmText ?? 'Apply',
                cancelText: cancelText ?? 'Cancel',
                scrollController: scrollController,
                showSelectedCount: showSelectedCount,
                showChips: showChips,
                enableSelectAll: enableSelectAll,
                groupedItems: groupedItems,
                enableStickyGroups: enableStickyGroups,
                maxChips: maxChips,
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<MyMultiSelectBottomSheet<T>> createState() =>
      _MyMultiSelectBottomSheetState<T>();
}

class _MyMultiSelectBottomSheetState<T>
    extends State<MyMultiSelectBottomSheet<T>>
    with SingleTickerProviderStateMixin {
  List<T> _selectedValues = [];
  List<MultiSelectItem<T>> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<MultiSelectItem<T>>>? _filteredGroupedItems;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _selectedValues = List.from(widget.initialSelectedValues);
    _filteredItems = widget.items;
    _filteredGroupedItems = widget.groupedItems;

    _searchController.addListener(() {
      _filterItems();
    });
  }

  void _filterItems() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _isSearchActive = searchQuery.isNotEmpty;

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

  void _toggleSelectAll(bool? selected) {
    if (selected == true) {
      setState(() {
        if (_isSearchActive) {
          // Only select filtered items
          for (var item in _filteredItems) {
            if (!_selectedValues.contains(item.value)) {
              _selectedValues.add(item.value);
            }
          }
        } else {
          // Select all items
          for (var item in widget.items) {
            if (!_selectedValues.contains(item.value)) {
              _selectedValues.add(item.value);
            }
          }
        }
      });
    } else {
      setState(() {
        if (_isSearchActive) {
          // Only deselect filtered items
          _selectedValues.removeWhere(
            (value) => _filteredItems.any((item) => item.value == value),
          );
        } else {
          _selectedValues.clear();
        }
      });
    }
  }

  bool get _allFilteredItemsSelected {
    if (_filteredItems.isEmpty) return false;
    return _filteredItems.every((item) => _selectedValues.contains(item.value));
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
              if (widget.showSelectedCount && _selectedValues.isNotEmpty)
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
                    '${_selectedValues.length}',
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
        // Select All option
        if (widget.enableSelectAll && _filteredItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
            child: Row(
              children: [
                Checkbox(
                  value: _allFilteredItemsSelected,
                  onChanged: _toggleSelectAll,
                  activeColor: theme.colorScheme.primary,
                  checkColor: theme.colorScheme.onPrimary,
                ),
                Text(
                  _allFilteredItemsSelected ? 'Deselect All' : 'Select All',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        // Selected items chips
        if (widget.showChips && _selectedValues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildSelectedChips(),
          ),
        // Selected items display
        if (widget.selectedItemsWidget != null) widget.selectedItemsWidget!,
        // Items list
        Expanded(
          child:
              _filteredItems.isEmpty &&
                  (_filteredGroupedItems == null ||
                      _filteredGroupedItems!.isEmpty)
              ? _buildEmptyState()
              : _buildItemsList(),
        ),
        // Confirm button
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: FilledButton.icon(
            onPressed: () => widget.onConfirm(_selectedValues),
            icon: Icon(widget.confirmIcon),
            label: Text(widget.confirmText ?? 'Apply'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedChips() {
    final theme = Theme.of(context);
    final maxChips = widget.maxChips ?? 5;

    // Find the label for each selected value
    final selectedItems = widget.items
        .where((item) => _selectedValues.contains(item.value))
        .toList();

    if (selectedItems.isEmpty) return const SizedBox.shrink();

    final displayedItems = selectedItems.length > maxChips
        ? selectedItems.sublist(0, maxChips)
        : selectedItems;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...displayedItems.map(
          (item) => Chip(
            label: Text(item.label),
            avatar: item.icon != null ? CircleAvatar(child: item.icon) : null,
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                _selectedValues.removeWhere((val) => val == item.value);
              });
            },
            backgroundColor: theme.colorScheme.secondaryContainer,
            labelStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
            deleteIconColor: theme.colorScheme.onSecondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
        if (selectedItems.length > maxChips)
          Chip(
            label: Text('+${selectedItems.length - maxChips}'),
            backgroundColor: theme.colorScheme.tertiaryContainer,
            labelStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
      ],
    );
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

  Widget _buildItemTile(MultiSelectItem<T> item) {
    final theme = Theme.of(context);
    final isSelected = _selectedValues.contains(item.value);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (selected) {
          setState(() {
            if (selected == true) {
              if (!_selectedValues.contains(item.value)) {
                _selectedValues.add(item.value);
              }
            } else {
              _selectedValues.removeWhere((val) => val == item.value);
            }
          });
        },
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
        secondary: item.icon != null
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
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: theme.colorScheme.primary,
        checkColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
