import 'package:phone_shop_pos/core/errors/app_error.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  Success<T>? get asSuccess => this is Success<T> ? this as Success<T> : null;
  Failure<T>? get asFailure => this is Failure<T> ? this as Failure<T> : null;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    if (this case Success<T>(value: final value)) {
      return onSuccess(value);
    }
    if (this case Failure<T>(error: final error)) {
      return onFailure(error);
    }
    throw StateError('Unhandled result state');
  }

  Result<R> map<R>(R Function(T value) transform) {
    return fold(
      onSuccess: (value) => Success<R>(transform(value)),
      onFailure: (error) => Failure<R>(error),
    );
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppError error;
}
