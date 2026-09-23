import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';

void main() {
  group('PrescriptionStatus.fromWire', () {
    test('round-trips every known value', () {
      for (final status in PrescriptionStatus.values) {
        expect(PrescriptionStatus.fromWire(status.wire), status);
      }
    });

    test('defaults an unknown value to uploaded', () {
      expect(PrescriptionStatus.fromWire('GARBAGE'), PrescriptionStatus.uploaded);
      expect(PrescriptionStatus.fromWire(''), PrescriptionStatus.uploaded);
    });
  });

  group('Prescription', () {
    test('carries optional fields as null when not supplied', () {
      final prescription = Prescription(
        id: 'rx-1',
        patientId: 'p1',
        uploadedByUid: 'uid-1',
        mimeType: 'image/jpeg',
        pageCount: 2,
        status: PrescriptionStatus.uploaded,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(prescription.prescribedDate, isNull);
      expect(prescription.doctorName, isNull);
      expect(prescription.clinicName, isNull);
      expect(prescription.pageCount, 2);
    });
  });
}
