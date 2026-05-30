class ImeiHelpers {
  const ImeiHelpers._();

  /// Normalizes shop-label IMEI text into the actual IMEI value.
  ///
  /// Some phone labels print values such as `865551059502427 / 69`; the suffix
  /// after `/` is not part of the IMEI and should not be stored or validated.
  static String normalize(String input) {
    final trimmed = input.trim();
    final slashIndex = trimmed.indexOf('/');
    if (slashIndex < 0) {
      return trimmed;
    }
    return trimmed.substring(0, slashIndex).trim();
  }

  static String? normalizeNullable(String? input) {
    final normalized = normalize(input ?? '');
    return normalized.isEmpty ? null : normalized;
  }
}
