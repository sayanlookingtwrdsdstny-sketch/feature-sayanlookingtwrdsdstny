import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';

/// What a person typed on the verification screen, before it is trusted.
///
/// ARCHITECTURE.md §7's stage-3 business rules applied to human input rather
/// than model output. The bounds are the same ones the extraction validator
/// uses, for the same reason: a schedule outside them is far more likely to
/// be a slip than a prescription.
final class MedicationDraft {
  const MedicationDraft({
    required this.medicineName,
    required this.timesLocal,
    required this.startDate,
    this.strength,
    this.form,
    this.dosage,
    this.foodInstruction = FoodInstruction.none,
    this.endDate,
    this.notes,
  });

  final String medicineName;
  final List<LocalTimeOfDay> timesLocal;
  final DateTime startDate;
  final String? strength;
  final String? form;
  final String? dosage;
  final FoodInstruction foodInstruction;
  final DateTime? endDate;
  final String? notes;

  /// Matches the extraction validator's bounds (§7 stage 3).
  static const int maxDosesPerDay = 12;
  static const int maxDurationDays = 365;
  static const int maxNameLength = 120;
  static const int maxShortFieldLength = 60;
  static const int maxNotesLength = 500;

  /// Validates and normalizes. Times come back sorted and de-duplicated, so
  /// the payload hash does not depend on the order a form happened to
  /// collect them in.
  Result<MedicationDraft> validate() {
    final name = medicineName.trim();
    if (name.isEmpty) {
      return const Failure(
        AppFailure.validation(field: 'medicineName', reason: 'empty'),
      );
    }
    if (name.length > maxNameLength) {
      return const Failure(
        AppFailure.validation(field: 'medicineName', reason: 'too_long'),
      );
    }

    final times = <LocalTimeOfDay>{...timesLocal}.toList()..sort();
    if (times.isEmpty) {
      return const Failure(
        AppFailure.validation(field: 'timesLocal', reason: 'empty'),
      );
    }
    if (times.length > maxDosesPerDay) {
      return const Failure(
        AppFailure.validation(field: 'timesLocal', reason: 'too_many'),
      );
    }

    if (endDate != null) {
      final start = _dateOnly(startDate);
      final end = _dateOnly(endDate!);
      if (end.isBefore(start)) {
        return const Failure(
          AppFailure.validation(field: 'endDate', reason: 'before_start'),
        );
      }
      // Inclusive of both ends: start == end is a one-day course, not zero.
      if (end.difference(start).inDays + 1 > maxDurationDays) {
        return const Failure(
          AppFailure.validation(field: 'endDate', reason: 'too_long'),
        );
      }
    }

    for (final (field, value) in [
      ('strength', strength),
      ('form', form),
      ('dosage', dosage),
    ]) {
      if ((value?.trim().length ?? 0) > maxShortFieldLength) {
        return Failure(
          AppFailure.validation(field: field, reason: 'too_long'),
        );
      }
    }
    if ((notes?.trim().length ?? 0) > maxNotesLength) {
      return const Failure(
        AppFailure.validation(field: 'notes', reason: 'too_long'),
      );
    }

    return Success(
      MedicationDraft(
        medicineName: name,
        timesLocal: times,
        startDate: startDate,
        strength: _clean(strength),
        form: _clean(form),
        dosage: _clean(dosage),
        foodInstruction: foodInstruction,
        endDate: endDate,
        notes: _clean(notes),
      ),
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}
