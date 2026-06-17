enum FormType { add, edit, view, preCreate }

extension FormTypeExtension on FormType {
  /// Safely parse a route argument. Null, empty, or unrecognised values
  /// fall back to [FormType.add] instead of throwing —
  /// `Enum.values.byName('')` would crash the route generator.
  static FormType fromName(String? name) {
    if (name == null || name.isEmpty) return FormType.add;
    for (final value in FormType.values) {
      if (value.name == name) return value;
    }
    return FormType.add;
  }
}
