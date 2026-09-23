import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/medications/domain/medication_payload_hash.dart';

/// The hash is what lets Module 07 assert a guardian approved exactly what
/// they were shown. These tests exist to prove two things: the same
/// medication always hashes the same, and no clinically significant change
/// slips through unnoticed.
void main() {
  String hash({
    String patientId = 'patient-1',
    String medicineName = 'Sompraz',
    List<LocalTimeOfDay>? timesLocal,
    DateTime? startDate,
    String? strength = '40 mg',
    String? form = 'Tablet',
    String? dosage = '1 tablet',
    FoodInstruction foodInstruction = FoodInstruction.beforeFood,
    DateTime? endDate,
  }) =>
      MedicationPayloadHash.compute(
        patientId: patientId,
        medicineName: medicineName,
        timesLocal: timesLocal ??
            [const LocalTimeOfDay(8, 0), const LocalTimeOfDay(20, 0)],
        startDate: startDate ?? DateTime(2026, 3, 3),
        strength: strength,
        form: form,
        dosage: dosage,
        foodInstruction: foodInstruction,
        endDate: endDate,
      );

  test('is stable across calls', () {
    expect(hash(), hash());
  });

  test('is a sha256 digest', () {
    expect(hash(), hasLength(64));
    expect(hash(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  group('changes when a clinically significant field changes', () {
    test('medicine name', () {
      expect(hash(medicineName: 'Sompraz D'), isNot(hash()));
    });

    test('strength', () {
      expect(hash(strength: '20 mg'), isNot(hash()));
    });

    test('form', () {
      expect(hash(form: 'Capsule'), isNot(hash()));
    });

    test('dosage', () {
      expect(hash(dosage: '2 tablets'), isNot(hash()));
    });

    test('a dose time', () {
      expect(
        hash(timesLocal: [
          const LocalTimeOfDay(8, 0),
          const LocalTimeOfDay(21, 0),
        ]),
        isNot(hash()),
      );
    });

    test('the number of doses', () {
      expect(hash(timesLocal: [const LocalTimeOfDay(8, 0)]), isNot(hash()));
    });

    test('food instruction', () {
      expect(hash(foodInstruction: FoodInstruction.afterFood), isNot(hash()));
    });

    test('start date', () {
      expect(hash(startDate: DateTime(2026, 3, 4)), isNot(hash()));
    });

    test('end date appearing', () {
      expect(hash(endDate: DateTime(2026, 3, 20)), isNot(hash()));
    });

    test('patient', () {
      // The right dose approved against the wrong patient is exactly what
      // this check has to catch.
      expect(hash(patientId: 'patient-2'), isNot(hash()));
    });
  });

  group('does not change for things that are not clinical', () {
    test('the order times were entered in', () {
      expect(
        hash(timesLocal: [
          const LocalTimeOfDay(20, 0),
          const LocalTimeOfDay(8, 0),
        ]),
        hash(),
      );
    });

    test('surrounding whitespace', () {
      expect(hash(medicineName: '  Sompraz  '), hash());
    });

    test('the time of day a start date carries', () {
      expect(hash(startDate: DateTime(2026, 3, 3, 13, 45)), hash());
    });
  });

  group('encoding is unambiguous', () {
    test('content cannot be shifted between fields without changing it', () {
      // The classic separator-joining bug: with a naive "a|b" encoding these
      // two produce identical strings, so a dosage could be smuggled into a
      // name and the approval check would never notice.
      final a = hash(medicineName: 'Sompraz|40 mg', strength: '');
      final b = hash(medicineName: 'Sompraz', strength: '40 mg');
      expect(a, isNot(b));
    });

    test('an empty field and a missing field agree', () {
      // Both mean "not recorded", and must not be treated as different
      // clinical content.
      expect(hash(strength: null), hash(strength: ''));
    });
  });

  test('of() matches compute() for the same medication', () {
    final medication = Medication(
      id: 'medication-1',
      patientId: 'patient-1',
      medicineName: 'Sompraz',
      strength: '40 mg',
      form: 'Tablet',
      dosage: '1 tablet',
      timesLocal: const [LocalTimeOfDay(8, 0), LocalTimeOfDay(20, 0)],
      foodInstruction: FoodInstruction.beforeFood,
      startDate: DateTime(2026, 3, 3),
      status: MedicationStatus.pendingApproval,
      payloadHash: '',
      createdByUid: 'guardian-1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    expect(MedicationPayloadHash.of(medication), hash());
  });

  test('notes are deliberately not part of the hash', () {
    // A guardian fixing a typo in their own note must not invalidate a
    // clinical approval.
    final medication = Medication(
      id: 'medication-1',
      patientId: 'patient-1',
      medicineName: 'Sompraz',
      strength: '40 mg',
      form: 'Tablet',
      dosage: '1 tablet',
      timesLocal: const [LocalTimeOfDay(8, 0), LocalTimeOfDay(20, 0)],
      foodInstruction: FoodInstruction.beforeFood,
      startDate: DateTime(2026, 3, 3),
      notes: 'ask the pharmacist about the generic',
      status: MedicationStatus.pendingApproval,
      payloadHash: '',
      createdByUid: 'guardian-1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    expect(MedicationPayloadHash.of(medication), hash());
  });
}
