import 'dart:typed_data';

import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/local_image_store.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_repositories.dart';

/// Prescription use cases: uploading a capture, deleting it.
///
/// Orchestration lives here, not in widgets or the repositories — the same
/// split `CareCircleService` uses. Testable against fakes for both
/// dependencies, with no Firebase or platform I/O import.
final class PrescriptionService {
  const PrescriptionService({
    required this.prescriptions,
    required this.localImages,
  });

  final PrescriptionRepository prescriptions;
  final LocalImageStore localImages;

  /// A single capture is 1-10 pages — a business limit on "one prescription",
  /// not a technical one (mirrored in `firestore.rules`).
  static const int maxPages = 10;

  /// Creates the Firestore metadata record, then saves [pages] locally under
  /// its id. If the local save fails, the metadata record is deleted again —
  /// an `UPLOADED` prescription with no image anywhere is worse than no
  /// record at all.
  Future<Result<Prescription>> uploadPrescription({
    required String patientId,
    required String uploadedByUid,
    required List<Uint8List> pages,
    DateTime? prescribedDate,
    String? doctorName,
    String? clinicName,
  }) async {
    if (pages.isEmpty) {
      return const Failure(
        AppFailure.validation(field: 'pages', reason: 'empty'),
      );
    }
    if (pages.length > maxPages) {
      return const Failure(
        AppFailure.validation(field: 'pages', reason: 'too_many'),
      );
    }

    final created = await prescriptions.createPrescription(
      patientId: patientId,
      uploadedByUid: uploadedByUid,
      mimeType: 'image/jpeg',
      pageCount: pages.length,
      prescribedDate: prescribedDate,
      doctorName: doctorName,
      clinicName: clinicName,
    );
    if (created case Failure(:final failure)) {
      return Failure(failure);
    }
    final prescription = created.valueOrNull!;

    final saved = await localImages.savePages(
      patientId: patientId,
      prescriptionId: prescription.id,
      pages: pages,
    );
    if (saved case Failure(:final failure)) {
      await prescriptions.deletePrescription(prescription.id);
      return Failure(failure);
    }

    return Success(prescription);
  }

  /// Deletes the Firestore record, then this device's local pages (a no-op
  /// if this device never had any — e.g. deleting from a second guardian's
  /// phone, see ARCHITECTURE.md §18's Module 04 limitation).
  Future<Result<void>> deletePrescription({
    required String prescriptionId,
    required String patientId,
  }) async {
    final result = await prescriptions.deletePrescription(prescriptionId);
    if (result.isSuccess) {
      await localImages.deletePages(
        patientId: patientId,
        prescriptionId: prescriptionId,
      );
    }
    return result;
  }
}
