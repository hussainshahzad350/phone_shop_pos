import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:phone_shop_pos/core/database/database_constants.dart';

abstract class LocalDatabaseService {
  Future<void> initialize();
  DatabaseFactory get factory;
  String get databasePath;
}

class SqliteFfiDatabaseService implements LocalDatabaseService {
  SqliteFfiDatabaseService({required String rootDirectory})
      : _databasePath = p.join(rootDirectory, DatabaseConstants.databaseName);

  final String _databasePath;

  @override
  String get databasePath => _databasePath;

  @override
  DatabaseFactory get factory => databaseFactoryFfi;

  @override
  Future<void> initialize() async {
    sqfliteFfiInit();
  }
}
