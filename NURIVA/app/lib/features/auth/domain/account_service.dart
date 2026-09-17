import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/domain/auth_repositories.dart';
import 'package:nuriva/features/auth/domain/auth_validators.dart';

/// The version of the privacy notice a user agrees to at registration.
///
/// Bump this whenever the notice text changes. Stored with each consent record
/// so NURIVA can show which notice a given user accepted (DPDP Act 2023).
const String kPrivacyNoticeVersion = '2026-09-15';

/// Account use cases.
///
/// Orchestration lives here, not in widgets: screens collect input and render
/// results; this decides what happens and in what order. Pure Dart over the
/// repository interfaces, so every path is testable without Firebase.
final class AccountService {
  const AccountService({
    required this.auth,
    required this.profiles,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    final invalid = AuthValidators.email(email) ??
        (password.isEmpty ? 'empty_password' : null);
    if (invalid != null) {
      return Failure(
        invalid == 'empty_password'
            ? const AppFailure.validation(field: 'password', reason: 'empty')
            : AppFailure.validation(field: 'email', reason: invalid),
      );
    }
    return auth.signIn(
      email: AuthValidators.normalizeEmail(email),
      password: password,
    );
  }

  /// Creates the account, saves the profile with consent, and sends the
  /// verification email.
  ///
  /// Consent is a precondition, not a field: the account is never created
  /// without it. If the profile write fails after the account exists, the
  /// account is kept and the session lands on "complete profile" rather than
  /// deleting a real account over a transient error.
  Future<Result<AuthUser>> register({
    required String displayName,
    required String email,
    required String password,
    required Set<UserRole> roles,
    required bool consentGiven,
  }) async {
    final validation = _validateRegistration(
      displayName: displayName,
      email: email,
      password: password,
      roles: roles,
      consentGiven: consentGiven,
    );
    if (validation != null) return Failure(validation);

    final created = await auth.register(
      email: AuthValidators.normalizeEmail(email),
      password: password,
      displayName: displayName.trim(),
    );

    switch (created) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(:final value):
        // Both follow-ups are best-effort: their failure must not undo a
        // successfully created account. The session model routes the user to
        // recovery screens (complete profile / resend verification).
        await profiles.createProfile(
          uid: value.uid,
          email: value.email,
          displayName: displayName.trim(),
          roles: roles,
          consentVersion: kPrivacyNoticeVersion,
        );
        await auth.sendEmailVerification();
        return Success(value);
    }
  }

  /// Saves a missing profile for an existing account (the recovery path).
  Future<Result<void>> completeProfile({
    required AuthUser user,
    required String displayName,
    required Set<UserRole> roles,
    required bool consentGiven,
  }) async {
    final nameError = AuthValidators.displayName(displayName);
    if (nameError != null) {
      return Failure(
        AppFailure.validation(field: 'displayName', reason: nameError),
      );
    }
    if (roles.isEmpty) {
      return const Failure(
        AppFailure.validation(field: 'roles', reason: 'empty'),
      );
    }
    if (!consentGiven) {
      return const Failure(
        AppFailure.validation(field: 'consent', reason: 'required'),
      );
    }
    return profiles.createProfile(
      uid: user.uid,
      email: user.email,
      displayName: displayName.trim(),
      roles: roles,
      consentVersion: kPrivacyNoticeVersion,
    );
  }

  Future<Result<void>> sendPasswordReset({required String email}) async {
    final invalid = AuthValidators.email(email);
    if (invalid != null) {
      return Failure(AppFailure.validation(field: 'email', reason: invalid));
    }
    return auth.sendPasswordReset(email: AuthValidators.normalizeEmail(email));
  }

  Future<Result<void>> resendVerification() => auth.sendEmailVerification();

  /// Reloads the user and reports whether the email is now verified.
  Future<Result<bool>> checkVerified() async {
    final reloaded = await auth.reloadUser();
    return reloaded.map((user) => user?.emailVerified ?? false);
  }

  Future<Result<void>> signOut() => auth.signOut();

  AppFailure? _validateRegistration({
    required String displayName,
    required String email,
    required String password,
    required Set<UserRole> roles,
    required bool consentGiven,
  }) {
    final nameError = AuthValidators.displayName(displayName);
    if (nameError != null) {
      return AppFailure.validation(field: 'displayName', reason: nameError);
    }
    final emailError = AuthValidators.email(email);
    if (emailError != null) {
      return AppFailure.validation(field: 'email', reason: emailError);
    }
    final passwordError = AuthValidators.password(password);
    if (passwordError != null) {
      return AppFailure.validation(field: 'password', reason: passwordError);
    }
    if (roles.isEmpty) {
      return const AppFailure.validation(field: 'roles', reason: 'empty');
    }
    if (!consentGiven) {
      return const AppFailure.validation(field: 'consent', reason: 'required');
    }
    return null;
  }
}
