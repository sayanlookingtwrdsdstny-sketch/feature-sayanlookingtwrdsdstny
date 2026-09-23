/// Patient/guardian domain models. Pure Dart: no Flutter, no Firebase.
///
/// Four entities, deliberately separated (ARCHITECTURE §6):
/// - [Patient] — a person receiving medication. May or may not have a login.
/// - A [GuardianRelationship] — the authorization edge between a User and a
///   Patient.
/// - [GuardianPermission] — what that edge allows.
/// - [PatientLinkCode] — a short-lived, single-use invite onto that edge.
library;

/// Biological sex, as relevant to dosing (not a full gender model — this is a
/// medication app, not an identity system).
enum PatientSex {
  female('FEMALE'),
  male('MALE'),
  unspecified('UNSPECIFIED');

  const PatientSex(this.wire);

  final String wire;

  static PatientSex fromWire(String value) => switch (value) {
        'FEMALE' => PatientSex.female,
        'MALE' => PatientSex.male,
        _ => PatientSex.unspecified,
      };
}

/// A person receiving medication. Distinct from [User][UserProfile] on
/// purpose — an 82-year-old managed entirely by their daughter gets a
/// [Patient] record and no login at all.
final class Patient {
  const Patient({
    required this.id,
    required this.displayName,
    required this.dob,
    required this.sex,
    required this.timezone,
    required this.createdByUid,
    required this.guardianUids,
    this.linkedUserUid,
    this.graceMinutes = 30,
    this.escalationMinutes = 30,
    this.archived = false,
  });

  final String id;
  final String displayName;
  final DateTime dob;
  final PatientSex sex;

  /// IANA zone (e.g. `Asia/Kolkata`). Drives ALL scheduling once medications
  /// exist — not touched by this module, but fixed here so later modules
  /// never have to ask "whose timezone".
  final String timezone;

  final String createdByUid;

  /// Denormalized, for LISTING only. Never the authorization source — Rules
  /// and this app's own checks always go through [GuardianRelationship].
  final Set<String> guardianUids;

  /// Set only when this patient manages their own account. `null` for a
  /// guardian-managed patient with no login.
  final String? linkedUserUid;

  /// Minutes after a dose's scheduled time before it moves DUE -> MISSED.
  final int graceMinutes;

  /// Minutes after MISSED before guardians are alerted.
  final int escalationMinutes;

  final bool archived;

  /// Whether this patient record represents the signed-in user themselves.
  bool isSelfOf(String uid) => linkedUserUid == uid;
}

/// What a [GuardianRelationship] allows — five flags deliberately coarse
/// enough for a non-technical family member to reason about.
enum GuardianPermission {
  viewMedications('VIEW_MEDICATIONS'),
  manageMedications('MANAGE_MEDICATIONS'),
  viewAdherence('VIEW_ADHERENCE'),
  manageAppointments('MANAGE_APPOINTMENTS'),
  viewPrescriptions('VIEW_PRESCRIPTIONS');

  const GuardianPermission(this.wire);

  final String wire;

  static GuardianPermission? fromWire(String value) {
    for (final permission in GuardianPermission.values) {
      if (permission.wire == value) return permission;
    }
    return null;
  }

  /// Every permission a link code grants by default, when the inviter does
  /// not narrow the set. Excludes [manageMedications] — the permission that
  /// can activate a live dosing schedule is never handed out by default.
  static const Set<GuardianPermission> defaults = {
    viewMedications,
    viewAdherence,
  };
}

enum RelationshipStatus {
  pending('PENDING'),
  active('ACTIVE'),
  rejected('REJECTED'),
  revoked('REVOKED');

  const RelationshipStatus(this.wire);

  final String wire;

  static RelationshipStatus fromWire(String value) => switch (value) {
        'ACTIVE' => RelationshipStatus.active,
        'REJECTED' => RelationshipStatus.rejected,
        'REVOKED' => RelationshipStatus.revoked,
        _ => RelationshipStatus.pending,
      };
}

/// The authorization edge between a guardian [User] and a [Patient].
///
/// ID is deterministic — `{patientId}__{guardianUid}` — so Rules can
/// authorize with a single `get()` instead of a query (ARCHITECTURE §6).
final class GuardianRelationship {
  const GuardianRelationship({
    required this.id,
    required this.patientId,
    required this.guardianUid,
    required this.isPrimary,
    required this.status,
    required this.permissions,
    required this.invitedByUid,
    required this.invitedAt,
    this.respondedAt,
    this.revokedAt,
  });

  final String id;
  final String patientId;
  final String guardianUid;
  final bool isPrimary;
  final RelationshipStatus status;
  final Set<GuardianPermission> permissions;
  final String invitedByUid;
  final DateTime? invitedAt;
  final DateTime? respondedAt;
  final DateTime? revokedAt;

  bool get isActive => status == RelationshipStatus.active;
  bool get isPending => status == RelationshipStatus.pending;

  bool has(GuardianPermission permission) =>
      isActive && permissions.contains(permission);
}

/// A short-lived, single-use invite onto a [GuardianRelationship].
///
/// Redemption alone never grants access — it only creates a PENDING
/// relationship. A leaked code is therefore not by itself sufficient to
/// reach patient data; the primary guardian must still approve.
final class PatientLinkCode {
  const PatientLinkCode({
    required this.code,
    required this.patientId,
    required this.createdByUid,
    required this.permissions,
    required this.expiresAt,
    this.consumedByUid,
    this.consumedAt,
  });

  final String code;
  final String patientId;
  final String createdByUid;
  final Set<GuardianPermission> permissions;
  final DateTime expiresAt;
  final String? consumedByUid;
  final DateTime? consumedAt;

  bool get isConsumed => consumedByUid != null;

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  bool isRedeemableAt(DateTime now) => !isConsumed && !isExpiredAt(now);
}
