import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/export/csv_export_service.dart';
import 'package:phone_shop_pos/core/services/export/printable_report_service.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class ReportExportActionWidget extends StatelessWidget {
  const ReportExportActionWidget({
    super.key,
    required this.title,
    required this.fileBaseName,
    required this.headers,
    required this.rows,
    required this.csvExportService,
    required this.printableReportService,
  });

  final String title;
  final String fileBaseName;
  final List<String> headers;
  final List<List<String>> rows;
  final CsvExportService csvExportService;
  final PrintableReportService printableReportService;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        ElevatedButton.icon(
          onPressed: rows.isEmpty
              ? null
              : () async {
                  final folder = await getDirectoryPath();
                  if (folder == null || !context.mounted) {
                    return;
                  }
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final file = await csvExportService.export(
                    directoryPath: folder,
                    fileName: '${fileBaseName}_$timestamp.csv',
                    headers: headers,
                    rows: rows,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  AppNotifier.success('CSV exported: ${file.path}');
                },
          icon: const Icon(Icons.download),
          label: const Text('Export CSV'),
        ),
        OutlinedButton.icon(
          onPressed: rows.isEmpty
              ? null
              : () {
                  final printable = printableReportService.buildPrintableText(
                    title: title,
                    headers: headers,
                    rows: rows,
                    metadata: <String, String>{
                      'Generated At': DateTime.now().toLocal().toString(),
                    },
                  );

                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Printable Layout Preview'),
                      content: AppDialogContentBox(
                        width: 800,
                        child: SingleChildScrollView(
                          child: SelectableText(printable),
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
          icon: const Icon(Icons.print_outlined),
          label: const Text('Printable Preview'),
        ),
      ],
    );
  }
}
