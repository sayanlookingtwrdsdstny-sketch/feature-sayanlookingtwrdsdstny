import 'package:nuriva/core/errors/app_failure.dart';

/// User-facing wording for care-circle failures — creating a patient,
/// inviting a guardian, redeeming a link code.
abstract final class PatientCopy {
  static String forField(String field, String reason) =>
      switch ((field, reason)) {
        ('displayName', 'empty') => 'Enter their name.',
        ('displayName', 'too_long') => 'Keep the name under 60 characters.',
        ('dob', 'required') => 'Enter their date of birth.',
        ('dob', 'in_future') => "That date of birth can't be in the future.",
        ('code', 'empty') => 'Enter the code you were given.',
        ('permissions', 'empty') => 'Choose at least one permission.',
        _ => 'Please check this and try again.',
      };

  static String forFailure(AppFailure failure) => switch (failure) {
        ValidationFailure(:final field, :final reason) =>
          forField(field, reason),
        NotFoundFailure(entity: 'linkCode') =>
          "That code doesn't match anything. Check it and try again.",
        ConflictFailure(reason: 'link_code_expired') =>
          'That code has expired. Ask for a new one.',
        ConflictFailure(reason: 'link_code_consumed') =>
          'That code has already been used. Ask for a new one.',
        ConflictFailure(reason: 'already_guardian') =>
          "You're already connected to this patient.",
        ConflictFailure() => 'Something went wrong. Please try again.',
        PermissionDeniedFailure() =>
          "You don't have permission to do that.",
        RateLimitedFailure() =>
          'Too many attempts. Please wait a few minutes, then try again.',
        NetworkFailure() =>
          "You're offline. Check your internet connection and try again.",
        TimeoutFailure() => 'That took too long. Please try again.',
        UnauthenticatedFailure() => 'Please sign in again to continue.',
        NotFoundFailure() || UnexpectedFailure() =>
          'Something went wrong. Please try again.',
      };
}
