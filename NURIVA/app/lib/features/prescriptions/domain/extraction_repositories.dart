import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';

/// Extraction records, stored under `prescriptions/{id}/extractions`
/// (ARCHITECTURE.md §4's subcollection, reached via `FirestorePaths`).
///
/// Append-only by design: a run is never edited, and re-running extraction
/// writes a new record rather than replacing the old one. The audit question
/// this module has to be able to answer is "what did the device actually read
/// off that page, and when" — rewriting history would erase it.
abstract interface class ExtractionRepository {
  /// Every extraction run for [prescriptionId], newest first.
  Stream<List<PrescriptionExtraction>> watchExtractions(String prescriptionId);

  Future<Result<PrescriptionExtraction>> createExtraction({
    required String prescriptionId,
    required ExtractionEngine engine,
    required String engineVersion,
    required ExtractionStatus status,
    required List<String> rawLines,
    required List<MedicationCandidate> candidates,
    required int pagesProcessed,
    required String createdByUid,
    List<String> warnings,
  });
}
