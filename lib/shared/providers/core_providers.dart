import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/sqlite_service.dart';

final localDatabaseServiceProvider = FutureProvider<LocalDatabaseService>((ref) async {
  final appDir = await getApplicationSupportDirectory();
  final service = SqliteFfiDatabaseService(rootDirectory: appDir.path);
  await service.initialize();
  return service;
});
