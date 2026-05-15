class FormattingHelpers {
  const FormattingHelpers._();

  static String currencyPkr(double amount) => 'PKR ${decimal(amount)}';

  static String decimal(
    double value, {
    int fractionDigits = 2,
    bool useGrouping = true,
  }) {
    final isNegative = value.isNegative;
    final fixed = value.abs().toStringAsFixed(fractionDigits);
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
    return '${yyyy}_${mm}_${dd}_${hh}_${min}';
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
    final buffer = StringBuffer();
    var decimalAdded = false;
    final trimmed = input.trim();
    for (var index = 0; index < trimmed.length; index++) {
      final character = trimmed[index];
      if (RegExp(r'[0-9-]').hasMatch(character)) {
        buffer.write(character);
        continue;
      }
      if (character == '.' || character == ',' || character == '٫') {
        if (!decimalAdded) {
          buffer.write('.');
          decimalAdded = true;
        }
        continue;
      }
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
      final translated = arabicDigits[character];
      if (translated != null) {
        buffer.write(translated);
      }
    }
    return buffer.toString();
  }
}
