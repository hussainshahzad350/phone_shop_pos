import 'package:phone_shop_pos/core/utils/imei_helpers.dart';

/// One parsed line from a multi-line IMEI paste — up to
/// `IMEI1[,IMEI2[,SerialNumber]]` per line.
class ParsedImeiLine {
  const ParsedImeiLine({
    required this.imei1,
    this.imei2,
    this.serialNumber,
  });

  final String imei1;
  final String? imei2;
  final String? serialNumber;
}

/// Shared multi-line IMEI paste parser — one device per line, fields
/// separated by comma/semicolon/tab. Extracted from the Purchases module's
/// bulk-entry widget so Inventory's bulk-add flow uses the identical parsing
/// logic instead of a second implementation.
class ImeiBulkParser {
  const ImeiBulkParser._();

  static List<ParsedImeiLine> parse(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final parsed = <ParsedImeiLine>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,;\t]+'));
      final imei1 = parts.isNotEmpty ? ImeiHelpers.normalize(parts[0]) : '';
      final imei2 =
          parts.length > 1 ? ImeiHelpers.normalizeNullable(parts[1]) : null;
      final serial = parts.length > 2 ? parts[2].trim() : null;
      parsed.add(ParsedImeiLine(
        imei1: imei1,
        imei2: imei2?.isNotEmpty == true ? imei2 : null,
        serialNumber: serial?.isNotEmpty == true ? serial : null,
      ));
    }
    return parsed;
  }
}
