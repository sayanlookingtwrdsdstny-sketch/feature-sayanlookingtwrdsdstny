import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/medications/domain/medication_draft.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/medications/domain/medication_payload_hash.dart';
import 'package:nuriva/features/medications/domain/medication_repositories.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_repositories.dart';

/// Turns what a person read off a prescription into a medication draft.
///
/// ARCHITECTURE.md §7 step 10. The screen above this shows the photo, the
/// text the phone read, and editable fields; this service takes the result,
/// validates it, and records it as `PENDING_APPROVAL` — never `ACTIVE`.
///
/// The human is the extractor here, not a checker of a machine's work. That
/// is a stronger position than §7 assumed, not a weaker one: there is no
/// confident-looking draft to anchor on, so the fields start empty unless
/// the OCR read something defensible.
final class VerificationService {
  const VerificationService({
    required this.medications,
    required this.prescriptions,
  });

  final MedicationRepository medications;
  final PrescriptionRepository prescriptions;

  /// Whether a prescription is at a point where verification makes sense.
  static bool canVerify(PrescriptionStatus status) =>
      status == PrescriptionStatus.extracted ||
      status == PrescriptionStatus.underReview;

  Future<Result<Medication>> saveVerifiedMedication({
    required Prescription prescription,
    required MedicationDraft draft,
    required String verifiedByUid,
    String? extractionId,
  }) async {
    final validated = draft.validate();
    if (validated case Failure(:final failure)) return Failure(failure);
    final clean = validated.valueOrNull!;

    final payloadHash = MedicationPayloadHash.compute(
      patientId: prescription.patientId,
      medicineName: clean.medicineName,
      strength: clean.strength,
      form: clean.form,
      dosage: clean.dosage,
      timesLocal: clean.timesLocal,
      foodInstruction: clean.foodInstruction,
      startDate: clean.startDate,
      endDate: clean.endDate,
    );

    final created = await medications.createPendingMedication(
      patientId: prescription.patientId,
      prescriptionId: prescription.id,
      extractionId: extractionId,
      medicineName: clean.medicineName,
      strength: clean.strength,
      form: clean.form,
      dosage: clean.dosage,
      timesLocal: clean.timesLocal,
      foodInstruction: clean.foodInstruction,
      startDate: clean.startDate,
      endDate: clean.endDate,
      notes: clean.notes,
      createdByUid: verifiedByUid,
      payloadHash: payloadHash,
    );
    if (created case Failure(:final failure)) return Failure(failure);

    // Best-effort, and deliberately not part of the result: the medication
    // draft is the artifact that matters, and failing the whole operation
    // after it was written would report a loss that did not happen. A
    // prescription left at EXTRACTED with drafts against it is cosmetic;
    // Module 07 re-derives review state from the drafts themselves.
    if (prescription.status == PrescriptionStatus.extracted) {
      await prescriptions.updateStatus(
        prescriptionId: prescription.id,
        status: PrescriptionStatus.underReview,
      );
    }

    return created;
  }

  /// Removes a draft captured by mistake. Legal only while the medication is
  /// still awaiting approval — `firestore.rules` enforces that.
  Future<Result<void>> discardDraft(String medicationId) =>
      medications.deletePendingMedication(medicationId);
}
