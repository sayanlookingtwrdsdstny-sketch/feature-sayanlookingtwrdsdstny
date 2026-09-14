import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';

void main() {
  const failure = AppFailure.network();

  group('Success', () {
    test('reports success and exposes its value', () {
      const result = Success<int>(7);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
    });

    test('getOrElse returns the value, not the fallback', () {
      const result = Success<int>(7);
      expect(result.getOrElse(99), 7);
    });

    test('equality is by value', () {
      expect(const Success<int>(7), const Success<int>(7));
      expect(const Success<int>(7), isNot(const Success<int>(8)));
      expect(const Success<int>(7).hashCode, const Success<int>(7).hashCode);
    });

    test('toString names the type and value', () {
      expect(const Success<int>(7).toString(), 'Success<int>(7)');
    });
  });

  group('Failure', () {
    test('reports failure and exposes its failure', () {
      const result = Failure<int>(failure);

      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });

    test('getOrElse returns the fallback', () {
      const result = Failure<int>(failure);
      expect(result.getOrElse(99), 99);
    });

    test('equality is by failure', () {
      expect(const Failure<int>(failure), const Failure<int>(failure));
      expect(
        const Failure<int>(failure),
        isNot(const Failure<int>(AppFailure.timeout())),
      );
    });
  });

  group('map', () {
    test('transforms a success value', () {
      final result = const Success<int>(7).map((v) => v * 2);
      expect(result, const Success<int>(14));
    });

    test('changes the value type', () {
      final result = const Success<int>(7).map((v) => 'n=$v');
      expect(result.valueOrNull, 'n=7');
    });

    test('leaves a failure untouched and does not run the transform', () {
      var called = false;
      final result = const Failure<int>(failure).map((v) {
        called = true;
        return v * 2;
      });

      expect(called, isFalse, reason: 'transform must not run on failure');
      expect(result.failureOrNull, same(failure));
    });
  });

  group('flatMap', () {
    test('chains a success into another success', () {
      final result = const Success<int>(7).flatMap((v) => Success<int>(v + 1));
      expect(result, const Success<int>(8));
    });

    test('chains a success into a failure', () {
      final result =
          const Success<int>(7).flatMap((_) => const Failure<int>(failure));
      expect(result.failureOrNull, same(failure));
    });

    test('leaves a failure untouched and does not run the transform', () {
      var called = false;
      final result = const Failure<int>(failure).flatMap((v) {
        called = true;
        return Success<int>(v);
      });

      expect(called, isFalse);
      expect(result.failureOrNull, same(failure));
    });
  });

  group('fold', () {
    test('runs only the success branch for a success', () {
      final branches = <String>[];
      final out = const Success<int>(7).fold(
        onSuccess: (v) {
          branches.add('success');
          return v.toString();
        },
        onFailure: (f) {
          branches.add('failure');
          return f.code;
        },
      );

      expect(out, '7');
      expect(branches, ['success']);
    });

    test('runs only the failure branch for a failure', () {
      final branches = <String>[];
      final out = const Failure<int>(failure).fold(
        onSuccess: (v) {
          branches.add('success');
          return v.toString();
        },
        onFailure: (f) {
          branches.add('failure');
          return f.code;
        },
      );

      expect(out, 'network');
      expect(branches, ['failure']);
    });
  });

  group('guard', () {
    test('wraps a returned value in Success', () {
      final result = guard(() => 7);
      expect(result, const Success<int>(7));
    });

    test('converts a thrown error into UnexpectedFailure by default', () {
      final result = guard<int>(() => throw StateError('boom'));

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(result.failureOrNull!.cause, isA<StateError>());
      expect(result.failureOrNull!.stackTrace, isNotNull);
    });

    test('uses onError to classify the failure when provided', () {
      final result = guard<int>(
        () => throw StateError('boom'),
        onError: (_, _) => const AppFailure.conflict(reason: 'mapped'),
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
      expect((result.failureOrNull! as ConflictFailure).reason, 'mapped');
    });
  });

  group('guardAsync', () {
    test('wraps a resolved value in Success', () async {
      final result = await guardAsync(() async => 7);
      expect(result, const Success<int>(7));
    });

    test('converts a thrown error into a Failure', () async {
      final result = await guardAsync<int>(() async => throw StateError('x'));

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test('uses onError to classify the failure when provided', () async {
      final result = await guardAsync<int>(
        () async => throw StateError('x'),
        onError: (_, _) => const AppFailure.timeout(),
      );

      expect(result.failureOrNull, isA<TimeoutFailure>());
    });
  });
}
