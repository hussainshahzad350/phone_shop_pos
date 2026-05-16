class NotesSafety {
  const NotesSafety._();

  static const int maxLength = 240;

  static String? normalizeNullable(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? validate(String? raw, {String fieldLabel = 'Notes'}) {
    final normalized = normalizeNullable(raw);
    if (normalized == null) {
      return null;
    }
    if (normalized.length > maxLength) {
      return '$fieldLabel must be $maxLength characters or fewer.';
    }
    return null;
  }

  static String normalizeForRendering(
    String? raw, {
    int renderMaxLength = maxLength,
  }) {
    if (raw == null) {
      return '';
    }
    final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return '';
    }
    if (compact.length <= renderMaxLength) {
      return compact;
    }
    return '${compact.substring(0, renderMaxLength - 3)}...';
  }
}
