import 'dart:math';

class IdHelpers {
  IdHelpers._();

  static final Random _random = Random.secure();

  static String newId({String prefix = 'id'}) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${prefix}_$timestamp$randomPart';
  }
}
