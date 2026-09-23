import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';

void main() {
  group('Patient', () {
    test('isSelfOf matches only the linked uid', () {
      final patient = Patient(
        id: 'p1',
        displayName: 'Asha',
        dob: DateTime.utc(1950),
        sex: PatientSex.female,
        timezone: 'Asia/Kolkata',
        createdByUid: 'uid-1',
        guardianUids: const {'uid-1'},
        linkedUserUid: 'uid-1',
      );
      expect(patient.isSelfOf('uid-1'), isTrue);
      expect(patient.isSelfOf('uid-2'), isFalse);
    });

    test('a guardian-managed patient with no login is never self', () {
      final patient = Patient(
        id: 'p1',
        displayName: 'Grandma',
        dob: DateTime.utc(1940),
        sex: PatientSex.female,
        timezone: 'Asia/Kolkata',
        createdByUid: 'uid-1',
        guardianUids: const {'uid-1'},
      );
      expect(patient.isSelfOf('uid-1'), isFalse);
      expect(patient.linkedUserUid, isNull);
    });
  });

  group('PatientSex.fromWire', () {
    test('round-trips known values', () {
      expect(PatientSex.fromWire('FEMALE'), PatientSex.female);
      expect(PatientSex.fromWire('MALE'), PatientSex.male);
    });

    test('an unknown value defaults to unspecified, not a thrown error', () {
      expect(PatientSex.fromWire('NONSENSE'), PatientSex.unspecified);
    });
  });

  group('GuardianPermission', () {
    test('defaults never include manageMedications', () {
      expect(
        GuardianPermission.defaults.contains(GuardianPermission.manageMedications),
        isFalse,
      );
    });

    test('fromWire round-trips every variant and rejects unknowns', () {
      for (final permission in GuardianPermission.values) {
        expect(GuardianPermission.fromWire(permission.wire), permission);
      }
      expect(GuardianPermission.fromWire('NOT_A_PERMISSION'), isNull);
    });
  });

  group('GuardianRelationship', () {
    GuardianRelationship relationship({
      RelationshipStatus status = RelationshipStatus.active,
      Set<GuardianPermission> permissions = const {
        GuardianPermission.viewMedications,
      },
      bool isPrimary = false,
    }) =>
        GuardianRelationship(
          id: 'p1__uid-2',
          patientId: 'p1',
          guardianUid: 'uid-2',
          isPrimary: isPrimary,
          status: status,
          permissions: permissions,
          invitedByUid: 'uid-1',
          invitedAt: DateTime.utc(2026),
        );

    test('isActive / isPending reflect status', () {
      expect(relationship(status: RelationshipStatus.active).isActive, isTrue);
      expect(relationship(status: RelationshipStatus.pending).isPending, isTrue);
      expect(relationship(status: RelationshipStatus.pending).isActive, isFalse);
    });

    test('has() requires both an active status and the specific permission', () {
      final active = relationship(
        permissions: const {GuardianPermission.viewMedications},
      );
      expect(active.has(GuardianPermission.viewMedications), isTrue);
      expect(active.has(GuardianPermission.manageMedications), isFalse);

      final pending = relationship(
        status: RelationshipStatus.pending,
        permissions: const {GuardianPermission.viewMedications},
      );
      expect(
        pending.has(GuardianPermission.viewMedications),
        isFalse,
        reason: 'a PENDING relationship grants nothing yet',
      );
    });
  });

  group('PatientLinkCode', () {
    PatientLinkCode code({DateTime? expiresAt, String? consumedByUid}) =>
        PatientLinkCode(
          code: 'ABC234',
          patientId: 'p1',
          createdByUid: 'uid-1',
          permissions: GuardianPermission.defaults,
          expiresAt: expiresAt ?? DateTime.utc(2026, 9, 20),
          consumedByUid: consumedByUid,
        );

    test('is redeemable before expiry and while unconsumed', () {
      final live = code(expiresAt: DateTime.utc(2026, 9, 20));
      expect(live.isRedeemableAt(DateTime.utc(2026, 9, 19)), isTrue);
    });

    test('is not redeemable once expired', () {
      final expired = code(expiresAt: DateTime.utc(2026, 9, 20));
      expect(expired.isExpiredAt(DateTime.utc(2026, 9, 21)), isTrue);
      expect(expired.isRedeemableAt(DateTime.utc(2026, 9, 21)), isFalse);
    });

    test('is not redeemable once consumed, even before expiry', () {
      final consumed = code(consumedByUid: 'uid-2');
      expect(consumed.isConsumed, isTrue);
      expect(consumed.isRedeemableAt(DateTime.utc(2026, 9, 19)), isFalse);
    });
  });
}
