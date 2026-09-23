import 'dart:async';

import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_repositories.dart';
import 'package:nuriva/features/prescriptions/domain/ocr_engine.dart';

/// In-memory extraction store. **Tests only.**
final class FakeExtractionRepository implements ExtractionRepository {
  final Map<String, List<PrescriptionExtraction>> _byPrescription = {};
  final StreamController<String> _changed = StreamController.broadcast();
  int _nextId = 1;

  AppFailure? nextFailure;

  List<PrescriptionExtraction> extractionsOf(String prescriptionId) =>
      _byPrescription[prescriptionId] ?? const [];

  @override
  Stream<List<PrescriptionExtraction>> watchExtractions(
    String prescriptionId,
  ) =>
      Stream.multi((controller) {
        controller.add(extractionsOf(prescriptionId));
        final sub = _changed.stream
            .where((id) => id == prescriptionId)
            .listen((_) => controller.add(extractionsOf(prescriptionId)));
        controller.onCancel = sub.cancel;
      });

  @override
  Future<Result<PrescriptionExtraction>> createExtraction({
    required String prescriptionId,
    required ExtractionEngine engine,
    required String engineVersion,
    required ExtractionStatus status,
    required List<String> rawLines,
    required List<MedicationCandidate> candidates,
    required int pagesProcessed,
    required String createdByUid,
    List<String> warnings = const <String>[],
  }) async {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      return Failure(failure);
    }

    final extraction = PrescriptionExtraction(
      id: 'extraction-${_nextId++}',
      prescriptionId: prescriptionId,
      engine: engine,
      engineVersion: engineVersion,
      status: status,
      rawLines: rawLines,
      candidates: candidates,
      pagesProcessed: pagesProcessed,
      warnings: warnings,
      createdByUid: createdByUid,
      createdAt: DateTime.utc(2026),
    );
    _byPrescription.putIfAbsent(prescriptionId, () => []).insert(0, extraction);
    _changed.add(prescriptionId);
    return Success(extraction);
  }
}

/// Scripted OCR. **Tests only.** Returns whatever the test says the camera
/// "saw", so the pipeline can be exercised without ML Kit or a device.
final class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine({this.linesPerPage = const [], this.failingPaths = const {}});

  /// One entry per page, in the order pages are read.
  final List<List<String>> linesPerPage;

  /// Paths that should fail rather than return text — for the partial-read
  /// and total-failure paths.
  final Set<String> failingPaths;

  final List<String> readPaths = [];
  bool disposed = false;

  @override
  String get version => 'fake-ocr';

  @override
  Future<Result<List<String>>> recognizeLines(String imagePath) async {
    if (failingPaths.contains(imagePath)) {
      return const Failure(AppFailure.unexpected());
    }
    final index = readPaths.length;
    readPaths.add(imagePath);
    return Success(
      index < linesPerPage.length ? linesPerPage[index] : const <String>[],
    );
  }

  @override
  Future<void> dispose() async => disposed = true;
}
