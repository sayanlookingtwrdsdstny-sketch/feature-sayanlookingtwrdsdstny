import 'package:nuriva/core/errors/app_failure.dart';

/// User-facing wording for auth failures and validation.
///
/// Rules for this copy: say what happened and what to do next, in plain
/// language, with no error codes and no apologies. Never reveal whether an
/// email address has an account.
abstract final class AuthCopy {
  static String forField(String field, String reason) =>
      switch ((field, reason)) {
        ('email', 'empty') => 'Enter your email address.',
        ('email', 'invalid') => "That email address doesn't look right.",
        ('password', 'empty') => 'Enter your password.',
        ('password', 'too_short') => 'Use at least 8 characters.',
        ('displayName', 'empty') => 'Enter your name.',
        ('displayName', 'too_long') =>
          'Please keep your name under 60 characters.',
        ('roles', 'empty') => "Choose who you'll manage medication for.",
        ('consent', 'required') =>
          'Please agree to the privacy notice to continue.',
        ('credentials', 'invalid') =>
          "That email and password don't match. Check them and try again.",
        _ => 'Please check this and try again.',
      };

  static String forFailure(AppFailure failure) => switch (failure) {
        ValidationFailure(:final field, :final reason) =>
          forField(field, reason),
        ConflictFailure(reason: 'email_in_use') =>
          'An account already uses this email. Sign in instead, or reset '
              'your password.',
        ConflictFailure(reason: 'provider_disabled') =>
          "Sign-in isn't available right now. Please try again later.",
        ConflictFailure() => 'Something went wrong. Please try again.',
        RateLimitedFailure() =>
          'Too many attempts. Please wait a few minutes, then try again.',
        NetworkFailure() =>
          "You're offline. Check your internet connection and try again.",
        TimeoutFailure() => 'That took too long. Please try again.',
        PermissionDeniedFailure(action: 'signIn') =>
          "This account can't be used right now.",
        PermissionDeniedFailure() => "You don't have access to that.",
        UnauthenticatedFailure() => 'Please sign in again to continue.',
        NotFoundFailure() || UnexpectedFailure() =>
          'Something went wrong. Please try again.',
      };

  /// Adapts a validator returning a reason token to a Form validator.
  static String? Function(String?) field(
    String name,
    String? Function(String?) validate,
  ) =>
      (value) {
        final reason = validate(value);
        return reason == null ? null : forField(name, reason);
      };
}
