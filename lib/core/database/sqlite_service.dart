import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract class LocalDatabaseService {
  Future<void> initialize();
  DatabaseFactory get factory;
  String get databasePath;
}

class SqliteFfiDatabaseService implements LocalDatabaseService {
  SqliteFfiDatabaseService({required String rootDirectory})
      : _databasePath = p.join(rootDirectory, 'phone_shop_pos.db');

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
