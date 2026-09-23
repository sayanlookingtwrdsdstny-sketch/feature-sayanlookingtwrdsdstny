import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';

/// User-facing wording for prescription-upload failures and statuses.
abstract final class PrescriptionCopy {
  static String forField(String field, String reason) =>
      switch ((field, reason)) {
        ('pages', 'empty') => 'Add at least one photo of the prescription.',
        ('pages', 'too_many') =>
          'A single prescription can have at most 10 pages.',
        _ => 'Please check this and try again.',
      };

  static String forFailure(AppFailure failure) => switch (failure) {
        ValidationFailure(:final field, :final reason) =>
          forField(field, reason),
        PermissionDeniedFailure() =>
          "You don't have permission to do that.",
        RateLimitedFailure() =>
          'Too many attempts. Please wait a few minutes, then try again.',
        NetworkFailure() =>
          "You're offline. Check your internet connection and try again.",
        TimeoutFailure() => 'That took too long. Please try again.',
        UnauthenticatedFailure() => 'Please sign in again to continue.',
        ConflictFailure() ||
        NotFoundFailure() ||
        UnexpectedFailure() =>
          'Something went wrong. Please try again.',
      };

  static String forStatus(PrescriptionStatus status) => switch (status) {
        PrescriptionStatus.uploaded => 'Uploaded',
        PrescriptionStatus.processing => 'Processing',
        PrescriptionStatus.extracted => 'Extracted',
        PrescriptionStatus.underReview => 'Needs review',
        PrescriptionStatus.approved => 'Approved',
        PrescriptionStatus.rejected => 'Rejected',
        PrescriptionStatus.failed => 'Failed',
        PrescriptionStatus.archived => 'Archived',
      };
}
