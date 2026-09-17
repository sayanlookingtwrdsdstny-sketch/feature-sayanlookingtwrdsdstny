import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/domain/auth_repositories.dart';

/// [AuthRepository] backed by Firebase Authentication.
///
/// The only file in the app that touches `firebase_auth`. Every Firebase
/// exception is converted here, so nothing above the data layer ever handles
/// a raw SDK error.
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final fb.FirebaseAuth _auth;

  @override
  Stream<AuthUser?> userChanges() => _auth.userChanges().map(_toDomain);

  @override
  AuthUser? get currentUser => _toDomain(_auth.currentUser);

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _toDomain(credential.user)!;
      });

  @override
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user!;
        await user.updateDisplayName(displayName);
        await user.reload();
        return _toDomain(_auth.currentUser ?? user)!;
      });

  @override
  Future<Result<void>> sendEmailVerification() => _guard(() async {
        final user = _auth.currentUser;
        if (user == null) throw const _NoUser();
        await user.sendEmailVerification();
      });

  @override
  Future<Result<void>> sendPasswordReset({required String email}) async {
    final result = await _guard(
      () => _auth.sendPasswordResetEmail(email: email),
    );
    // An unknown address is reported as success so the UI cannot be used to
    // test which emails have accounts.
    if (result case Failure(failure: ValidationFailure(field: 'credentials'))) {
      return const Success(null);
    }
    return result;
  }

  @override
  Future<Result<AuthUser?>> reloadUser() => _guard(() async {
        await _auth.currentUser?.reload();
        return _toDomain(_auth.currentUser);
      });

  @override
  Future<Result<void>> signOut() => _guard(_auth.signOut);

  static AuthUser? _toDomain(fb.User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email ?? '',
          emailVerified: user.emailVerified,
          displayName: user.displayName,
        );

  static Future<Result<T>> _guard<T>(Future<T> Function() action) =>
      guardAsync(
        action,
        onError: (error, stack) => switch (error) {
          fb.FirebaseAuthException(:final code) =>
            AuthErrorMapper.fromAuthCode(code, cause: error, stackTrace: stack),
          _NoUser() =>
            AppFailure.unauthenticated(cause: error, stackTrace: stack),
          _ => AppFailure.unexpected(cause: error, stackTrace: stack),
        },
      );
}

final class _NoUser implements Exception {
  const _NoUser();
}
