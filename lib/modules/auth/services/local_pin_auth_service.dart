import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

class LocalPinAuthService {
  LocalPinAuthService({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  static const String _pinHashKey = 'auth.pin.hash';
  static const String _pinSaltKey = 'auth.pin.salt';
  static const String _recoveryHashKey = 'auth.recovery.hash';
  static const String _recoverySaltKey = 'auth.recovery.salt';

  Future<bool> hasPinConfigured() async {
    final hash = await _readSetting(_pinHashKey);
    final salt = await _readSetting(_pinSaltKey);
    return hash != null && salt != null;
  }

  Future<String> configurePin(String pin) async {
    await _writePinHash(pin);
    final recoveryCode = _generateRecoveryCode();
    final recoverySalt = _generateSalt();
    final recoveryHash = _hashWithSalt(value: recoveryCode, salt: recoverySalt);

    await _writeSetting(_recoverySaltKey, recoverySalt);
    await _writeSetting(_recoveryHashKey, recoveryHash);
    return recoveryCode;
  }

  Future<bool> verifyPin(String pin) async {
    final storedSalt = await _readSetting(_pinSaltKey);
    final storedHash = await _readSetting(_pinHashKey);
    if (storedSalt == null || storedHash == null) {
      return false;
    }
    final candidateHash = _hashWithSalt(value: pin, salt: storedSalt);
    return candidateHash == storedHash;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final validCurrent = await verifyPin(currentPin);
    if (!validCurrent) {
      return false;
    }
    await _writePinHash(newPin);
    return true;
  }

  Future<String?> regenerateRecoveryCode({required String currentPin}) async {
    final validCurrent = await verifyPin(currentPin);
    if (!validCurrent) {
      return null;
    }

    final recoveryCode = _generateRecoveryCode();
    final recoverySalt = _generateSalt();
    final recoveryHash = _hashWithSalt(value: recoveryCode, salt: recoverySalt);

    await _writeSetting(_recoverySaltKey, recoverySalt);
    await _writeSetting(_recoveryHashKey, recoveryHash);
    return recoveryCode;
  }

  Future<bool> resetPinWithRecoveryCode({
    required String recoveryCode,
    required String newPin,
  }) async {
    final storedSalt = await _readSetting(_recoverySaltKey);
    final storedHash = await _readSetting(_recoveryHashKey);
    if (storedSalt == null || storedHash == null) {
      return false;
    }
    final candidateHash = _hashWithSalt(value: recoveryCode, salt: storedSalt);
    if (candidateHash != storedHash) {
      return false;
    }
    await _writePinHash(newPin);
    return true;
  }

  Future<String?> _readSetting(String key) async {
    final rows = await _appDatabase.database.query(
      TableNames.appSettings,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _writeSetting(String key, String value) async {
    await _appDatabase.database.insert(
      TableNames.appSettings,
      <String, Object?>{
        'key': key,
        'value': value,
        'updated_at': DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _writePinHash(String pin) async {
    final pinSalt = _generateSalt();
    final pinHash = _hashWithSalt(value: pin, salt: pinSalt);
    await _writeSetting(_pinSaltKey, pinSalt);
    await _writeSetting(_pinHashKey, pinHash);
  }

  String _hashWithSalt({required String value, required String salt}) {
    return sha256.convert(utf8.encode('$salt::$value')).toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _generateRecoveryCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final values = List<String>.generate(
      12,
      (_) => chars[random.nextInt(chars.length)],
    );
    return '${values.take(4).join()}-${values.skip(4).take(4).join()}-${values.skip(8).take(4).join()}';
  }
}
