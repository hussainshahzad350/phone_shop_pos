import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/kpi_card_config.dart';

class KpiPreferencesService {
  static const _fileName = 'kpi_card_preferences.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(path.join(dir.path, _fileName));
  }

  Future<List<KpiCardConfig>> load() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) return List.of(kpiCardDefaults);

      final rawList = jsonDecode(await file.readAsString()) as List<dynamic>;
      final savedMap = <String, Map<String, dynamic>>{
        for (final item in rawList)
          (item as Map<String, dynamic>)['id'] as String: item,
      };

      final configs = <KpiCardConfig>[
        for (final def in kpiCardDefaults)
          if (savedMap.containsKey(def.id))
            KpiCardConfig(
              id: def.id,
              label: def.label,
              visible: savedMap[def.id]!['visible'] as bool? ?? true,
              order: savedMap[def.id]!['order'] as int? ?? def.order,
            )
          else
            def,
      ];

      configs.sort((a, b) => a.order.compareTo(b.order));
      return configs;
    } catch (_) {
      return List.of(kpiCardDefaults);
    }
  }

  Future<void> save(List<KpiCardConfig> configs) async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(configs.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }
}
