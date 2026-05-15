class DateTimeHelpers {
  const DateTimeHelpers._();

  static DateTime nowUtc() => DateTime.now().toUtc();

  static String toSql(DateTime dateTime) => dateTime.toUtc().toIso8601String();

  static DateTime fromSql(String value) => DateTime.parse(value).toUtc();
}
