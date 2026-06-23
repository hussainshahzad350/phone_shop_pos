import 'package:phone_shop_pos/modules/dashboard/domain/entities/model_imei_stock_entity.dart';

class StockReportExportService {
  const StockReportExportService();

  static const List<String> headers = <String>[
    'Sr.',
    'Brand',
    'Model',
    'IMEI 1',
    'IMEI 2',
    'Serial No.',
    'Cost Price (PKR)',
    'Selling Price (PKR)',
  ];

  static const String fileBaseName = 'available_stock_report';

  /// Builds flat CSV rows from [brandMap], inserting model subtotal rows
  /// after each model and brand subtotal rows after each brand.
  List<List<String>> buildRows(
    Map<String, List<ModelImeiStockEntity>> brandMap,
  ) {
    final rows = <List<String>>[];
    var sr = 1;
    var grandUnits = 0;
    var grandCost = 0.0;
    var grandSale = 0.0;

    for (final brand in brandMap.keys) {
      final models = brandMap[brand]!;
      var brandUnits = 0;
      var brandCost = 0.0;
      var brandSale = 0.0;

      for (final model in models) {
        var modelUnits = 0;
        var modelCost = 0.0;
        var modelSale = 0.0;

        for (final item in model.imeis) {
          rows.add(<String>[
            '$sr',
            brand,
            model.modelName,
            item.imei,
            item.imei2 ?? '',
            item.serialNumber ?? '',
            item.costPrice.toStringAsFixed(0),
            item.salePrice.toStringAsFixed(0),
          ]);
          sr++;
          modelUnits++;
          modelCost += item.costPrice;
          modelSale += item.salePrice;
        }

        final unitLabel = modelUnits == 1 ? 'unit' : 'units';
        rows.add(<String>[
          '',
          '',
          '${model.modelName} — Subtotal ($modelUnits $unitLabel)',
          '',
          '',
          '',
          modelCost.toStringAsFixed(0),
          modelSale.toStringAsFixed(0),
        ]);

        brandUnits += modelUnits;
        brandCost += modelCost;
        brandSale += modelSale;
      }

      final brandUnitLabel = brandUnits == 1 ? 'unit' : 'units';
      rows.add(<String>[
        '',
        '$brand — Total ($brandUnits $brandUnitLabel)',
        '',
        '',
        '',
        '',
        brandCost.toStringAsFixed(0),
        brandSale.toStringAsFixed(0),
      ]);

      grandUnits += brandUnits;
      grandCost += brandCost;
      grandSale += brandSale;
    }

    final grandLabel = grandUnits == 1 ? 'unit' : 'units';
    rows.add(<String>[
      '',
      'Grand Total ($grandUnits $grandLabel)',
      '',
      '',
      '',
      '',
      grandCost.toStringAsFixed(0),
      grandSale.toStringAsFixed(0),
    ]);

    return rows;
  }
}
