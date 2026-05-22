/// Utility helpers for Pakistan CNIC (Computerised National Identity Card).
///
/// A valid CNIC consists of exactly 13 digits formatted as XXXXX-XXXXXXX-X.
/// This helper accepts raw digits (with or without separators/spaces) and
/// normalises them to the canonical dash-separated form before storage.
abstract final class CnicHelpers {
  /// Strips all non-digit characters from [input] and formats the resulting
  /// 13-digit string as `XXXXX-XXXXXXX-X`.
  ///
  /// Returns `null` if the input does not contain exactly 13 digits.
  static String? normalizeCnic(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return null;
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
  }

  /// Returns a localised error string if [input] is not a valid CNIC, or
  /// `null` if the input is valid (or blank — blank is allowed so the field
  /// only errors once the user has started typing).
  static String? errorText(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) {
      return 'Enter a valid 13-digit CNIC (e.g. 35202-1234567-1)';
    }
    return null;
  }
}
