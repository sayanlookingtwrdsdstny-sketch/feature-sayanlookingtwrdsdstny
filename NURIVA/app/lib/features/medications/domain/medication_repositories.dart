import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';

/// Medication records. The Firestore implementation lives in `data/`.
///
/// Note what is absent: there is no `activate`, no status setter, and no
/// general `update`. Module 06 can bring a medication into existence as a
/// draft awaiting approval and nothing else. Moving one to `active` is
/// Module 07's to design — and, per ARCHITECTURE.md §10, needs a decision
/// about who is allowed to do it at all when no Cloud Function exists.
abstract interface class MedicationRepository {
  /// Every medication recorded for [patientId].
  Stream<List<Medication>> watchMedicationsForPatient(String patientId);

  /// Medications created from a particular prescription, so the
  /// verification screen can show what has already been captured from it.
  ///
  /// Takes [patientId] as well as [prescriptionId] deliberately. The
  /// security rule authorizes on `patientId`, and Firestore only permits a
  /// query it can prove safe **from that query's own filters** — a lesson
  /// Module 03 learned the hard way (see its notes on `watchGuardianPatients`).
  /// A query filtered only by `prescriptionId` would be denied outright, for
  /// any data, so the filter that carries the authorization is the one that
  /// goes to the server and the narrower match happens on the client.
  Stream<List<Medication>> watchMedicationsForPrescription({
    required String patientId,
    required String prescriptionId,
  });

  /// Creates one medication at [MedicationStatus.pendingApproval].
  ///
  /// The status is not a parameter on purpose: a caller must not be able to
  /// ask for `active`, and a reader of this signature should be able to see
  /// that no caller can.
  Future<Result<Medication>> createPendingMedication({
    required String patientId,
    required String medicineName,
    required List<LocalTimeOfDay> timesLocal,
    required DateTime startDate,
    required String createdByUid,
    required String payloadHash,
    String? prescriptionId,
    String? extractionId,
    String? strength,
    String? form,
    String? dosage,
    FoodInstruction foodInstruction,
    DateTime? endDate,
    String? notes,
  });

  /// Deletes a draft. Only legal while `PENDING_APPROVAL` (enforced in
  /// `firestore.rules`) — once something has been approved it is part of the
  /// patient's record and Module 08 owns cancelling it properly.
  Future<Result<void>> deletePendingMedication(String medicationId);
}
