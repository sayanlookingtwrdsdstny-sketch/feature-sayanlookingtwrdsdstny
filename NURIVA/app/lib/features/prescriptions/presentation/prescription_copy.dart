import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
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
        ConflictFailure(reason: 'prescription_not_extractable') =>
          'This prescription has already been read.',
        NotFoundFailure(entity: 'prescription_pages_on_this_device') =>
          'The photos for this prescription are not on this device, so it '
              "can't be read here. Use the phone that took them.",
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

  /// Plain-language wording for a parser warning.
  ///
  /// Every one of these says what the app *could not* establish. None of them
  /// suggests a value, because the whole point of the warning is that there
  /// isn't a defensible one.
  static String forWarning(String token) => switch (token) {
        ExtractionWarnings.noTextFound =>
          'Some pages had no text the phone could read.',
        ExtractionWarnings.noCandidatesParsed =>
          'No medicine lines could be picked out. The full text is below — '
              'please read it against the photo.',
        ExtractionWarnings.ambiguousFrequency =>
          'How often to take it was written in a way the phone could not '
              'read reliably.',
        ExtractionWarnings.fractionalDose =>
          'This looks like a part-dose (such as half a tablet). It has been '
              'left for you to enter.',
        ExtractionWarnings.dosesPerDayOutOfRange =>
          'The doses per day read off the page were outside a sensible '
              'range, so they were discarded.',
        ExtractionWarnings.durationOutOfRange =>
          'The course length read off the page was outside a sensible '
              'range, so it was discarded.',
        ExtractionWarnings.monthApproximated =>
          'A duration in months was counted as 30 days per month. Please '
              'confirm the exact end date.',
        ExtractionWarnings.missingName => 'The medicine name could not be read.',
        ExtractionWarnings.missingFrequency =>
          'How often to take it could not be read.',
        ExtractionWarnings.missingDuration =>
          'How long to take it could not be read.',
        ExtractionWarnings.directiveText =>
          'This page contains text that reads like an instruction to the app '
              'rather than part of a prescription. Treat it with suspicion.',
        _ => 'Something on this page needs checking.',
      };

  static String forExtractionStatus(ExtractionStatus status) =>
      switch (status) {
        ExtractionStatus.extracted => 'Read',
        ExtractionStatus.needsReview => 'Needs checking',
        ExtractionStatus.failed => 'Could not read',
      };
}
