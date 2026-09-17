import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

/// Authentication operations. The app depends on this interface; the Firebase
/// implementation lives in `data/` and tests use an in-memory fake.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out, and whenever the user record changes —
  /// including after [reloadUser], which is how email verification is noticed.
  Stream<AuthUser?> userChanges();

  AuthUser? get currentUser;

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });

  /// Creates the account and sets its display name.
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<void>> sendEmailVerification();

  /// Always reports success for a well-formed address, whether or not an
  /// account exists — revealing which emails are registered is an
  /// account-enumeration leak.
  Future<Result<void>> sendPasswordReset({required String email});

  /// Refreshes the user record from the server (e.g. to pick up verification).
  Future<Result<AuthUser?>> reloadUser();

  Future<Result<void>> signOut();
}

/// Profile persistence at `users/{uid}`.
abstract interface class ProfileRepository {
  /// Emits `null` when no profile exists.
  Stream<UserProfile?> watchProfile(String uid);

  /// Creates the profile. Consent time is assigned by the server.
  Future<Result<void>> createProfile({
    required String uid,
    required String email,
    required String displayName,
    required Set<UserRole> roles,
    required String consentVersion,
  });
}
