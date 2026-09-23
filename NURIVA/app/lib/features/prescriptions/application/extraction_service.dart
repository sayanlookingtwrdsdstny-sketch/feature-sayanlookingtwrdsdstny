import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_repositories.dart';
import 'package:nuriva/features/prescriptions/domain/local_image_store.dart';
import 'package:nuriva/features/prescriptions/domain/ocr_engine.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_repositories.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_text_parser.dart';

/// Runs on-device OCR over a prescription's pages and records the result.
///
/// The entire Module 05 pipeline, and deliberately the *whole* of it: this
/// service reads pixels, produces text, proposes drafts, and stops. It
/// creates no medication and schedules no dose. ARCHITECTURE.md §7's real
/// safety control is the human gate that follows, and the way to keep that
/// control meaningful is for extraction to have no authority of its own.
final class ExtractionService {
  const ExtractionService({
    required this.prescriptions,
    required this.extractions,
    required this.localImages,
    required this.ocr,
  });

  final PrescriptionRepository prescriptions;
  final ExtractionRepository extractions;
  final LocalImageStore localImages;
  final OcrEngine ocr;

  /// Legal edges of the extraction state machine, mirrored in
  /// `firestore.rules` — this copy is a courtesy to the user (a disabled
  /// button instead of a rejected write), never the enforcement.
  static bool canExtractFrom(PrescriptionStatus status) =>
      status == PrescriptionStatus.uploaded ||
      status == PrescriptionStatus.failed;

  /// OCRs every page of [prescription] that exists on *this* device.
  ///
  /// Returns a failure without touching the prescription's status when no
  /// page is available locally. That case is not an extraction failure — it
  /// is §18's Module 04 limitation showing through (the images live on the
  /// phone that took them), and writing `FAILED` to a document every guardian
  /// can see, because of a condition local to one handset, would be wrong.
  Future<Result<PrescriptionExtraction>> extract({
    required Prescription prescription,
    required String requestedByUid,
  }) async {
    if (!canExtractFrom(prescription.status)) {
      return const Failure(
        AppFailure.conflict(reason: 'prescription_not_extractable'),
      );
    }

    final paths = await localImages.pageFilePaths(
      patientId: prescription.patientId,
      prescriptionId: prescription.id,
      pageCount: prescription.pageCount,
    );
    final available = <String>[];
    for (final path in paths) {
      if (await localImages.pageExists(path)) available.add(path);
    }
    if (available.isEmpty) {
      return const Failure(
        AppFailure.notFound(entity: 'prescription_pages_on_this_device'),
      );
    }

    final moved = await prescriptions.updateStatus(
      prescriptionId: prescription.id,
      status: PrescriptionStatus.processing,
    );
    if (moved case Failure(:final failure)) return Failure(failure);

    final lines = <String>[];
    var pagesRead = 0;
    for (final path in available) {
      final recognized = await ocr.recognizeLines(path);
      if (recognized case Success(:final value)) {
        lines.addAll(value);
        pagesRead++;
      }
    }

    if (pagesRead == 0) {
      await prescriptions.updateStatus(
        prescriptionId: prescription.id,
        status: PrescriptionStatus.failed,
      );
      return const Failure(AppFailure.unexpected());
    }

    final parsed = PrescriptionTextParser.parse(lines);
    final warnings = <String>{...parsed.warnings};
    if (pagesRead < available.length) {
      warnings.add(ExtractionWarnings.noTextFound);
    }

    final written = await extractions.createExtraction(
      prescriptionId: prescription.id,
      engine: ExtractionEngine.mlkitOnDevice,
      engineVersion: '${ocr.version}/${PrescriptionTextParser.version}',
      status: parsed.status,
      rawLines: lines,
      candidates: parsed.candidates,
      pagesProcessed: pagesRead,
      createdByUid: requestedByUid,
      warnings: warnings.toList()..sort(),
    );
    if (written case Failure(:final failure)) {
      await prescriptions.updateStatus(
        prescriptionId: prescription.id,
        status: PrescriptionStatus.failed,
      );
      return Failure(failure);
    }

    // The prescription is EXTRACTED even when the extraction itself wants a
    // human's eyes: text was read, and that is what this status means.
    // Whether the *content* is trustworthy is carried on the extraction
    // record, and acting on it is Module 06's decision to gate, not this
    // module's to pre-empt.
    await prescriptions.updateStatus(
      prescriptionId: prescription.id,
      status: PrescriptionStatus.extracted,
    );
    return written;
  }
}
