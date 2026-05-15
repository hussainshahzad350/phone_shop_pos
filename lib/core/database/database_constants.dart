class DatabaseConstants {
  const DatabaseConstants._();

  static const String databaseName = 'phone_shop_pos.db';
  static const int databaseVersion = 3;

  static const String sqliteForeignKeysOn = 'PRAGMA foreign_keys = ON;';
  static const String sqliteJournalModeWal = 'PRAGMA journal_mode = WAL;';
}
