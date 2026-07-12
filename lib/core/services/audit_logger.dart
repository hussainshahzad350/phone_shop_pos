import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Single write-path for the `audit_logs` table. Extracted from the insert
/// that used to live inline inside `voidSale` so any repository can record an
/// audit entry with one call instead of hand-writing the insert map again —
/// the extension point "prepare the architecture for future audit logging"
/// asks for, without retrofitting every mutation in this pass.
class AuditLogger {
  const AuditLogger._();

  /// Records one audit entry. Pass the active [Transaction] when called from
  /// inside a `runInTransaction` block so the entry commits/rolls back with
  /// the rest of the operation; otherwise pass the plain database executor.
  static Future<void> record(
    DatabaseExecutor db, {
    required String action,
    required String entityId,
    String? actorId,
    String? details,
  }) {
    return db.insert(
      TableNames.auditLogs,
      <String, Object?>{
        'id': IdHelpers.newId(prefix: 'aud'),
        'action': action,
        'actor_id': actorId,
        'entity_id': entityId,
        'details': details,
        'created_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      },
    );
  }
}
