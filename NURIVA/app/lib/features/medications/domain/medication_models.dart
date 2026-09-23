/// Medication domain model. Pure Dart: no Flutter, no Firebase.
///
/// This is the most safety-critical entity in NURIVA. A medication that
/// reaches `active` is what Module 09 turns into a dosing schedule and
/// Module 10 turns into alarms on a patient's phone — so the states before
/// that, and who may move between them, are the product's central control.
///
/// Module 06 creates these **only** as [MedicationStatus.pendingApproval],
/// from fields a person typed while looking at the prescription. Nothing in
/// this module can produce an `active` medication, and `firestore.rules`
/// enforces that rather than trusting the client.
library;

/// Mirrors ARCHITECTURE.md §4's full lifecycle. Module 06 writes only
/// [pendingApproval]; the later states belong to Modules 07 and 08.
enum MedicationStatus {
  draft('DRAFT'),
  pendingApproval('PENDING_APPROVAL'),
  active('ACTIVE'),
  paused('PAUSED'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const MedicationStatus(this.wire);

  final String wire;

  static MedicationStatus fromWire(String value) => switch (value) {
        'DRAFT' => MedicationStatus.draft,
        'ACTIVE' => MedicationStatus.active,
        'PAUSED' => MedicationStatus.paused,
        'COMPLETED' => MedicationStatus.completed,
        'CANCELLED' => MedicationStatus.cancelled,
        _ => MedicationStatus.pendingApproval,
      };
}

/// Whether a dose is tied to food. Kept as a small closed set rather than
/// free text, because Module 10's reminder copy has to say something
/// specific and a typo in free text would silently change the instruction.
enum FoodInstruction {
  none('NONE'),
  beforeFood('BEFORE_FOOD'),
  afterFood('AFTER_FOOD'),
  withFood('WITH_FOOD'),
  emptyStomach('EMPTY_STOMACH');

  const FoodInstruction(this.wire);

  final String wire;

  static FoodInstruction fromWire(String value) => switch (value) {
        'BEFORE_FOOD' => FoodInstruction.beforeFood,
        'AFTER_FOOD' => FoodInstruction.afterFood,
        'WITH_FOOD' => FoodInstruction.withFood,
        'EMPTY_STOMACH' => FoodInstruction.emptyStomach,
        _ => FoodInstruction.none,
      };
}

/// A time of day in the patient's local timezone, as `HH:mm`.
///
/// Deliberately not a `DateTime`: "08:00 every day" is a wall-clock
/// instruction, and storing it as an instant would silently shift the dose
/// when the patient's offset changes (ARCHITECTURE.md §8's DST rule). The
/// timezone that resolves these lives on the patient, not here.
final class LocalTimeOfDay implements Comparable<LocalTimeOfDay> {
  const LocalTimeOfDay(this.hour, this.minute);

  final int hour;
  final int minute;

  static LocalTimeOfDay? tryParse(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return LocalTimeOfDay(hour, minute);
  }

  String get wire =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalTimeOfDay other) =>
      (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is LocalTimeOfDay && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => wire;
}

/// One medicine a patient is meant to take.
final class Medication {
  const Medication({
    required this.id,
    required this.patientId,
    required this.medicineName,
    required this.timesLocal,
    required this.startDate,
    required this.status,
    required this.payloadHash,
    required this.createdByUid,
    required this.createdAt,
    required this.updatedAt,
    this.prescriptionId,
    this.extractionId,
    this.strength,
    this.form,
    this.dosage,
    this.foodInstruction = FoodInstruction.none,
    this.endDate,
    this.notes,
  });

  final String id;
  final String patientId;

  /// Where this came from. Null when a guardian added a medicine by hand
  /// with no prescription photo behind it — a real case Module 08 supports.
  final String? prescriptionId;
  final String? extractionId;

  /// As a person typed it. NURIVA does not match against a drug dictionary,
  /// normalize a brand to a generic, or correct a spelling: that would be
  /// identifying or substituting a medicine, which §10 and the repo's
  /// healthcare-safety rule put out of scope.
  final String medicineName;

  final String? strength;
  final String? form;

  /// How much per dose, as written, e.g. `1 tablet`.
  final String? dosage;

  /// The times of day a dose is taken. Sorted, de-duplicated, never empty —
  /// this list *is* the frequency, so "twice a day" is stored as the two
  /// times it actually happens rather than as a count that something later
  /// has to guess times for.
  final List<LocalTimeOfDay> timesLocal;

  final FoodInstruction foodInstruction;
  final DateTime startDate;

  /// Null means open-ended. Module 09 treats that as "until cancelled".
  final DateTime? endDate;

  final String? notes;
  final MedicationStatus status;

  /// Hash of the clinically significant fields, as they were when a person
  /// last saw and saved them. Module 07 re-computes it at approval and
  /// refuses if it has moved — so a guardian can never approve something
  /// other than what was on screen.
  final String payloadHash;

  final String createdByUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// How many doses a day this comes to.
  int get dosesPerDay => timesLocal.length;
}
