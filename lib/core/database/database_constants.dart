class DatabaseConstants {
  const DatabaseConstants._();

  static const String databaseName = 'phone_shop_pos.db';
  static const int databaseVersion = 20;
  static const int sqliteBusyTimeoutMs = 5000;
  static const int windowsRecommendedPathLength = 220;

  static const String sqliteForeignKeysOn = 'PRAGMA foreign_keys = ON;';
  static const String sqliteJournalModeWal = 'PRAGMA journal_mode = WAL;';
}
