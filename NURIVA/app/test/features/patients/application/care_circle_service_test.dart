import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/patients/application/care_circle_service.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';

import '../../../support/fake_patients.dart';

void main() {
  late FakePatientRepository patients;
  late FakeGuardianRelationshipRepository relationships;
  late CareCircleService service;

  setUp(() {
    patients = FakePatientRepository();
    relationships = FakeGuardianRelationshipRepository();
    service = CareCircleService(patients: patients, relationships: relationships);
  });

  group('ensureSelfPatient', () {
    test('creates a patient linked to the uid on first call', () async {
      final result = await service.ensureSelfPatient(
        uid: 'uid-1',
        displayName: 'Asha',
        timezone: 'Asia/Kolkata',
      );
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.linkedUserUid, 'uid-1');
    });

    test('is idempotent — a second call returns the same record', () async {
      final first = await service.ensureSelfPatient(
        uid: 'uid-1',
        displayName: 'Asha',
        timezone: 'Asia/Kolkata',
      );
      final second = await service.ensureSelfPatient(
        uid: 'uid-1',
        displayName: 'Asha',
        timezone: 'Asia/Kolkata',
      );
      expect(second.valueOrNull!.id, first.valueOrNull!.id);
    });
  });

  group('createManagedPatient', () {
    Future<void> expectValidationField(
      Future<dynamic> Function() call,
      String field,
    ) async {
      final result = await call();
      expect(
        (result as dynamic).failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'field', field),
      );
    }

    test('rejects an empty display name without calling the backend',
        () async {
      await expectValidationField(
        () => service.createManagedPatient(
          displayName: '   ',
          dob: DateTime.utc(1950),
          sex: PatientSex.unspecified,
          timezone: 'Asia/Kolkata',
          creatorUid: 'uid-1',
        ),
        'displayName',
      );
    });

    test('rejects a name over 60 characters', () async {
      await expectValidationField(
        () => service.createManagedPatient(
          displayName: 'A' * 61,
          dob: DateTime.utc(1950),
          sex: PatientSex.unspecified,
          timezone: 'Asia/Kolkata',
          creatorUid: 'uid-1',
        ),
        'displayName',
      );
    });

    test('rejects a date of birth in the future', () async {
      await expectValidationField(
        () => service.createManagedPatient(
          displayName: 'Grandma',
          dob: DateTime.now().add(const Duration(days: 1)),
          sex: PatientSex.unspecified,
          timezone: 'Asia/Kolkata',
          creatorUid: 'uid-1',
        ),
        'dob',
      );
    });

    test('trims the name and makes the creator the sole guardian', () async {
      final result = await service.createManagedPatient(
        displayName: '  Grandma  ',
        dob: DateTime.utc(1940),
        sex: PatientSex.female,
        timezone: 'Asia/Kolkata',
        creatorUid: 'uid-1',
      );
      expect(result.isSuccess, isTrue);
      final patient = result.valueOrNull!;
      expect(patient.displayName, 'Grandma');
      expect(patient.guardianUids, {'uid-1'});
      expect(patient.linkedUserUid, isNull);
    });
  });

  group('createLinkCode', () {
    test('rejects an empty permission set', () async {
      final result = await service.createLinkCode(
        patientId: 'p1',
        creatorUid: 'uid-1',
        requesterPermissions: GuardianPermission.defaults,
        permissions: const {},
      );
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'field', 'permissions'),
      );
    });

    test(
        'a guardian can never hand out a permission they do not themselves '
        'hold', () async {
      final result = await service.createLinkCode(
        patientId: 'p1',
        creatorUid: 'uid-1',
        requesterPermissions: const {GuardianPermission.viewMedications},
        permissions: const {GuardianPermission.manageMedications},
      );
      expect(
        result.failureOrNull,
        isA<PermissionDeniedFailure>(),
      );
    });

    test('issues a code when requested permissions are a subset of the '
        "requester's own", () async {
      final result = await service.createLinkCode(
        patientId: 'p1',
        creatorUid: 'uid-1',
        requesterPermissions: const {
          GuardianPermission.viewMedications,
          GuardianPermission.manageMedications,
        },
        permissions: const {GuardianPermission.viewMedications},
      );
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.permissions, {GuardianPermission.viewMedications});
    });
  });

  group('redeemLinkCode', () {
    test('rejects an empty code without calling the backend', () async {
      final result =
          await service.redeemLinkCode(code: '   ', guardianUid: 'uid-2');
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'field', 'code'),
      );
    });

    test('normalizes the code to uppercase and trims whitespace', () async {
      relationships.seedCode(
        PatientLinkCode(
          code: 'ABC234',
          patientId: 'p1',
          createdByUid: 'uid-1',
          permissions: GuardianPermission.defaults,
          expiresAt: DateTime.utc(2100),
        ),
      );
      final result = await service.redeemLinkCode(
        code: '  abc234  ',
        guardianUid: 'uid-2',
      );
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.status, RelationshipStatus.pending);
    });

    test('redemption alone never activates the relationship', () async {
      relationships.seedCode(
        PatientLinkCode(
          code: 'ABC234',
          patientId: 'p1',
          createdByUid: 'uid-1',
          permissions: GuardianPermission.defaults,
          expiresAt: DateTime.utc(2100),
        ),
      );
      final result = await service.redeemLinkCode(
        code: 'ABC234',
        guardianUid: 'uid-2',
      );
      expect(result.valueOrNull!.isActive, isFalse);
    });
  });

  group('approve / reject / revoke', () {
    late String relationshipId;

    setUp(() async {
      relationships.seedCode(
        PatientLinkCode(
          code: 'ABC234',
          patientId: 'p1',
          createdByUid: 'uid-1',
          permissions: GuardianPermission.defaults,
          expiresAt: DateTime.utc(2100),
        ),
      );
      final redeemed = await service.redeemLinkCode(
        code: 'ABC234',
        guardianUid: 'uid-2',
      );
      relationshipId = redeemed.valueOrNull!.id;
    });

    test('approve moves a PENDING relationship to ACTIVE', () async {
      final result = await service.approveRelationship(
        relationshipId: relationshipId,
        responderUid: 'uid-1',
      );
      expect(result.isSuccess, isTrue);
      expect(relationships.relationshipOf(relationshipId)!.isActive, isTrue);
    });

    test('reject moves a PENDING relationship to REJECTED, not ACTIVE',
        () async {
      await service.rejectRelationship(
        relationshipId: relationshipId,
        responderUid: 'uid-1',
      );
      final relationship = relationships.relationshipOf(relationshipId)!;
      expect(relationship.status, RelationshipStatus.rejected);
      expect(relationship.isActive, isFalse);
    });

    test('revoke moves an ACTIVE relationship to REVOKED', () async {
      await service.approveRelationship(
        relationshipId: relationshipId,
        responderUid: 'uid-1',
      );
      await service.revokeRelationship(
        relationshipId: relationshipId,
        actorUid: 'uid-1',
      );
      final relationship = relationships.relationshipOf(relationshipId)!;
      expect(relationship.status, RelationshipStatus.revoked);
      expect(relationship.has(GuardianPermission.viewMedications), isFalse);
    });
  });
}
