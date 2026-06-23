import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/kpi_card_config.dart';
import 'package:phone_shop_pos/modules/dashboard/services/kpi_preferences_service.dart';

class KpiPreferencesNotifier extends AsyncNotifier<List<KpiCardConfig>> {
  final _service = KpiPreferencesService();
  static const _minVisible = 2;

  @override
  Future<List<KpiCardConfig>> build() => _service.load();

  Future<void> toggleVisibility(String cardId) async {
    final current = List<KpiCardConfig>.of(state.valueOrNull ?? kpiCardDefaults);
    final visibleCount = current.where((c) => c.visible).length;

    final updated = current.map((c) {
      if (c.id != cardId) return c;
      if (c.visible && visibleCount <= _minVisible) return c;
      return c.copyWith(visible: !c.visible);
    }).toList();

    state = AsyncData(updated);
    await _service.save(updated);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = List<KpiCardConfig>.of(state.valueOrNull ?? kpiCardDefaults);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);

    final reindexed = current
        .asMap()
        .entries
        .map((e) => e.value.copyWith(order: e.key))
        .toList();
    state = AsyncData(reindexed);
    await _service.save(reindexed);
  }
}

final kpiPreferencesProvider =
    AsyncNotifierProvider<KpiPreferencesNotifier, List<KpiCardConfig>>(
  KpiPreferencesNotifier.new,
);
