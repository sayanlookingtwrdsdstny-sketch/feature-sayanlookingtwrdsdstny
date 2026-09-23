import 'dart:async';

import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/domain/patient_repositories.dart';

/// In-memory patient store. **Tests only.**
final class FakePatientRepository implements PatientRepository {
  final Map<String, Patient> _byId = {};
  final StreamController<String> _changed = StreamController.broadcast();
  int _nextId = 1;

  AppFailure? nextFailure;

  void seed(Patient patient) {
    _byId[patient.id] = patient;
    _changed.add(patient.id);
  }

  Patient? patientOf(String id) => _byId[id];

  Result<T>? _consumeFailure<T>() {
    final failure = nextFailure;
    if (failure == null) return null;
    nextFailure = null;
    return Failure<T>(failure);
  }

  @override
  Stream<Patient?> watchSelfPatient(String uid) => Stream.multi((controller) {
        Patient? selfOf(String uid) {
          for (final p in _byId.values) {
            if (p.linkedUserUid == uid) return p;
          }
          return null;
        }

        controller.add(selfOf(uid));
        final sub = _changed.stream.listen((_) => controller.add(selfOf(uid)));
        controller.onCancel = sub.cancel;
      });

  @override
  Stream<List<Patient>> watchGuardianPatients(String guardianUid) =>
      Stream.multi((controller) {
        List<Patient> guardedBy(String uid) => _byId.values
            .where((p) => p.guardianUids.contains(uid))
            .toList();

        controller.add(guardedBy(guardianUid));
        final sub =
            _changed.stream.listen((_) => controller.add(guardedBy(guardianUid)));
        controller.onCancel = sub.cancel;
      });

  @override
  Future<Result<Patient?>> getPatient(String patientId) async {
    final injected = _consumeFailure<Patient?>();
    if (injected != null) return injected;
    return Success(_byId[patientId]);
  }

  @override
  Future<Result<Patient>> ensureSelfPatient({
    required String uid,
    required String displayName,
    required String timezone,
  }) async {
    final injected = _consumeFailure<Patient>();
    if (injected != null) return injected;

    for (final p in _byId.values) {
      if (p.linkedUserUid == uid) return Success(p);
    }
    final patient = Patient(
      id: uid,
      displayName: displayName,
      dob: DateTime.utc(1970),
      sex: PatientSex.unspecified,
      timezone: timezone,
      createdByUid: uid,
      guardianUids: {uid},
      linkedUserUid: uid,
    );
    seed(patient);
    return Success(patient);
  }

  @override
  Future<Result<Patient>> createManagedPatient({
    required String displayName,
    required DateTime dob,
    required PatientSex sex,
    required String timezone,
    required String creatorUid,
  }) async {
    final injected = _consumeFailure<Patient>();
    if (injected != null) return injected;

    final patient = Patient(
      id: 'patient-${_nextId++}',
      displayName: displayName,
      dob: dob,
      sex: sex,
      timezone: timezone,
      createdByUid: creatorUid,
      guardianUids: {creatorUid},
    );
    seed(patient);
    return Success(patient);
  }
}

/// In-memory guardian-relationship store. **Tests only.**
final class FakeGuardianRelationshipRepository
    implements GuardianRelationshipRepository {
  final Map<String, GuardianRelationship> _byId = {};
  final Map<String, PatientLinkCode> _codes = {};
  final StreamController<String> _changed = StreamController.broadcast();
  int _nextId = 1;

  AppFailure? nextFailure;

  void seedRelationship(GuardianRelationship relationship) {
    _byId[relationship.id] = relationship;
    _changed.add(relationship.patientId);
  }

  void seedCode(PatientLinkCode code) => _codes[code.code] = code;

  GuardianRelationship? relationshipOf(String id) => _byId[id];

  Result<T>? _consumeFailure<T>() {
    final failure = nextFailure;
    if (failure == null) return null;
    nextFailure = null;
    return Failure<T>(failure);
  }

  @override
  Stream<List<GuardianRelationship>> watchRelationshipsForPatient(
    String patientId,
  ) =>
      Stream.multi((controller) {
        List<GuardianRelationship> forPatient() => _byId.values
            .where((r) => r.patientId == patientId)
            .toList();

        controller.add(forPatient());
        final sub = _changed.stream
            .where((p) => p == patientId)
            .listen((_) => controller.add(forPatient()));
        controller.onCancel = sub.cancel;
      });

  @override
  Stream<GuardianRelationship?> watchMyRelationship({
    required String patientId,
    required String guardianUid,
  }) =>
      Stream.multi((controller) {
        GuardianRelationship? mine() {
          for (final r in _byId.values) {
            if (r.patientId == patientId && r.guardianUid == guardianUid) {
              return r;
            }
          }
          return null;
        }

        controller.add(mine());
        final sub = _changed.stream
            .where((p) => p == patientId)
            .listen((_) => controller.add(mine()));
        controller.onCancel = sub.cancel;
      });

  @override
  Future<Result<PatientLinkCode>> createLinkCode({
    required String patientId,
    required String creatorUid,
    required Set<GuardianPermission> permissions,
  }) async {
    final injected = _consumeFailure<PatientLinkCode>();
    if (injected != null) return injected;

    final code = PatientLinkCode(
      code: 'CODE${_nextId++}',
      patientId: patientId,
      createdByUid: creatorUid,
      permissions: permissions,
      expiresAt: DateTime.utc(2100),
    );
    _codes[code.code] = code;
    return Success(code);
  }

  @override
  Future<Result<GuardianRelationship>> redeemLinkCode({
    required String code,
    required String guardianUid,
  }) async {
    final injected = _consumeFailure<GuardianRelationship>();
    if (injected != null) return injected;

    final linkCode = _codes[code];
    if (linkCode == null) {
      return const Failure(AppFailure.notFound(entity: 'linkCode'));
    }
    if (!linkCode.isRedeemableAt(DateTime.utc(2026))) {
      return const Failure(
        AppFailure.validation(field: 'code', reason: 'not_redeemable'),
      );
    }
    final relationship = GuardianRelationship(
      id: 'rel-${_nextId++}',
      patientId: linkCode.patientId,
      guardianUid: guardianUid,
      isPrimary: false,
      status: RelationshipStatus.pending,
      permissions: linkCode.permissions,
      invitedByUid: linkCode.createdByUid,
      invitedAt: DateTime.utc(2026),
    );
    _codes[code] = PatientLinkCode(
      code: linkCode.code,
      patientId: linkCode.patientId,
      createdByUid: linkCode.createdByUid,
      permissions: linkCode.permissions,
      expiresAt: linkCode.expiresAt,
      consumedByUid: guardianUid,
      consumedAt: DateTime.utc(2026),
    );
    seedRelationship(relationship);
    return Success(relationship);
  }

  @override
  Future<Result<void>> respondToRelationship({
    required String relationshipId,
    required bool approve,
    required String responderUid,
  }) async {
    final injected = _consumeFailure<void>();
    if (injected != null) return injected;

    final relationship = _byId[relationshipId];
    if (relationship == null) {
      return const Failure(AppFailure.notFound(entity: 'relationship'));
    }
    seedRelationship(
      GuardianRelationship(
        id: relationship.id,
        patientId: relationship.patientId,
        guardianUid: relationship.guardianUid,
        isPrimary: relationship.isPrimary,
        status: approve
            ? RelationshipStatus.active
            : RelationshipStatus.rejected,
        permissions: relationship.permissions,
        invitedByUid: relationship.invitedByUid,
        invitedAt: relationship.invitedAt,
        respondedAt: DateTime.utc(2026),
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> revokeRelationship({
    required String relationshipId,
    required String actorUid,
  }) async {
    final injected = _consumeFailure<void>();
    if (injected != null) return injected;

    final relationship = _byId[relationshipId];
    if (relationship == null) {
      return const Failure(AppFailure.notFound(entity: 'relationship'));
    }
    seedRelationship(
      GuardianRelationship(
        id: relationship.id,
        patientId: relationship.patientId,
        guardianUid: relationship.guardianUid,
        isPrimary: relationship.isPrimary,
        status: RelationshipStatus.revoked,
        permissions: relationship.permissions,
        invitedByUid: relationship.invitedByUid,
        invitedAt: relationship.invitedAt,
        respondedAt: relationship.respondedAt,
        revokedAt: DateTime.utc(2026),
      ),
    );
    return const Success(null);
  }
}
