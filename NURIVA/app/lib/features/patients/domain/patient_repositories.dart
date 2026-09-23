import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';

/// Patient records and the guardian relationships that authorize access to
/// them. The Firestore implementation lives in `data/`; tests use an
/// in-memory fake.
abstract interface class PatientRepository {
  /// The signed-in user's own patient record (`patients/{uid}`), or `null`
  /// if they have not been set up as a patient (or aren't one).
  Stream<Patient?> watchSelfPatient(String uid);

  /// Patients this user guards, via an ACTIVE [GuardianRelationship].
  /// Ordered newest-linked first is not guaranteed — callers sort as needed.
  Stream<List<Patient>> watchGuardianPatients(String guardianUid);

  Future<Result<Patient?>> getPatient(String patientId);

  /// Creates `patients/{uid}` for the signed-in user, linking it to
  /// themselves. Idempotent — a second call for the same [uid] returns the
  /// existing record rather than failing, so it is safe to call on every
  /// app open without first checking existence.
  Future<Result<Patient>> ensureSelfPatient({
    required String uid,
    required String displayName,
    required String timezone,
  });

  /// Creates a new patient record for someone the caller cares for, and in
  /// the same atomic write makes the caller its primary, ACTIVE guardian
  /// with every permission. There is no invite step for the creator — they
  /// already have full access to a patient they just created.
  Future<Result<Patient>> createManagedPatient({
    required String displayName,
    required DateTime dob,
    required PatientSex sex,
    required String timezone,
    required String creatorUid,
  });
}

abstract interface class GuardianRelationshipRepository {
  /// Every relationship on a patient — active, pending, and (for the
  /// history a primary guardian sees) rejected/revoked.
  Stream<List<GuardianRelationship>> watchRelationshipsForPatient(
    String patientId,
  );

  /// This caller's own relationship to a patient, or `null` if none exists
  /// yet. Used to check "am I already a guardian here" before redeeming a
  /// code, and to gate the invite/manage UI on the caller's own status.
  Stream<GuardianRelationship?> watchMyRelationship({
    required String patientId,
    required String guardianUid,
  });

  /// Generates a 6-character, 24-hour, single-use invite code. [permissions]
  /// must be a subset of the creator's own — Rules enforce this too, but
  /// checking client-side gives an immediate, specific error.
  Future<Result<PatientLinkCode>> createLinkCode({
    required String patientId,
    required String creatorUid,
    required Set<GuardianPermission> permissions,
  });

  /// Redeems [code] as [guardianUid], creating a PENDING relationship.
  /// Redemption alone never grants access — the primary guardian must still
  /// call [respondToRelationship]. Runs as a single Firestore transaction:
  /// validates the code (exists, unexpired, unconsumed), that the caller
  /// isn't already a guardian of that patient, and that the patient is not
  /// archived, then atomically marks the code consumed and creates the
  /// relationship.
  Future<Result<GuardianRelationship>> redeemLinkCode({
    required String code,
    required String guardianUid,
  });

  /// Approves or rejects a PENDING relationship. Only the patient's primary
  /// guardian may call this — Rules are the real enforcement; this is the
  /// client-side use case.
  Future<Result<void>> respondToRelationship({
    required String relationshipId,
    required bool approve,
    required String responderUid,
  });

  /// Revokes an ACTIVE relationship — either the primary guardian revoking
  /// someone else, or a non-primary guardian revoking themselves ("leave").
  /// A primary guardian cannot revoke their own relationship this way; the
  /// patient would be left without one.
  Future<Result<void>> revokeRelationship({
    required String relationshipId,
    required String actorUid,
  });
}
