import 'package:nuriva/core/errors/app_failure.dart';

/// Maps Firebase error codes to [AppFailure].
///
/// Takes the code *string* rather than the exception type so it is pure and
/// testable without Firebase. The data layer is the only place that sees
/// Firebase exceptions; everything above it sees these typed failures.
abstract final class AuthErrorMapper {
  /// Maps a `FirebaseAuthException.code`.
  static AppFailure fromAuthCode(
    String code, {
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      switch (code) {
        // Newer Firebase projects return `invalid-credential` for both a wrong
        // password and an unknown user (email-enumeration protection). The
        // older codes map to the same failure so the UI never reveals which.
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          AppFailure.validation(
            field: 'credentials',
            reason: 'invalid',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'invalid-email' => AppFailure.validation(
            field: 'email',
            reason: 'invalid',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'weak-password' => AppFailure.validation(
            field: 'password',
            reason: 'too_short',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'email-already-in-use' => AppFailure.conflict(
            reason: 'email_in_use',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'too-many-requests' =>
          AppFailure.rateLimited(cause: cause, stackTrace: stackTrace),
        'network-request-failed' =>
          AppFailure.network(cause: cause, stackTrace: stackTrace),
        'user-disabled' => AppFailure.permissionDenied(
            action: 'signIn',
            cause: cause,
            stackTrace: stackTrace,
          ),
        // Email/password sign-in is switched off in the Firebase console.
        // A configuration problem, not a user error — surfaced distinctly so
        // it is diagnosable from logs.
        'operation-not-allowed' => AppFailure.conflict(
            reason: 'provider_disabled',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'requires-recent-login' || 'user-token-expired' =>
          AppFailure.unauthenticated(cause: cause, stackTrace: stackTrace),
        _ => AppFailure.unexpected(cause: cause, stackTrace: stackTrace),
      };

  /// Maps a Firestore `FirebaseException.code`.
  static AppFailure fromFirestoreCode(
    String code, {
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      switch (code) {
        'permission-denied' => AppFailure.permissionDenied(
            action: 'firestore',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'unauthenticated' =>
          AppFailure.unauthenticated(cause: cause, stackTrace: stackTrace),
        'unavailable' =>
          AppFailure.network(cause: cause, stackTrace: stackTrace),
        'deadline-exceeded' =>
          AppFailure.timeout(cause: cause, stackTrace: stackTrace),
        'not-found' => AppFailure.notFound(
            entity: 'document',
            cause: cause,
            stackTrace: stackTrace,
          ),
        'resource-exhausted' =>
          AppFailure.rateLimited(cause: cause, stackTrace: stackTrace),
        _ => AppFailure.unexpected(cause: cause, stackTrace: stackTrace),
      };
}
