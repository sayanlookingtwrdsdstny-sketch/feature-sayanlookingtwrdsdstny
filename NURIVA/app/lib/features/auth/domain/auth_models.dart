// Auth domain models. Pure Dart: no Flutter, no Firebase.

/// What a person uses NURIVA for.
///
/// A list rather than a single field (ARCHITECTURE §5): one person is often
/// both a patient managing their own medication and the guardian of a parent.
/// `DOCTOR` can be added later as a new value without an auth redesign.
enum UserRole {
  patient('PATIENT'),
  guardian('GUARDIAN');

  const UserRole(this.wire);

  /// The value stored in Firestore. Stable; never rename.
  final String wire;

  static UserRole? fromWire(String value) {
    for (final role in UserRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}

/// The signed-in account, as far as authentication knows it.
final class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  final String uid;
  final String email;
  final bool emailVerified;
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.emailVerified == emailVerified &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, email, emailVerified, displayName);
}

/// A record that the user agreed to NURIVA processing their health data.
///
/// Required by India's DPDP Act 2023: consent must be specific, informed and
/// given by a clear affirmative act, and NURIVA must be able to show which
/// notice was agreed to. [version] identifies that notice text.
final class ConsentRecord {
  const ConsentRecord({required this.version, this.acceptedAt});

  final String version;

  /// Server-assigned. `null` only on a record not yet written.
  final DateTime? acceptedAt;
}

/// The person's NURIVA profile, stored at `users/{uid}`.
final class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.roles,
    required this.consent,
  });

  final String uid;
  final String displayName;
  final String email;
  final Set<UserRole> roles;
  final ConsentRecord consent;

  bool get isPatient => roles.contains(UserRole.patient);
  bool get isGuardian => roles.contains(UserRole.guardian);

  /// First word of the display name, for friendly greetings.
  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

/// Where the user is in the sign-in lifecycle. Drives routing (§5).
sealed class AuthSession {
  const AuthSession();
}

/// Session not resolved yet. Shown as the splash.
final class SessionLoading extends AuthSession {
  const SessionLoading();
}

/// No account signed in.
final class SignedOut extends AuthSession {
  const SignedOut();
}

/// Signed in, but the email address has not been confirmed.
final class AwaitingVerification extends AuthSession {
  const AwaitingVerification(this.user);
  final AuthUser user;
}

/// Verified, but no profile document exists — registration was interrupted
/// between creating the account and saving the profile (e.g. network loss).
final class NeedsProfile extends AuthSession {
  const NeedsProfile(this.user);
  final AuthUser user;
}

/// Fully signed in.
final class SignedIn extends AuthSession {
  const SignedIn(this.user, this.profile);
  final AuthUser user;
  final UserProfile profile;
}

/// Signed in, but the profile could not be read. Shown with a retry rather
/// than guessing — sending the user to "complete profile" on a transient read
/// failure would ask them to re-enter details they already gave.
final class SessionUnavailable extends AuthSession {
  const SessionUnavailable(this.user);
  final AuthUser user;
}
