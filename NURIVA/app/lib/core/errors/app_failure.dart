/// Every way a NURIVA operation can fail.
///
/// Sealed so a `switch` must be exhaustive: when a new failure kind is added,
/// every site that maps failures to user-facing copy stops compiling until it
/// handles the new case. In a medication app, a silently unhandled failure is
/// a dose the user never hears about.
///
/// Failures carry a [code] for logs and a [cause]/[stackTrace] for diagnostics.
/// They deliberately do **not** carry user-facing copy — presentation decides
/// the wording, because the same failure reads differently to a patient and a
/// guardian, and copy must be localizable.
sealed class AppFailure {
  const AppFailure({this.cause, this.stackTrace});

  /// The underlying error, when one exists. Never shown to a user.
  final Object? cause;

  /// Where it came from. Never shown to a user.
  final StackTrace? stackTrace;

  /// Stable machine-readable identifier, safe to log.
  String get code;

  /// A short description for logs and bug reports. Never shown to a user and
  /// never interpolates patient data.
  String get debugMessage;

  const factory AppFailure.network({
    Object? cause,
    StackTrace? stackTrace,
  }) = NetworkFailure;

  const factory AppFailure.timeout({
    Object? cause,
    StackTrace? stackTrace,
  }) = TimeoutFailure;

  const factory AppFailure.unauthenticated({
    Object? cause,
    StackTrace? stackTrace,
  }) = UnauthenticatedFailure;

  const factory AppFailure.permissionDenied({
    required String action,
    Object? cause,
    StackTrace? stackTrace,
  }) = PermissionDeniedFailure;

  const factory AppFailure.notFound({
    required String entity,
    Object? cause,
    StackTrace? stackTrace,
  }) = NotFoundFailure;

  const factory AppFailure.validation({
    required String field,
    required String reason,
    Object? cause,
    StackTrace? stackTrace,
  }) = ValidationFailure;

  const factory AppFailure.conflict({
    required String reason,
    Object? cause,
    StackTrace? stackTrace,
  }) = ConflictFailure;

  const factory AppFailure.unexpected({
    Object? cause,
    StackTrace? stackTrace,
  }) = UnexpectedFailure;

  const factory AppFailure.rateLimited({
    Object? cause,
    StackTrace? stackTrace,
  }) = RateLimitedFailure;
}

/// The device could not reach the backend.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause, super.stackTrace});

  @override
  String get code => 'network';

  @override
  String get debugMessage => 'Network unreachable';
}

/// The backend was reachable but did not answer in time.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.cause, super.stackTrace});

  @override
  String get code => 'timeout';

  @override
  String get debugMessage => 'Operation timed out';
}

/// No valid session. The caller must sign in again.
final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure({super.cause, super.stackTrace});

  @override
  String get code => 'unauthenticated';

  @override
  String get debugMessage => 'No authenticated session';
}

/// Authenticated, but not allowed to perform [action].
///
/// Distinct from [UnauthenticatedFailure] on purpose: a revoked guardian is
/// signed in but must lose access immediately, and the UI response differs.
final class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({
    required this.action,
    super.cause,
    super.stackTrace,
  });

  /// The attempted action, e.g. `approveMedication`. Never a patient name.
  final String action;

  @override
  String get code => 'permission_denied';

  @override
  String get debugMessage => 'Permission denied for action: $action';
}

/// The requested entity does not exist.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    required this.entity,
    super.cause,
    super.stackTrace,
  });

  /// The entity type, e.g. `medication`. Never an identifier or a name.
  final String entity;

  @override
  String get code => 'not_found';

  @override
  String get debugMessage => 'Not found: $entity';
}

/// Input failed validation before it reached the backend.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required this.field,
    required this.reason,
    super.cause,
    super.stackTrace,
  });

  /// The field name, e.g. `email`. Never the field's value.
  final String field;

  /// Why it failed, e.g. `must_not_be_empty`. A stable token, not prose.
  final String reason;

  @override
  String get code => 'validation';

  @override
  String get debugMessage => 'Validation failed on $field: $reason';
}

/// The write lost a race, or the state machine forbids the transition.
///
/// Used for illegal dose transitions and for edits to a medication whose
/// approval hash has moved on.
final class ConflictFailure extends AppFailure {
  const ConflictFailure({
    required this.reason,
    super.cause,
    super.stackTrace,
  });

  /// A stable token, e.g. `stale_approval_hash`.
  final String reason;

  @override
  String get code => 'conflict';

  @override
  String get debugMessage => 'Conflict: $reason';
}

/// Anything not otherwise classified. Always worth investigating.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});

  @override
  String get code => 'unexpected';

  @override
  String get debugMessage => 'Unexpected failure';
}

/// The backend refused because of too many attempts in a short time.
///
/// Distinct from [ConflictFailure] and [NetworkFailure] because the right
/// response differs: the user should wait, not retry immediately or fix input.
/// First used by sign-in; later by AI extraction quotas.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({super.cause, super.stackTrace});

  @override
  String get code => 'rate_limited';

  @override
  String get debugMessage => 'Rate limited';
}
