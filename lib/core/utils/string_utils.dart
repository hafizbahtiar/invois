/// String helpers for normalizing form input before persistence.
class StringUtils {
  StringUtils._();

  /// Returns `null` when [value] is `null` or contains only whitespace,
  /// otherwise returns the trimmed value.
  ///
  /// Used to normalize optional, `@Unique()` fields (e.g. email/phone) so that
  /// multiple records with a blank value are stored as `null` instead of `''`
  /// and do not collide on the unique index.
  static String? nullIfBlank(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
