import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/medications/domain/medication_draft.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/medications/domain/medication_payload_hash.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/verification/application/verification_service.dart';

import '../../../support/fake_medications.dart';
import '../../../support/fake_prescriptions.dart';

void main() {
  late FakeMedicationRepository medications;
  late FakePrescriptionRepository prescriptions;
  late VerificationService service;

  const patientId = 'patient-1';
  const uid = 'guardian-1';

  setUp(() {
    medications = FakeMedicationRepository();
    prescriptions = FakePrescriptionRepository();
    service = VerificationService(
      medications: medications,
      prescriptions: prescriptions,
    );
  });

  Prescription seedPrescription({
    PrescriptionStatus status = PrescriptionStatus.extracted,
  }) {
    final prescription = Prescription(
      id: 'prescription-1',
      patientId: patientId,
      uploadedByUid: uid,
      mimeType: 'image/jpeg',
      pageCount: 1,
      status: status,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    prescriptions.seed(prescription);
    return prescription;
  }

  MedicationDraft draft({
    String medicineName = 'Sompraz',
    List<LocalTimeOfDay>? timesLocal,
  }) =>
      MedicationDraft(
        medicineName: medicineName,
        timesLocal: timesLocal ?? [const LocalTimeOfDay(8, 0)],
        startDate: DateTime(2026, 3, 3),
        strength: '40 mg',
        form: 'Tablet',
        dosage: '1 tablet',
        foodInstruction: FoodInstruction.beforeFood,
      );

  test('records a draft awaiting approval, never active', () {
    // The module's central safety property.
    final prescription = seedPrescription();

    return service
        .saveVerifiedMedication(
      prescription: prescription,
      draft: draft(),
      verifiedByUid: uid,
    )
        .then((result) {
      expect(result.isSuccess, isTrue);
      final saved = medications.all.single;
      expect(saved.status, MedicationStatus.pendingApproval);
      expect(saved.patientId, patientId);
      expect(saved.prescriptionId, 'prescription-1');
      expect(saved.createdByUid, uid);
    });
  });

  test('stores a payload hash matching the saved fields', () async {
    final prescription = seedPrescription();

    await service.saveVerifiedMedication(
      prescription: prescription,
      draft: draft(),
      verifiedByUid: uid,
    );

    final saved = medications.all.single;
    expect(saved.payloadHash, MedicationPayloadHash.of(saved));
  });

  test('normalizes the draft before hashing it', () async {
    // Times out of order must not produce a different hash from the same
    // times in order — otherwise a re-approval could spuriously fail.
    final prescription = seedPrescription();

    await service.saveVerifiedMedication(
      prescription: prescription,
      draft: draft(
        timesLocal: const [LocalTimeOfDay(20, 0), LocalTimeOfDay(8, 0)],
      ),
      verifiedByUid: uid,
    );

    final saved = medications.all.single;
    expect(
      saved.timesLocal,
      const [LocalTimeOfDay(8, 0), LocalTimeOfDay(20, 0)],
    );
    expect(saved.payloadHash, MedicationPayloadHash.of(saved));
  });

  test('rejects an invalid draft without writing anything', () async {
    final prescription = seedPrescription();

    final result = await service.saveVerifiedMedication(
      prescription: prescription,
      draft: draft(medicineName: '  '),
      verifiedByUid: uid,
    );

    expect(result.isSuccess, isFalse);
    expect(medications.all, isEmpty);
    expect(prescriptions.statusWrites, isEmpty);
  });

  group('prescription status', () {
    test('moves to UNDER_REVIEW once something is captured', () async {
      final prescription = seedPrescription();

      await service.saveVerifiedMedication(
        prescription: prescription,
        draft: draft(),
        verifiedByUid: uid,
      );

      expect(prescriptions.statusWrites, [PrescriptionStatus.underReview]);
    });

    test('is not re-written when already under review', () async {
      final prescription =
          seedPrescription(status: PrescriptionStatus.underReview);

      await service.saveVerifiedMedication(
        prescription: prescription,
        draft: draft(),
        verifiedByUid: uid,
      );

      expect(prescriptions.statusWrites, isEmpty);
    });

    test('a failed status write does not lose the medication', () async {
      // The draft is the artifact that matters. Reporting failure after it
      // was written would claim a loss that did not happen.
      final prescription = seedPrescription();
      prescriptions.nextFailure = const AppFailure.permissionDenied(
        action: 'updateStatus',
      );

      final result = await service.saveVerifiedMedication(
        prescription: prescription,
        draft: draft(),
        verifiedByUid: uid,
      );

      expect(result.isSuccess, isTrue);
      expect(medications.all, hasLength(1));
    });
  });

  test('propagates a write failure', () async {
    final prescription = seedPrescription();
    medications.nextFailure = const AppFailure.permissionDenied(
      action: 'createPendingMedication',
    );

    final result = await service.saveVerifiedMedication(
      prescription: prescription,
      draft: draft(),
      verifiedByUid: uid,
    );

    expect(result.isSuccess, isFalse);
    expect(prescriptions.statusWrites, isEmpty);
  });

  test('discards a draft', () async {
    final prescription = seedPrescription();
    final created = await service.saveVerifiedMedication(
      prescription: prescription,
      draft: draft(),
      verifiedByUid: uid,
    );

    await service.discardDraft(created.valueOrNull!.id);

    expect(medications.all, isEmpty);
  });

  test('canVerify permits exactly the documented states', () {
    expect(VerificationService.canVerify(PrescriptionStatus.extracted), isTrue);
    expect(
      VerificationService.canVerify(PrescriptionStatus.underReview),
      isTrue,
    );
    for (final status in [
      PrescriptionStatus.uploaded,
      PrescriptionStatus.processing,
      PrescriptionStatus.approved,
      PrescriptionStatus.rejected,
      PrescriptionStatus.failed,
      PrescriptionStatus.archived,
    ]) {
      expect(VerificationService.canVerify(status), isFalse);
    }
  });
}
