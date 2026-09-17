import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';

void main() {
  group('fromAuthCode', () {
    test('wrong password and unknown user map to the same failure', () {
      // Never reveal whether an email has an account.
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'INVALID_LOGIN_CREDENTIALS',
      ]) {
        final f = AuthErrorMapper.fromAuthCode(code);
        expect(f, isA<ValidationFailure>(), reason: code);
        expect((f as ValidationFailure).field, 'credentials', reason: code);
      }
    });

    test('maps the other known codes', () {
      expect(
        AuthErrorMapper.fromAuthCode('email-already-in-use'),
        isA<ConflictFailure>().having((f) => f.reason, 'r', 'email_in_use'),
      );
      expect(
        AuthErrorMapper.fromAuthCode('weak-password'),
        isA<ValidationFailure>().having((f) => f.field, 'f', 'password'),
      );
      expect(
        AuthErrorMapper.fromAuthCode('invalid-email'),
        isA<ValidationFailure>().having((f) => f.field, 'f', 'email'),
      );
      expect(AuthErrorMapper.fromAuthCode('too-many-requests'),
          isA<RateLimitedFailure>());
      expect(AuthErrorMapper.fromAuthCode('network-request-failed'),
          isA<NetworkFailure>());
      expect(AuthErrorMapper.fromAuthCode('user-disabled'),
          isA<PermissionDeniedFailure>());
      expect(
        AuthErrorMapper.fromAuthCode('operation-not-allowed'),
        isA<ConflictFailure>()
            .having((f) => f.reason, 'r', 'provider_disabled'),
      );
      expect(AuthErrorMapper.fromAuthCode('requires-recent-login'),
          isA<UnauthenticatedFailure>());
    });

    test('an unknown code is unexpected, and keeps its cause', () {
      final cause = Exception('x');
      final f = AuthErrorMapper.fromAuthCode('brand-new-code', cause: cause);
      expect(f, isA<UnexpectedFailure>());
      expect(f.cause, same(cause));
    });
  });

  group('fromFirestoreCode', () {
    test('maps the codes the profile repository can hit', () {
      expect(AuthErrorMapper.fromFirestoreCode('permission-denied'),
          isA<PermissionDeniedFailure>());
      expect(AuthErrorMapper.fromFirestoreCode('unavailable'),
          isA<NetworkFailure>());
      expect(AuthErrorMapper.fromFirestoreCode('deadline-exceeded'),
          isA<TimeoutFailure>());
      expect(AuthErrorMapper.fromFirestoreCode('resource-exhausted'),
          isA<RateLimitedFailure>());
      expect(AuthErrorMapper.fromFirestoreCode('whatever'),
          isA<UnexpectedFailure>());
    });
  });
}
