class FormattingHelpers {
  const FormattingHelpers._();

  static String currencyPkr(double amount) => 'PKR ${decimal(amount)}';

  static String decimal(
    double value, {
    int fractionDigits = 2,
    bool useGrouping = true,
    bool trimTrailingZeros = true,
  }) {
    final isNegative = value.isNegative;
    var fixed = value.abs().toStringAsFixed(fractionDigits);
    // Pakistani retail rarely cares about paisa: display whole rupees as `100`
    // rather than `100.00`, and `100.50` as `100.5`. The stored value keeps its
    // full precision — this only affects presentation.
    if (trimTrailingZeros && fixed.contains('.')) {
      fixed = fixed
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    final parts = fixed.split('.');
    final whole = useGrouping ? _groupDigits(parts.first) : parts.first;
    final fraction = parts.length > 1 ? '.${parts[1]}' : '';
    return '${isNegative ? '-' : ''}$whole$fraction';
  }

  static double parseLocaleDecimal(
    String input, {
    double fallback = 0,
  }) {
    final normalized = _normalizeLocalizedNumber(input);
    return double.tryParse(normalized) ?? fallback;
  }

  static double? tryParseGroupedDecimalStrict(String input) {
    final compact = _translateArabicDigits(input).trim().replaceAll(' ', '');
    if (compact.isEmpty) {
      return null;
    }

    final validPattern = RegExp(
      r'^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:[.٫]\d+)?$',
    );
    if (!validPattern.hasMatch(compact)) {
      return null;
    }

    final normalized = compact.replaceAll(',', '').replaceAll('٫', '.');
    return double.tryParse(normalized);
  }

  static int? parsePositiveInt(String input) {
    final normalized = _normalizeLocalizedNumber(input);
    return int.tryParse(normalized);
  }

  static String dateYmd(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String dateYmdHm(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  static String backupTimestamp(DateTime dateTime) {
    final yyyy = dateTime.year.toString().padLeft(4, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '${yyyy}_${mm}_${dd}_${hh}_$min';
  }

  static String _groupDigits(String digits) {
    if (digits.length <= 3) {
      return digits;
    }
    final reversed = digits.split('').reversed.toList(growable: false);
    final buffer = StringBuffer();
    for (var index = 0; index < reversed.length; index++) {
      if (index > 0 && index % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(reversed[index]);
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _normalizeLocalizedNumber(String input) {
    final compact = _translateArabicDigits(input).trim().replaceAll(' ', '');
    if (compact.isEmpty) {
      return '';
    }

    final sign = compact.startsWith('-') ? '-' : '';
    final unsigned = sign.isEmpty ? compact : compact.substring(1);
    final numeric = unsigned.replaceAll(RegExp(r'[^0-9.,٫]'), '');
    if (numeric.isEmpty) {
      return sign;
    }

    final normalizedArabicDecimal = numeric.replaceAll('٫', '.');
    final lastDot = normalizedArabicDecimal.lastIndexOf('.');
    final lastComma = normalizedArabicDecimal.lastIndexOf(',');

    if (lastDot >= 0 && lastComma >= 0) {
      final decimalSeparator = lastDot > lastComma ? '.' : ',';
      final decimalIndex = decimalSeparator == '.' ? lastDot : lastComma;
      final whole = normalizedArabicDecimal
          .substring(0, decimalIndex)
          .replaceAll(RegExp(r'[^0-9]'), '');
      final fraction = normalizedArabicDecimal
          .substring(decimalIndex + 1)
          .replaceAll(RegExp(r'[^0-9]'), '');
      return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
    }

    if (lastComma >= 0) {
      final commaGrouped = RegExp(r'^\d{1,3}(,\d{3})+$');
      if (commaGrouped.hasMatch(normalizedArabicDecimal)) {
        return sign + normalizedArabicDecimal.replaceAll(',', '');
      }
      return '$sign${normalizedArabicDecimal.replaceAll(',', '.')}';
    }

    if (lastDot >= 0) {
      final dotGrouped = RegExp(r'^\d{1,3}(\.\d{3})+$');
      if (dotGrouped.hasMatch(normalizedArabicDecimal)) {
        return sign + normalizedArabicDecimal.replaceAll('.', '');
      }
    }

    return '$sign$normalizedArabicDecimal';
  }

  static String _translateArabicDigits(String input) {
    const arabicDigits = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };
    final buffer = StringBuffer();
    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      buffer.write(arabicDigits[char] ?? char);
    }
    return buffer.toString();
  }
}
