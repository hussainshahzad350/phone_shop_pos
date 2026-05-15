import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';

class ImeiEntryWidget extends StatefulWidget {
  const ImeiEntryWidget({
    required this.defaultCostPrice,
    super.key,
  });

  final double defaultCostPrice;

  @override
  State<ImeiEntryWidget> createState() => _ImeiEntryWidgetState();
}

class _ImeiEntryWidgetState extends State<ImeiEntryWidget> {
  final TextEditingController _bulkController = TextEditingController();
  List<_ParsedImeiLine> _preview = const <_ParsedImeiLine>[];
  double _defaultCost = 0;

  @override
  void initState() {
    super.initState();
    _defaultCost = widget.defaultCostPrice;
  }

  @override
  void dispose() {
    _bulkController.dispose();
    super.dispose();
  }

  void _parseInput(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final parsed = <_ParsedImeiLine>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,;\t]+'));
      final imei1 = parts.isNotEmpty ? parts[0].trim() : '';
      if (imei1.isEmpty) {
        continue;
      }
      final imei2 = parts.length > 1 ? parts[1].trim() : null;
      final serial = parts.length > 2 ? parts[2].trim() : null;
      parsed.add(_ParsedImeiLine(
        imei1: imei1,
        imei2: imei2?.isNotEmpty == true ? imei2 : null,
        serialNumber: serial?.isNotEmpty == true ? serial : null,
      ));
    }

    setState(() {
      _preview = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add IMEI Entries'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Enter one device per line. Formats accepted:\n'
              '• IMEI1\n'
              '• IMEI1,IMEI2\n'
              '• IMEI1,IMEI2,SerialNumber',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Text('Default cost price: '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: _defaultCost.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Cost',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final parsed = FormattingHelpers.parseLocaleDecimal(
                        v,
                        fallback: -1,
                      );
                      if (parsed >= 0) {
                        _defaultCost = parsed;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bulkController,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '356789101234561\n356789101234562,356789101234570\n...',
                labelText: 'Paste IMEIs here',
              ),
              onChanged: _parseInput,
            ),
            const SizedBox(height: 8),
            if (_preview.isNotEmpty) ...<Widget>[
              Text(
                'Preview: ${_preview.length} device(s)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _preview.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _preview[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${index + 1}. ${entry.imei1}'
                        '${entry.imei2 != null ? " / ${entry.imei2}" : ""}'
                        '${entry.serialNumber != null ? " [${entry.serialNumber}]" : ""}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop<List<ImeiEntry>>(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _preview.isEmpty
              ? null
              : () {
                  final entries = _preview
                      .map(
                        (p) => ImeiEntry(
                          imei1: p.imei1,
                          imei2: p.imei2,
                          serialNumber: p.serialNumber,
                          costPrice: _defaultCost,
                        ),
                      )
                      .toList(growable: false);
                  Navigator.of(context).pop<List<ImeiEntry>>(entries);
                },
          child: Text('Add ${_preview.length} Device(s)'),
        ),
      ],
    );
  }
}

class _ParsedImeiLine {
  const _ParsedImeiLine({
    required this.imei1,
    this.imei2,
    this.serialNumber,
  });

  final String imei1;
  final String? imei2;
  final String? serialNumber;
}
