enum ListType { list, singlePicker, multiPicker }

extension ListTypeExtension on ListType {
  /// Safely parse a route argument. Null, empty, or unrecognised values
  /// fall back to [ListType.list] instead of throwing —
  /// `Enum.values.byName('')` would crash the route generator.
  static ListType fromName(String? name) {
    if (name == null || name.isEmpty) return ListType.list;
    for (final value in ListType.values) {
      if (value.name == name) return value;
    }
    return ListType.list;
  }
}
