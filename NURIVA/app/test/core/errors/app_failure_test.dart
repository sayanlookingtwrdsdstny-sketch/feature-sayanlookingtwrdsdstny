import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';

void main() {
  const all = <AppFailure>[
    AppFailure.network(),
    AppFailure.timeout(),
    AppFailure.unauthenticated(),
    AppFailure.permissionDenied(action: 'approveMedication'),
    AppFailure.notFound(entity: 'medication'),
    AppFailure.validation(field: 'email', reason: 'must_not_be_empty'),
    AppFailure.conflict(reason: 'stale_approval_hash'),
    AppFailure.unexpected(),
  ];

  group('factories construct the right variant', () {
    test('each maps to its concrete type', () {
      expect(const AppFailure.network(), isA<NetworkFailure>());
      expect(const AppFailure.timeout(), isA<TimeoutFailure>());
      expect(const AppFailure.unauthenticated(), isA<UnauthenticatedFailure>());
      expect(
        const AppFailure.permissionDenied(action: 'a'),
        isA<PermissionDeniedFailure>(),
      );
      expect(
        const AppFailure.notFound(entity: 'e'),
        isA<NotFoundFailure>(),
      );
      expect(
        const AppFailure.validation(field: 'f', reason: 'r'),
        isA<ValidationFailure>(),
      );
      expect(
        const AppFailure.conflict(reason: 'r'),
        isA<ConflictFailure>(),
      );
      expect(const AppFailure.unexpected(), isA<UnexpectedFailure>());
    });
  });

  group('codes', () {
    test('are stable, snake_case tokens', () {
      for (final failure in all) {
        expect(
          failure.code,
          matches(RegExp(r'^[a-z][a-z0-9_]*$')),
          reason: failure.runtimeType.toString(),
        );
      }
    });

    test('are unique across variants', () {
      final codes = all.map((f) => f.code).toSet();
      expect(codes.length, all.length);
    });

    test('match the expected values', () {
      expect(const AppFailure.network().code, 'network');
      expect(const AppFailure.timeout().code, 'timeout');
      expect(const AppFailure.unauthenticated().code, 'unauthenticated');
      expect(
        const AppFailure.permissionDenied(action: 'a').code,
        'permission_denied',
      );
      expect(const AppFailure.notFound(entity: 'e').code, 'not_found');
      expect(
        const AppFailure.validation(field: 'f', reason: 'r').code,
        'validation',
      );
      expect(const AppFailure.conflict(reason: 'r').code, 'conflict');
      expect(const AppFailure.unexpected().code, 'unexpected');
    });
  });

  group('debug messages', () {
    test('are non-empty for every variant', () {
      for (final failure in all) {
        expect(failure.debugMessage, isNotEmpty,
            reason: failure.runtimeType.toString());
      }
    });

    test('include the discriminating detail', () {
      expect(
        const AppFailure.permissionDenied(action: 'approveMedication')
            .debugMessage,
        contains('approveMedication'),
      );
      expect(
        const AppFailure.notFound(entity: 'medication').debugMessage,
        contains('medication'),
      );
      expect(
        const AppFailure.validation(field: 'email', reason: 'empty')
            .debugMessage,
        allOf(contains('email'), contains('empty')),
      );
      expect(
        const AppFailure.conflict(reason: 'stale_approval_hash').debugMessage,
        contains('stale_approval_hash'),
      );
    });
  });

  group('cause and stack trace', () {
    test('default to null', () {
      const failure = AppFailure.network();
      expect(failure.cause, isNull);
      expect(failure.stackTrace, isNull);
    });

    test('are carried when supplied', () {
      final trace = StackTrace.fromString('#0 frame');
      final failure = AppFailure.unexpected(
        cause: const FormatException('bad'),
        stackTrace: trace,
      );

      expect(failure.cause, isA<FormatException>());
      expect(failure.stackTrace, same(trace));
    });
  });

  group('exhaustive switching', () {
    test('every variant is reachable through a sealed switch', () {
      String describe(AppFailure failure) => switch (failure) {
            NetworkFailure() => 'network',
            TimeoutFailure() => 'timeout',
            UnauthenticatedFailure() => 'unauthenticated',
            PermissionDeniedFailure(:final action) => 'denied:$action',
            NotFoundFailure(:final entity) => 'missing:$entity',
            ValidationFailure(:final field) => 'invalid:$field',
            ConflictFailure(:final reason) => 'conflict:$reason',
            UnexpectedFailure() => 'unexpected',
          };

      expect(all.map(describe).toList(), [
        'network',
        'timeout',
        'unauthenticated',
        'denied:approveMedication',
        'missing:medication',
        'invalid:email',
        'conflict:stale_approval_hash',
        'unexpected',
      ]);
    });
  });

  group('distinctness', () {
    test('unauthenticated and permissionDenied are different failures', () {
      // A revoked guardian is signed in but must lose access — the UI response
      // differs, so these must never collapse into one case.
      expect(
        const AppFailure.unauthenticated().code,
        isNot(const AppFailure.permissionDenied(action: 'x').code),
      );
    });
  });
}
