import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';

/// Hashes the clinically significant fields of a medication.
///
/// ARCHITECTURE.md §7 steps 12-13: at approval, the hash is recomputed from
/// stored state and compared with what the guardian was shown. A mismatch
/// means the medication changed between being displayed and being approved,
/// and the approval is refused. That check is only worth anything if this
/// function is **deterministic and injective** — the same fields must always
/// give the same digest, and two different sets of fields must never collide
/// through sloppy encoding.
///
/// Hence the length-prefixed encoding below. Joining fields with a separator
/// is the obvious approach and it is subtly wrong: `name="A|B", dosage=""`
/// and `name="A", dosage="B"` would produce the same string, so a dosage
/// could be moved into a name without changing the hash. Prefixing every
/// value with its length removes that class of ambiguity entirely.
abstract final class MedicationPayloadHash {
  /// Bump when the field set changes. Stored hashes carry no version of
  /// their own, so an approval written under `v1` must not be silently
  /// re-validated under different rules.
  static const String version = 'v1';

  /// Fields deliberately **excluded**:
  ///
  /// * `notes` — free text a guardian keeps for themselves. It changes
  ///   nothing about what is taken or when, and making it hash-significant
  ///   would force a pointless re-approval every time someone fixes a typo.
  /// * `quantity` — how much was dispensed, not how much is taken.
  /// * `status`, timestamps, ids — not clinical content.
  ///
  /// `patientId` **is** included: approving the right dose against the wrong
  /// patient is exactly the failure this check exists to make impossible.
  static String of(Medication medication) => compute(
        patientId: medication.patientId,
        medicineName: medication.medicineName,
        strength: medication.strength,
        form: medication.form,
        dosage: medication.dosage,
        timesLocal: medication.timesLocal,
        foodInstruction: medication.foodInstruction,
        startDate: medication.startDate,
        endDate: medication.endDate,
      );

  static String compute({
    required String patientId,
    required String medicineName,
    required List<LocalTimeOfDay> timesLocal,
    required DateTime startDate,
    String? strength,
    String? form,
    String? dosage,
    FoodInstruction foodInstruction = FoodInstruction.none,
    DateTime? endDate,
  }) {
    // Times are a set, not a sequence: 08:00+20:00 and 20:00+08:00 are the
    // same instruction, and must not hash differently just because a form
    // happened to collect them in a different order.
    final times = [...timesLocal]..sort();

    final buffer = StringBuffer()
      ..write(_field(version))
      ..write(_field(patientId))
      ..write(_field(medicineName.trim()))
      ..write(_field(strength?.trim() ?? ''))
      ..write(_field(form?.trim() ?? ''))
      ..write(_field(dosage?.trim() ?? ''))
      ..write(_field(times.map((t) => t.wire).join(',')))
      ..write(_field(foodInstruction.wire))
      ..write(_field(_date(startDate)))
      ..write(_field(endDate == null ? '' : _date(endDate)));

    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  static String _field(String value) => '${value.length}:$value';

  /// The calendar date as written, with any time component and offset
  /// discarded. A medication starting "on the 3rd" must hash the same
  /// whether the form built that date at midnight or at midday.
  static String _date(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
