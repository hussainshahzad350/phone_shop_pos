import 'dart:io';

import 'package:path/path.dart' as p;

abstract class CsvExportService {
  Future<File> export({
    required String directoryPath,
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
  });
}

class FileCsvExportService implements CsvExportService {
  const FileCsvExportService();

  @override
  Future<File> export({
    required String directoryPath,
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fullName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
    final file = File(p.join(directory.path, fullName));

    final lines = <String>[
      headers.map(_escapeCell).join(','),
      ...rows.map((row) => row.map(_escapeCell).join(',')),
    ];

    await file.writeAsString(lines.join('\n'));
    return file;
  }

  String _escapeCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
