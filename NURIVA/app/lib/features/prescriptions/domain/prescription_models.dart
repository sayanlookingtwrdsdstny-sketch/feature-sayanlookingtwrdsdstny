/// Prescription domain model. Pure Dart: no Flutter, no Firebase.
///
/// A [Prescription] is metadata only — patient, uploader, page count, status.
/// The page images themselves never live here and never reach Firestore: see
/// ARCHITECTURE.md §18's Module 04 entry for why (no Blaze plan, so no
/// Firebase Storage; images are saved to the device's local filesystem
/// instead, via `LocalPrescriptionImageStore`).
library;

/// Mirrors ARCHITECTURE.md §4's full status set so the model is
/// forward-compatible with Module 05+ (AI/OCR, verification, approval) even
/// though Module 04 only ever writes [uploaded].
enum PrescriptionStatus {
  uploaded('UPLOADED'),
  processing('PROCESSING'),
  extracted('EXTRACTED'),
  underReview('UNDER_REVIEW'),
  approved('APPROVED'),
  rejected('REJECTED'),
  failed('FAILED'),
  archived('ARCHIVED');

  const PrescriptionStatus(this.wire);

  final String wire;

  static PrescriptionStatus fromWire(String value) => switch (value) {
        'PROCESSING' => PrescriptionStatus.processing,
        'EXTRACTED' => PrescriptionStatus.extracted,
        'UNDER_REVIEW' => PrescriptionStatus.underReview,
        'APPROVED' => PrescriptionStatus.approved,
        'REJECTED' => PrescriptionStatus.rejected,
        'FAILED' => PrescriptionStatus.failed,
        'ARCHIVED' => PrescriptionStatus.archived,
        _ => PrescriptionStatus.uploaded,
      };
}

/// A record of a prescription capture — one or more page images taken or
/// picked for a patient, awaiting the AI/OCR extraction Module 05 adds.
final class Prescription {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.uploadedByUid,
    required this.mimeType,
    required this.pageCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.prescribedDate,
    this.doctorName,
    this.clinicName,
  });

  final String id;
  final String patientId;
  final String uploadedByUid;

  /// `image/jpeg` for everything Module 04 produces — capture/pick is always
  /// compressed to JPEG before saving.
  final String mimeType;

  /// 1..10. Capped client-side (`PrescriptionService`) and in
  /// `firestore.rules` — a business limit on a single capture, not a
  /// technical one.
  final int pageCount;

  final PrescriptionStatus status;
  final DateTime? prescribedDate;
  final String? doctorName;
  final String? clinicName;
  final DateTime createdAt;
  final DateTime updatedAt;
}
