import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/domain/patient_repositories.dart';

/// Care-circle use cases: creating patients, inviting and responding to
/// guardians, revoking access.
///
/// Orchestration lives here, not in widgets or the repositories — the same
/// split Module 02's `AccountService` uses. Pure Dart over the repository
/// interfaces, so every rule below is testable without Firebase.
final class CareCircleService {
  const CareCircleService({
    required this.patients,
    required this.relationships,
  });

  final PatientRepository patients;
  final GuardianRelationshipRepository relationships;

  /// Ensures the signed-in user has their own patient record. Safe to call
  /// unconditionally on every sign-in — idempotent at the repository layer.
  Future<Result<Patient>> ensureSelfPatient({
    required String uid,
    required String displayName,
    required String timezone,
  }) =>
      patients.ensureSelfPatient(
        uid: uid,
        displayName: displayName,
        timezone: timezone,
      );

  Future<Result<Patient>> createManagedPatient({
    required String displayName,
    required DateTime dob,
    required PatientSex sex,
    required String timezone,
    required String creatorUid,
  }) {
    final nameError = _validateName(displayName);
    if (nameError != null) {
      return Future.value(
        Failure(AppFailure.validation(field: 'displayName', reason: nameError)),
      );
    }
    if (dob.isAfter(DateTime.now())) {
      return Future.value(
        const Failure(
          AppFailure.validation(field: 'dob', reason: 'in_future'),
        ),
      );
    }
    return patients.createManagedPatient(
      displayName: displayName.trim(),
      dob: dob,
      sex: sex,
      timezone: timezone,
      creatorUid: creatorUid,
    );
  }

  /// Generates an invite code. [requesterPermissions] is what the inviter
  /// currently holds on this patient — [permissions] must be a subset, so a
  /// guardian can never hand out more access than they themselves have.
  Future<Result<PatientLinkCode>> createLinkCode({
    required String patientId,
    required String creatorUid,
    required Set<GuardianPermission> requesterPermissions,
    Set<GuardianPermission> permissions = GuardianPermission.defaults,
  }) {
    if (permissions.isEmpty) {
      return Future.value(
        const Failure(
          AppFailure.validation(field: 'permissions', reason: 'empty'),
        ),
      );
    }
    if (!permissions.every(requesterPermissions.contains)) {
      return Future.value(
        const Failure(
          AppFailure.permissionDenied(action: 'createLinkCode'),
        ),
      );
    }
    return relationships.createLinkCode(
      patientId: patientId,
      creatorUid: creatorUid,
      permissions: permissions,
    );
  }

  Future<Result<GuardianRelationship>> redeemLinkCode({
    required String code,
    required String guardianUid,
  }) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return Future.value(
        const Failure(
          AppFailure.validation(field: 'code', reason: 'empty'),
        ),
      );
    }
    return relationships.redeemLinkCode(
      code: normalized,
      guardianUid: guardianUid,
    );
  }

  Future<Result<void>> approveRelationship({
    required String relationshipId,
    required String responderUid,
  }) =>
      relationships.respondToRelationship(
        relationshipId: relationshipId,
        approve: true,
        responderUid: responderUid,
      );

  Future<Result<void>> rejectRelationship({
    required String relationshipId,
    required String responderUid,
  }) =>
      relationships.respondToRelationship(
        relationshipId: relationshipId,
        approve: false,
        responderUid: responderUid,
      );

  Future<Result<void>> revokeRelationship({
    required String relationshipId,
    required String actorUid,
  }) =>
      relationships.revokeRelationship(
        relationshipId: relationshipId,
        actorUid: actorUid,
      );

  String? _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'empty';
    if (trimmed.length > 60) return 'too_long';
    return null;
  }
}
