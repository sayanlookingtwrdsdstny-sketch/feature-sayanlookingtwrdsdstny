import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/prescriptions/application/prescription_service.dart';

import '../../../support/fake_prescriptions.dart';

void main() {
  late FakePrescriptionRepository prescriptions;
  late FakeLocalImageStore localImages;
  late PrescriptionService service;

  setUp(() {
    prescriptions = FakePrescriptionRepository();
    localImages = FakeLocalImageStore();
    service = PrescriptionService(
      prescriptions: prescriptions,
      localImages: localImages,
    );
  });

  List<Uint8List> pages(int count) =>
      List.generate(count, (i) => Uint8List.fromList([i]));

  group('uploadPrescription', () {
    test('rejects an empty page list', () async {
      final result = await service.uploadPrescription(
        patientId: 'p1',
        uploadedByUid: 'uid-1',
        pages: const [],
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect((result.failureOrNull as ValidationFailure).field, 'pages');
      expect((result.failureOrNull as ValidationFailure).reason, 'empty');
    });

    test('rejects more than the page cap', () async {
      final result = await service.uploadPrescription(
        patientId: 'p1',
        uploadedByUid: 'uid-1',
        pages: pages(PrescriptionService.maxPages + 1),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect((result.failureOrNull as ValidationFailure).reason, 'too_many');
    });

    test('creates the record and saves pages locally', () async {
      final result = await service.uploadPrescription(
        patientId: 'p1',
        uploadedByUid: 'uid-1',
        pages: pages(3),
      );
      expect(result.isSuccess, isTrue);
      final prescription = result.valueOrNull!;
      expect(prescription.pageCount, 3);
      expect(prescriptions.prescriptionOf(prescription.id), isNotNull);
      expect(localImages.hasPages(prescription.id), isTrue);
    });

    test('rolls back the metadata record when the local save fails', () async {
      localImages.nextFailure = const AppFailure.unexpected();
      final result = await service.uploadPrescription(
        patientId: 'p1',
        uploadedByUid: 'uid-1',
        pages: pages(1),
      );
      expect(result.isFailure, isTrue);
      await expectLater(
        prescriptions.watchPrescriptionsForPatient('p1'),
        emits(isEmpty),
      );
    });
  });

  group('deletePrescription', () {
    test('removes both the record and this device\'s local pages', () async {
      final created = await service.uploadPrescription(
        patientId: 'p1',
        uploadedByUid: 'uid-1',
        pages: pages(1),
      );
      final id = created.valueOrNull!.id;

      final result = await service.deletePrescription(
        prescriptionId: id,
        patientId: 'p1',
      );
      expect(result.isSuccess, isTrue);
      expect(prescriptions.prescriptionOf(id), isNull);
      expect(localImages.hasPages(id), isFalse);
    });
  });
}
