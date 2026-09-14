import 'package:nuriva/core/errors/app_failure.dart';

/// The return type for every operation that can fail.
///
/// NURIVA does not let exceptions cross layer boundaries. A repository returns
/// [Result], never throws, so a caller cannot forget that failure is possible —
/// the type system makes them handle it.
///
/// [Result] is `sealed`, so a `switch` over it must be exhaustive. Adding a new
/// variant later turns every incomplete `switch` into a compile error rather
/// than a runtime surprise. Dart 3 provides this natively, which is why NURIVA
/// does not pull in `freezed` for it.
sealed class Result<T> {
  const Result();

  /// True when this holds a value.
  bool get isSuccess => this is Success<T>;

  /// True when this holds a failure.
  bool get isFailure => this is Failure<T>;

  /// The value, or `null` when this is a [Failure].
  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  /// The failure, or `null` when this is a [Success].
  AppFailure? get failureOrNull => switch (this) {
        Success() => null,
        Failure(:final failure) => failure,
      };

  /// The value, or [fallback] when this is a [Failure].
  T getOrElse(T fallback) => switch (this) {
        Success(:final value) => value,
        Failure() => fallback,
      };

  /// Transforms a success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success(:final value) => Success<R>(transform(value)),
        Failure(:final failure) => Failure<R>(failure),
      };

  /// Chains another fallible operation, leaving a failure untouched.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) =>
      switch (this) {
        Success(:final value) => transform(value),
        Failure(:final failure) => Failure<R>(failure),
      };

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final failure) => onFailure(failure),
      };
}

/// A successful [Result] carrying a value.
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Success<$T>($value)';
}

/// A failed [Result] carrying an [AppFailure].
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure);

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'Failure<$T>($failure)';
}

/// Runs [action], converting any thrown object into a [Failure].
///
/// This is the **only** place third-party exceptions are allowed to be caught
/// and converted. Data-layer implementations wrap their SDK calls here so that
/// nothing above the data layer ever sees a raw exception.
Result<T> guard<T>(
  T Function() action, {
  AppFailure Function(Object error, StackTrace stackTrace)? onError,
}) {
  try {
    return Success<T>(action());
  } catch (error, stackTrace) {
    return Failure<T>(
      onError?.call(error, stackTrace) ??
          AppFailure.unexpected(cause: error, stackTrace: stackTrace),
    );
  }
}

/// Asynchronous counterpart to [guard].
Future<Result<T>> guardAsync<T>(
  Future<T> Function() action, {
  AppFailure Function(Object error, StackTrace stackTrace)? onError,
}) async {
  try {
    return Success<T>(await action());
  } catch (error, stackTrace) {
    return Failure<T>(
      onError?.call(error, stackTrace) ??
          AppFailure.unexpected(cause: error, stackTrace: stackTrace),
    );
  }
}
