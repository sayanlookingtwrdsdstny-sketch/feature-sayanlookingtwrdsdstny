import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/domain/patient_repositories.dart';

/// [PatientRepository] backed by Cloud Firestore.
///
/// `patients/{uid}` is used for a self-managed patient — deterministic on
/// the user's own uid, so "does this user already have a self patient
/// record" is a single `get()`/`.doc(uid)` rather than a query, and a second
/// self-record can never be created by accident. This is a deliberate
/// simplification from ARCHITECTURE §4's generic auto-ID `patientId`,
/// recorded in ARCHITECTURE §18 — guardian-created patients still get a
/// generated ID, since there is no analogous one-per-user constraint there.
final class FirestorePatientRepository implements PatientRepository {
  FirestorePatientRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String patientId) =>
      _db.doc(FirestorePaths.patient(patientId));

  @override
  Stream<Patient?> watchSelfPatient(String uid) =>
      _doc(uid).snapshots().map((snap) {
        final data = snap.data();
        return (snap.exists && data != null) ? _fromMap(uid, data) : null;
      });

  @override
  Stream<List<Patient>> watchGuardianPatients(String guardianUid) =>
      // Not an array-contains query on patients.guardianUids: that field is
      // written once at creation and never updated after (there is no
      // Cloud Function to keep it in sync, and no client update rule for
      // it — see ARCHITECTURE §18), so it only ever lists the creator, not
      // a guardian added later via an approved invite. Deriving from ACTIVE
      // relationships instead is correct for everyone, at the cost of
      // re-fetching each patient by ID on every relationship-set change
      // rather than getting live per-patient updates — an acceptable MVP
      // trade for a care circle of a handful of patients.
      _db
          .collection(FirestorePaths.guardianRelationships)
          .where('guardianUid', isEqualTo: guardianUid)
          .where('status', isEqualTo: RelationshipStatus.active.wire)
          .snapshots()
          .asyncMap((query) async {
        final patientIds = query.docs
            .map((d) => d.data()['patientId'] as String?)
            .whereType<String>()
            .toSet();
        if (patientIds.isEmpty) return const <Patient>[];
        final snaps = await Future.wait(patientIds.map(_doc).map((r) => r.get()));
        return [
          for (final snap in snaps)
            if (snap.exists && snap.data() != null) _fromMap(snap.id, snap.data()!),
        ];
      });

  @override
  Future<Result<Patient?>> getPatient(String patientId) => guardAsync(
        () async {
          final snap = await _doc(patientId).get();
          final data = snap.data();
          return (snap.exists && data != null)
              ? _fromMap(patientId, data)
              : null;
        },
        onError: _mapFirestoreError,
      );

  @override
  Future<Result<Patient>> ensureSelfPatient({
    required String uid,
    required String displayName,
    required String timezone,
  }) =>
      guardAsync(
        () => _db.runTransaction<Patient>((txn) async {
          final ref = _doc(uid);
          final existing = await txn.get(ref);
          final existingData = existing.data();
          if (existing.exists && existingData != null) {
            return _fromMap(uid, existingData);
          }

          final data = <String, dynamic>{
            'displayName': displayName,
            'dob': null,
            'sex': PatientSex.unspecified.wire,
            'timezone': timezone,
            'linkedUserUid': uid,
            'createdByUid': uid,
            'guardianUids': <String>[],
            'graceMinutes': 30,
            'escalationMinutes': 30,
            'archived': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          txn.set(ref, data);
          return Patient(
            id: uid,
            displayName: displayName,
            dob: DateTime.fromMillisecondsSinceEpoch(0),
            sex: PatientSex.unspecified,
            timezone: timezone,
            createdByUid: uid,
            guardianUids: const {},
            linkedUserUid: uid,
          );
        }),
        onError: _mapFirestoreError,
      );

  @override
  Future<Result<Patient>> createManagedPatient({
    required String displayName,
    required DateTime dob,
    required PatientSex sex,
    required String timezone,
    required String creatorUid,
  }) =>
      guardAsync(
        () async {
          // Two sequential writes, not a batch. Security Rules' get() cannot
          // see a sibling write from the same batch/transaction — the
          // relationship-create rule proves the caller owns this patient by
          // reading its already-committed createdByUid, which requires the
          // patient to exist first. If the app dies between these two
          // awaits, the patient is created but has no guardian yet — nobody
          // (including its creator) can read it, since patients-read
          // requires an ACTIVE relationship. Rare (only a mid-write crash or
          // total network loss) and self-contained: no orphaned access, just
          // an orphaned document a later cleanup pass could sweep.
          final patientRef = _db.collection(FirestorePaths.patients).doc();
          await patientRef.set({
            'displayName': displayName,
            'dob': Timestamp.fromDate(dob),
            'sex': sex.wire,
            'timezone': timezone,
            'linkedUserUid': null,
            'createdByUid': creatorUid,
            'guardianUids': [creatorUid],
            'graceMinutes': 30,
            'escalationMinutes': 30,
            'archived': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final relationshipRef = _db.doc(
            FirestorePaths.guardianRelationship(
              patientId: patientRef.id,
              guardianUid: creatorUid,
            ),
          );
          await relationshipRef.set({
            'patientId': patientRef.id,
            'guardianUid': creatorUid,
            'isPrimary': true,
            'status': RelationshipStatus.active.wire,
            'permissions':
                GuardianPermission.values.map((p) => p.wire).toList(),
            'invitedByUid': creatorUid,
            'invitedAt': FieldValue.serverTimestamp(),
            'respondedAt': FieldValue.serverTimestamp(),
            'revokedAt': null,
          });

          return Patient(
            id: patientRef.id,
            displayName: displayName,
            dob: dob,
            sex: sex,
            timezone: timezone,
            createdByUid: creatorUid,
            guardianUids: {creatorUid},
          );
        },
        onError: _mapFirestoreError,
      );

  static AppFailure _mapFirestoreError(Object error, StackTrace stack) =>
      switch (error) {
        FirebaseException(:final code) =>
          AuthErrorMapper.fromFirestoreCode(code, cause: error, stackTrace: stack),
        _ => AppFailure.unexpected(cause: error, stackTrace: stack),
      };

  static Patient _fromMap(String id, Map<String, dynamic> data) {
    final dob = data['dob'];
    return Patient(
      id: id,
      displayName: (data['displayName'] as String?) ?? '',
      dob: dob is Timestamp
          ? dob.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      sex: PatientSex.fromWire((data['sex'] as String?) ?? ''),
      timezone: (data['timezone'] as String?) ?? 'UTC',
      linkedUserUid: data['linkedUserUid'] as String?,
      createdByUid: (data['createdByUid'] as String?) ?? '',
      guardianUids: {
        for (final raw in (data['guardianUids'] as List?) ?? const [])
          if (raw is String) raw,
      },
      graceMinutes: (data['graceMinutes'] as num?)?.toInt() ?? 30,
      escalationMinutes: (data['escalationMinutes'] as num?)?.toInt() ?? 30,
      archived: (data['archived'] as bool?) ?? false,
    );
  }
}
