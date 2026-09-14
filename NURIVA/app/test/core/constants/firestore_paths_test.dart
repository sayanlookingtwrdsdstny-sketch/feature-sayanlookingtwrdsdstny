import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';

void main() {
  group('document paths', () {
    test('build under the right collection', () {
      expect(FirestorePaths.user('u1'), 'users/u1');
      expect(FirestorePaths.patient('p1'), 'patients/p1');
      expect(FirestorePaths.prescription('rx1'), 'prescriptions/rx1');
      expect(FirestorePaths.medication('m1'), 'medications/m1');
      expect(FirestorePaths.doseLog('d1'), 'dose_logs/d1');
    });

    test('have an even number of segments, so they address documents', () {
      // Firestore alternates collection/document, so a document path always
      // has an even segment count: `users/u1` is 2.
      for (final path in [
        FirestorePaths.user('u1'),
        FirestorePaths.patient('p1'),
        FirestorePaths.medication('m1'),
        FirestorePaths.doseLog('d1'),
      ]) {
        expect(path.split('/').length.isEven, isTrue, reason: path);
      }
    });
  });

  group('subcollection paths', () {
    test('nest under their parent document', () {
      expect(
        FirestorePaths.extractions('rx1'),
        'prescriptions/rx1/extractions',
      );
      expect(
        FirestorePaths.scheduleVersions('m1'),
        'medications/m1/schedule_versions',
      );
      expect(
        FirestorePaths.adherenceDaily('p1'),
        'patients/p1/adherence_daily',
      );
    });

    test('have an odd number of segments, so they address collections', () {
      // `prescriptions/rx1/extractions` is 3 — a collection, not a document.
      for (final path in [
        FirestorePaths.extractions('rx1'),
        FirestorePaths.scheduleVersions('m1'),
        FirestorePaths.adherenceDaily('p1'),
      ]) {
        expect(path.split('/').length.isOdd, isTrue, reason: path);
      }
    });
  });

  group('guardianRelationshipId', () {
    test('joins patient and guardian with a double underscore', () {
      expect(
        FirestorePaths.guardianRelationshipId(
          patientId: 'p1',
          guardianUid: 'g1',
        ),
        'p1__g1',
      );
    });

    test('is deterministic — same inputs give the same id', () {
      final a = FirestorePaths.guardianRelationshipId(
        patientId: 'p1',
        guardianUid: 'g1',
      );
      final b = FirestorePaths.guardianRelationshipId(
        patientId: 'p1',
        guardianUid: 'g1',
      );

      expect(a, b);
    });

    test('is not symmetric — argument order changes the id', () {
      final forward = FirestorePaths.guardianRelationshipId(
        patientId: 'a',
        guardianUid: 'b',
      );
      final reversed = FirestorePaths.guardianRelationshipId(
        patientId: 'b',
        guardianUid: 'a',
      );

      expect(forward, isNot(reversed));
    });

    test('stays unambiguous when ids contain single underscores', () {
      // Firebase UIDs can contain underscores; a single-underscore separator
      // would make the key impossible to split back apart.
      final id = FirestorePaths.guardianRelationshipId(
        patientId: 'pat_1',
        guardianUid: 'gu_2',
      );

      expect(id, 'pat_1__gu_2');
      expect(id.split(FirestorePaths.relationshipIdSeparator), ['pat_1', 'gu_2']);
    });

    test('rejects empty or blank ids', () {
      expect(
        () => FirestorePaths.guardianRelationshipId(
          patientId: '',
          guardianUid: 'g1',
        ),
        throwsArgumentError,
      );
      expect(
        () => FirestorePaths.guardianRelationshipId(
          patientId: 'p1',
          guardianUid: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('the full path sits in the relationships collection', () {
      expect(
        FirestorePaths.guardianRelationship(
          patientId: 'p1',
          guardianUid: 'g1',
        ),
        'guardian_relationships/p1__g1',
      );
    });
  });

  group('adherenceDailyId', () {
    test('formats as yyyy-MM-dd', () {
      expect(
        FirestorePaths.adherenceDailyId(DateTime(2026, 9, 14)),
        '2026-09-14',
      );
    });

    test('zero-pads single-digit months and days', () {
      expect(
        FirestorePaths.adherenceDailyId(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
    });

    test('ids sort chronologically as plain strings', () {
      final ids = [
        FirestorePaths.adherenceDailyId(DateTime(2026, 12, 1)),
        FirestorePaths.adherenceDailyId(DateTime(2026, 2, 3)),
        FirestorePaths.adherenceDailyId(DateTime(2025, 11, 30)),
      ]..sort();

      expect(ids, ['2025-11-30', '2026-02-03', '2026-12-01']);
    });

    test('ignores the time component', () {
      expect(
        FirestorePaths.adherenceDailyId(DateTime(2026, 9, 14, 23, 59, 59)),
        FirestorePaths.adherenceDailyId(DateTime(2026, 9, 14)),
      );
    });
  });

  group('prescriptionStorage', () {
    test('is patient-scoped so Storage Rules can authorize on the path', () {
      expect(
        FirestorePaths.prescriptionStorage(
          patientId: 'p1',
          prescriptionId: 'rx1',
          fileName: 'original.jpg',
        ),
        'prescriptions/p1/rx1/original.jpg',
      );
    });

    test('puts the patient id in the second segment', () {
      final path = FirestorePaths.prescriptionStorage(
        patientId: 'p1',
        prescriptionId: 'rx1',
        fileName: 'original.jpg',
      );

      expect(path.split('/')[1], 'p1');
    });

    test('rejects empty components', () {
      expect(
        () => FirestorePaths.prescriptionStorage(
          patientId: '',
          prescriptionId: 'rx1',
          fileName: 'f.jpg',
        ),
        throwsArgumentError,
      );
      expect(
        () => FirestorePaths.prescriptionStorage(
          patientId: 'p1',
          prescriptionId: '',
          fileName: 'f.jpg',
        ),
        throwsArgumentError,
      );
      expect(
        () => FirestorePaths.prescriptionStorage(
          patientId: 'p1',
          prescriptionId: 'rx1',
          fileName: '  ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('collection names', () {
    test('are snake_case and stable', () {
      const names = [
        FirestorePaths.users,
        FirestorePaths.patients,
        FirestorePaths.guardianRelationships,
        FirestorePaths.patientLinkCodes,
        FirestorePaths.prescriptions,
        FirestorePaths.medications,
        FirestorePaths.doseLogs,
        FirestorePaths.appointments,
        FirestorePaths.notifications,
        FirestorePaths.auditLogs,
      ];

      for (final name in names) {
        expect(name, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: name);
      }
    });

    test('are all distinct', () {
      const names = {
        FirestorePaths.users,
        FirestorePaths.patients,
        FirestorePaths.guardianRelationships,
        FirestorePaths.patientLinkCodes,
        FirestorePaths.prescriptions,
        FirestorePaths.medications,
        FirestorePaths.doseLogs,
        FirestorePaths.appointments,
        FirestorePaths.notifications,
        FirestorePaths.auditLogs,
      };

      expect(names.length, 10);
    });
  });
}
