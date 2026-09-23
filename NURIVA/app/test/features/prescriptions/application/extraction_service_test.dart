import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/application/extraction_service.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';

import '../../../support/fake_extractions.dart';
import '../../../support/fake_prescriptions.dart';

void main() {
  late FakePrescriptionRepository prescriptions;
  late FakeExtractionRepository extractions;
  late FakeLocalImageStore images;

  const patientId = 'patient-1';
  const uid = 'guardian-1';

  setUp(() {
    prescriptions = FakePrescriptionRepository();
    extractions = FakeExtractionRepository();
    images = FakeLocalImageStore();
  });

  Prescription seedPrescription({
    PrescriptionStatus status = PrescriptionStatus.uploaded,
    int pageCount = 1,
  }) {
    final prescription = Prescription(
      id: 'prescription-1',
      patientId: patientId,
      uploadedByUid: uid,
      mimeType: 'image/jpeg',
      pageCount: pageCount,
      status: status,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    prescriptions.seed(prescription);
    return prescription;
  }

  Future<void> seedPages(int count) => images.savePages(
        patientId: patientId,
        prescriptionId: 'prescription-1',
        pages: [for (var i = 0; i < count; i++) Uint8List(0)],
      );

  ExtractionService serviceWith(FakeOcrEngine ocr) => ExtractionService(
        prescriptions: prescriptions,
        extractions: extractions,
        localImages: images,
        ocr: ocr,
      );

  test('records what OCR read and walks the state machine', () async {
    final prescription = seedPrescription();
    await seedPages(1);
    final service = serviceWith(
      FakeOcrEngine(linesPerPage: [
        ['TAB Sompraz 40 MG 1-0-1 15 days'],
      ]),
    );

    final result =
        await service.extract(prescription: prescription, requestedByUid: uid);

    expect(result.isSuccess, isTrue);
    expect(
      prescriptions.statusWrites,
      [PrescriptionStatus.processing, PrescriptionStatus.extracted],
    );

    final stored = extractions.extractionsOf('prescription-1').single;
    expect(stored.rawLines, ['TAB Sompraz 40 MG 1-0-1 15 days']);
    expect(stored.candidates.single.name, 'Sompraz');
    expect(stored.engine, ExtractionEngine.mlkitOnDevice);
    expect(stored.createdByUid, uid);
    expect(stored.pagesProcessed, 1);
  });

  test('records the engine and parser versions together', () async {
    final prescription = seedPrescription();
    await seedPages(1);
    final service = serviceWith(FakeOcrEngine(linesPerPage: [[]]));

    await service.extract(prescription: prescription, requestedByUid: uid);

    expect(
      extractions.extractionsOf('prescription-1').single.engineVersion,
      contains('fake-ocr'),
    );
  });

  test('reads every page that is on this device', () async {
    final prescription = seedPrescription(pageCount: 2);
    await seedPages(2);
    final service = serviceWith(
      FakeOcrEngine(linesPerPage: [
        ['TAB Sompraz 40 MG 1-0-1 15 days'],
        ['TAB Atarax 10 mg 0-0-1 5 days'],
      ]),
    );

    await service.extract(prescription: prescription, requestedByUid: uid);

    final stored = extractions.extractionsOf('prescription-1').single;
    expect(stored.pagesProcessed, 2);
    expect(stored.candidates, hasLength(2));
  });

  test(
    'a prescription whose images are on another phone is not marked failed',
    () async {
      // §18's Module 04 limitation: the pixels live on the device that took
      // them. That is local to this handset, so it must not write FAILED to
      // a document every guardian can see.
      final prescription = seedPrescription();
      final service = serviceWith(FakeOcrEngine());

      final result = await service.extract(
        prescription: prescription,
        requestedByUid: uid,
      );

      expect(result.isSuccess, isFalse);
      expect(prescriptions.statusWrites, isEmpty);
      expect(extractions.extractionsOf('prescription-1'), isEmpty);
    },
  );

  test('marks the prescription failed when no page could be read', () async {
    final prescription = seedPrescription();
    await seedPages(1);
    final service = serviceWith(
      FakeOcrEngine(
        failingPaths: {'fake://$patientId/prescription-1/page_0.jpg'},
      ),
    );

    final result =
        await service.extract(prescription: prescription, requestedByUid: uid);

    expect(result.isSuccess, isFalse);
    expect(
      prescriptions.statusWrites,
      [PrescriptionStatus.processing, PrescriptionStatus.failed],
    );
    expect(extractions.extractionsOf('prescription-1'), isEmpty);
  });

  test('falls back to FAILED when the extraction write is rejected', () async {
    final prescription = seedPrescription();
    await seedPages(1);
    extractions.nextFailure = const AppFailure.permissionDenied(
      action: 'createExtraction',
    );
    final service = serviceWith(
      FakeOcrEngine(linesPerPage: [
        ['TAB Sompraz 40 MG 1-0-1 15 days'],
      ]),
    );

    final result =
        await service.extract(prescription: prescription, requestedByUid: uid);

    expect(result.isSuccess, isFalse);
    expect(prescriptions.statusWrites.last, PrescriptionStatus.failed);
  });

  test('an unreadable page still produces a record with the raw text',
      () async {
    // A blank result is not an error: "nothing legible here" is a real answer
    // about a photograph of paper, and the guardian still needs the record.
    final prescription = seedPrescription();
    await seedPages(1);
    final service = serviceWith(FakeOcrEngine(linesPerPage: [[]]));

    final result =
        await service.extract(prescription: prescription, requestedByUid: uid);

    expect(result.isSuccess, isTrue);
    final stored = extractions.extractionsOf('prescription-1').single;
    expect(stored.rawLines, isEmpty);
    expect(stored.status, ExtractionStatus.needsReview);
    expect(stored.warnings, contains(ExtractionWarnings.noTextFound));
  });

  group('state machine', () {
    test('refuses to run on an already-extracted prescription', () async {
      final prescription =
          seedPrescription(status: PrescriptionStatus.extracted);
      await seedPages(1);
      final service = serviceWith(FakeOcrEngine());

      final result = await service.extract(
        prescription: prescription,
        requestedByUid: uid,
      );

      expect(result.isSuccess, isFalse);
      expect(
        result,
        isA<Failure<PrescriptionExtraction>>().having(
          (f) => f.failure,
          'failure',
          isA<ConflictFailure>(),
        ),
      );
      expect(prescriptions.statusWrites, isEmpty);
    });

    test('allows retrying a failed run', () async {
      final prescription = seedPrescription(status: PrescriptionStatus.failed);
      await seedPages(1);
      final service = serviceWith(FakeOcrEngine(linesPerPage: [[]]));

      final result = await service.extract(
        prescription: prescription,
        requestedByUid: uid,
      );

      expect(result.isSuccess, isTrue);
      expect(prescriptions.statusWrites.first, PrescriptionStatus.processing);
    });

    test('canExtractFrom permits exactly the two documented entry states', () {
      expect(
        ExtractionService.canExtractFrom(PrescriptionStatus.uploaded),
        isTrue,
      );
      expect(
        ExtractionService.canExtractFrom(PrescriptionStatus.failed),
        isTrue,
      );
      for (final status in [
        PrescriptionStatus.processing,
        PrescriptionStatus.extracted,
        PrescriptionStatus.underReview,
        PrescriptionStatus.approved,
        PrescriptionStatus.rejected,
        PrescriptionStatus.archived,
      ]) {
        expect(ExtractionService.canExtractFrom(status), isFalse);
      }
    });
  });

  test('creates no medication of any kind', () async {
    // The module's central safety property, asserted rather than assumed:
    // extraction produces a record to read and nothing that could become a
    // live dosing schedule. Modules 06-08 own that path.
    final prescription = seedPrescription();
    await seedPages(1);
    final service = serviceWith(
      FakeOcrEngine(linesPerPage: [
        ['TAB Sompraz 40 MG 1-0-1 15 days'],
      ]),
    );

    await service.extract(prescription: prescription, requestedByUid: uid);

    final stored = extractions.extractionsOf('prescription-1').single;
    expect(stored.candidates.single, isA<MedicationCandidate>());
    expect(
      prescriptions.prescriptionOf('prescription-1')!.status,
      PrescriptionStatus.extracted,
    );
  });
}
