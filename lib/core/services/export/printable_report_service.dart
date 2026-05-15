abstract class PrintableReportService {
  String buildPrintableText({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String> metadata = const <String, String>{},
  });
}

class PlainTextPrintableReportService implements PrintableReportService {
  const PlainTextPrintableReportService();

  @override
  String buildPrintableText({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String> metadata = const <String, String>{},
  }) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('=' * title.length);

    if (metadata.isNotEmpty) {
      for (final entry in metadata.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln('');
    }

    buffer.writeln(headers.join(' | '));
    buffer.writeln(List.filled(headers.length, '---').join(' | '));

    for (final row in rows) {
      buffer.writeln(row.join(' | '));
    }

    return buffer.toString();
  }
}
