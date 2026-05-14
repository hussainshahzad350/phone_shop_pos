import '../errors/result.dart';

abstract class BaseRepository {
  Future<Result<T>> guard<T>(Future<T> Function() action);
}
