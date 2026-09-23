import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';

/// Prescription metadata records. The Firestore implementation lives in
/// `data/`; tests use an in-memory fake. Never touches image bytes — those
/// go through `LocalPrescriptionImageStore` instead.
abstract interface class PrescriptionRepository {
  /// Every prescription on [patientId], newest first is not guaranteed —
  /// callers sort as needed.
  Stream<List<Prescription>> watchPrescriptionsForPatient(String patientId);

  Stream<Prescription?> watchPrescription(String prescriptionId);

  /// Creates the metadata record at `status = UPLOADED`, before the page
  /// images are saved locally — the returned [Prescription.id] is what
  /// `LocalImageStore.savePages` files pages under. If the local save then
  /// fails, `PrescriptionService.uploadPrescription` deletes this record
  /// again rather than leaving an `UPLOADED` prescription with no image on
  /// any device.
  Future<Result<Prescription>> createPrescription({
    required String patientId,
    required String uploadedByUid,
    required String mimeType,
    required int pageCount,
    DateTime? prescribedDate,
    String? doctorName,
    String? clinicName,
  });

  /// Deletes the metadata record. Only legal while `status == UPLOADED`
  /// (enforced by `firestore.rules`) — nothing to undo once extraction has
  /// looked at it.
  Future<Result<void>> deletePrescription(String prescriptionId);

  /// Moves a prescription along the extraction state machine (Module 05).
  ///
  /// Only the edges `UPLOADED -> PROCESSING` and
  /// `PROCESSING -> EXTRACTED | FAILED` are legal, and `firestore.rules`
  /// enforces that server-side rather than trusting this client — §10's
  /// "state-machine validation in Rules". Status is the only field a client
  /// may ever change on a prescription; everything else stays immutable after
  /// upload.
  Future<Result<void>> updateStatus({
    required String prescriptionId,
    required PrescriptionStatus status,
  });
}
