import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/domain/auth_repositories.dart';

/// [ProfileRepository] backed by Cloud Firestore at `users/{uid}`.
///
/// The document shape here must match `firestore.rules`, which rejects any
/// field not on its allow-list and requires server-assigned timestamps.
final class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _doc(uid).snapshots().map((snap) {
        final data = snap.data();
        return (snap.exists && data != null) ? _fromMap(uid, data) : null;
      });

  @override
  Future<Result<void>> createProfile({
    required String uid,
    required String email,
    required String displayName,
    required Set<UserRole> roles,
    required String consentVersion,
  }) =>
      guardAsync(
        () => _doc(uid).set({
          'uid': uid,
          'displayName': displayName,
          'email': email,
          'roles': roles.map((r) => r.wire).toList()..sort(),
          'consent': {
            'version': consentVersion,
            'acceptedAt': FieldValue.serverTimestamp(),
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        onError: (error, stack) => switch (error) {
          FirebaseException(:final code) => AuthErrorMapper.fromFirestoreCode(
              code,
              cause: error,
              stackTrace: stack,
            ),
          _ => AppFailure.unexpected(cause: error, stackTrace: stack),
        },
      );

  static UserProfile _fromMap(String uid, Map<String, dynamic> data) {
    final consent = data['consent'];
    final acceptedAt = consent is Map ? consent['acceptedAt'] : null;

    return UserProfile(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      roles: {
        for (final raw in (data['roles'] as List?) ?? const [])
          if (raw is String) ?UserRole.fromWire(raw),
      },
      consent: ConsentRecord(
        version: consent is Map ? (consent['version'] as String? ?? '') : '',
        // Null while a server timestamp is still pending on a local write.
        acceptedAt: acceptedAt is Timestamp ? acceptedAt.toDate() : null,
      ),
    );
  }
}
