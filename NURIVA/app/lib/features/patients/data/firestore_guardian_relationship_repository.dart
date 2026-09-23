import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/core/time/clock.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/patients/domain/link_code_generator.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/domain/patient_repositories.dart';

/// [GuardianRelationshipRepository] backed by Cloud Firestore.
///
/// Code redemption is a client-side Firestore transaction rather than a
/// Cloud Function (a deliberate deviation from ARCHITECTURE §6 — recorded in
/// §18 — made to stay on the Spark plan; Functions require Blaze to deploy
/// at all). Atomicity is real: `runTransaction` guarantees the code-consume
/// and relationship-create either both happen or neither does. What a
/// Function would add on top is server-only business logic Rules cannot
/// express — none of the checks here need that, since every one of them is a
/// simple field comparison Rules can also enforce independently.
final class FirestoreGuardianRelationshipRepository
    implements GuardianRelationshipRepository {
  FirestoreGuardianRelationshipRepository(this._db, this._clock);

  final FirebaseFirestore _db;
  final Clock _clock;

  static const _linkCodeValidity = Duration(hours: 24);
  static const _maxCodeGenerationAttempts = 5;

  CollectionReference<Map<String, dynamic>> get _relationships =>
      _db.collection(FirestorePaths.guardianRelationships);

  @override
  Stream<List<GuardianRelationship>> watchRelationshipsForPatient(
    String patientId,
  ) =>
      _relationships
          .where('patientId', isEqualTo: patientId)
          .snapshots()
          .map((q) => q.docs.map((d) => _fromMap(d.id, d.data())).toList());

  @override
  Stream<GuardianRelationship?> watchMyRelationship({
    required String patientId,
    required String guardianUid,
  }) =>
      _db
          .doc(
            FirestorePaths.guardianRelationship(
              patientId: patientId,
              guardianUid: guardianUid,
            ),
          )
          .snapshots()
          .map((snap) {
        final data = snap.data();
        return (snap.exists && data != null) ? _fromMap(snap.id, data) : null;
      });

  @override
  Future<Result<PatientLinkCode>> createLinkCode({
    required String patientId,
    required String creatorUid,
    required Set<GuardianPermission> permissions,
  }) =>
      guardAsync(() async {
        final expiresAt = _clock.nowUtc().add(_linkCodeValidity);

        // Astronomically unlikely to collide (32^6 codes), but a link code
        // is meant to be shared out loud, and reusing a stale document ID
        // silently would be a real bug — so check, not just hope.
        for (var attempt = 0; attempt < _maxCodeGenerationAttempts; attempt++) {
          final code = LinkCodeGenerator.generate();
          final ref = _db.doc(FirestorePaths.patientLinkCode(code));
          final existing = await ref.get();
          if (existing.exists) continue;

          await ref.set({
            'patientId': patientId,
            'createdByUid': creatorUid,
            'permissions': permissions.map((p) => p.wire).toList(),
            'expiresAt': Timestamp.fromDate(expiresAt),
            'consumedByUid': null,
            'consumedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
          });

          return PatientLinkCode(
            code: code,
            patientId: patientId,
            createdByUid: creatorUid,
            permissions: permissions,
            expiresAt: expiresAt,
          );
        }
        throw StateError('link_code_generation_exhausted');
      }, onError: _mapFirestoreError);

  @override
  Future<Result<GuardianRelationship>> redeemLinkCode({
    required String code,
    required String guardianUid,
  }) =>
      guardAsync(
        () => _db.runTransaction<GuardianRelationship>((txn) async {
          final codeRef = _db.doc(FirestorePaths.patientLinkCode(code));
          final codeSnap = await txn.get(codeRef);
          final codeData = codeSnap.data();
          if (!codeSnap.exists || codeData == null) {
            throw const _LinkCodeInvalid();
          }

          final expiresAt = (codeData['expiresAt'] as Timestamp?)?.toDate();
          final consumedByUid = codeData['consumedByUid'] as String?;
          if (expiresAt == null || _clock.nowUtc().isAfter(expiresAt)) {
            throw const _LinkCodeExpired();
          }
          if (consumedByUid != null) {
            throw const _LinkCodeConsumed();
          }

          final patientId = codeData['patientId'] as String;
          final relationshipRef = _db.doc(
            FirestorePaths.guardianRelationship(
              patientId: patientId,
              guardianUid: guardianUid,
            ),
          );
          final existingRelationship = await txn.get(relationshipRef);
          final existingData = existingRelationship.data();
          if (existingRelationship.exists && existingData != null) {
            final status = RelationshipStatus.fromWire(
              existingData['status'] as String? ?? '',
            );
            if (status == RelationshipStatus.active ||
                status == RelationshipStatus.pending) {
              throw const _AlreadyGuardian();
            }
          }

          final patientRef = _db.doc(FirestorePaths.patient(patientId));
          final patientSnap = await txn.get(patientRef);
          final patientData = patientSnap.data();
          if (!patientSnap.exists ||
              patientData == null ||
              (patientData['archived'] as bool? ?? false)) {
            throw const _LinkCodeInvalid();
          }

          final permissions = {
            for (final raw in (codeData['permissions'] as List?) ?? const [])
              if (raw is String) ?GuardianPermission.fromWire(raw),
          };

          txn
            ..update(codeRef, {
              'consumedByUid': guardianUid,
              'consumedAt': FieldValue.serverTimestamp(),
            })
            ..set(relationshipRef, {
              'patientId': patientId,
              'guardianUid': guardianUid,
              'isPrimary': false,
              'status': RelationshipStatus.pending.wire,
              'permissions': permissions.map((p) => p.wire).toList(),
              'invitedByUid': codeData['createdByUid'],
              'invitedAt': FieldValue.serverTimestamp(),
              'respondedAt': null,
              'revokedAt': null,
            });

          return GuardianRelationship(
            id: relationshipRef.id,
            patientId: patientId,
            guardianUid: guardianUid,
            isPrimary: false,
            status: RelationshipStatus.pending,
            permissions: permissions,
            invitedByUid: codeData['createdByUid'] as String,
            invitedAt: _clock.nowUtc(),
          );
        }),
        onError: (error, stack) => switch (error) {
          _LinkCodeInvalid() => AppFailure.notFound(
              entity: 'linkCode',
              cause: error,
              stackTrace: stack,
            ),
          _LinkCodeExpired() => AppFailure.conflict(
              reason: 'link_code_expired',
              cause: error,
              stackTrace: stack,
            ),
          _LinkCodeConsumed() => AppFailure.conflict(
              reason: 'link_code_consumed',
              cause: error,
              stackTrace: stack,
            ),
          _AlreadyGuardian() => AppFailure.conflict(
              reason: 'already_guardian',
              cause: error,
              stackTrace: stack,
            ),
          _ => _mapFirestoreError(error, stack),
        },
      );

  @override
  Future<Result<void>> respondToRelationship({
    required String relationshipId,
    required bool approve,
    required String responderUid,
  }) =>
      guardAsync(
        () => _relationships.doc(relationshipId).update({
          'status': (approve
                  ? RelationshipStatus.active
                  : RelationshipStatus.rejected)
              .wire,
          'respondedAt': FieldValue.serverTimestamp(),
        }),
        onError: _mapFirestoreError,
      );

  @override
  Future<Result<void>> revokeRelationship({
    required String relationshipId,
    required String actorUid,
  }) =>
      guardAsync(
        () => _relationships.doc(relationshipId).update({
          'status': RelationshipStatus.revoked.wire,
          'revokedAt': FieldValue.serverTimestamp(),
        }),
        onError: _mapFirestoreError,
      );

  static AppFailure _mapFirestoreError(Object error, StackTrace stack) =>
      switch (error) {
        FirebaseException(:final code) => AuthErrorMapper.fromFirestoreCode(
            code,
            cause: error,
            stackTrace: stack,
          ),
        _ => AppFailure.unexpected(cause: error, stackTrace: stack),
      };

  static GuardianRelationship _fromMap(String id, Map<String, dynamic> data) {
    final invitedAt = data['invitedAt'];
    final respondedAt = data['respondedAt'];
    final revokedAt = data['revokedAt'];
    return GuardianRelationship(
      id: id,
      patientId: (data['patientId'] as String?) ?? '',
      guardianUid: (data['guardianUid'] as String?) ?? '',
      isPrimary: (data['isPrimary'] as bool?) ?? false,
      status: RelationshipStatus.fromWire((data['status'] as String?) ?? ''),
      permissions: {
        for (final raw in (data['permissions'] as List?) ?? const [])
          if (raw is String) ?GuardianPermission.fromWire(raw),
      },
      invitedByUid: (data['invitedByUid'] as String?) ?? '',
      invitedAt: invitedAt is Timestamp ? invitedAt.toDate() : null,
      respondedAt: respondedAt is Timestamp ? respondedAt.toDate() : null,
      revokedAt: revokedAt is Timestamp ? revokedAt.toDate() : null,
    );
  }
}

final class _LinkCodeInvalid implements Exception {
  const _LinkCodeInvalid();
}

final class _LinkCodeExpired implements Exception {
  const _LinkCodeExpired();
}

final class _LinkCodeConsumed implements Exception {
  const _LinkCodeConsumed();
}

final class _AlreadyGuardian implements Exception {
  const _AlreadyGuardian();
}
