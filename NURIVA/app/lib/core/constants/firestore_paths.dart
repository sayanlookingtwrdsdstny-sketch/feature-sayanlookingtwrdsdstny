/// The single source of truth for every Firestore location.
///
/// The brief bans hardcoded Firebase paths scattered through the application.
/// Keeping them here means a schema change is one edit, the data model is
/// greppable, and — most importantly — the deterministic ID rules that NURIVA's
/// correctness depends on live in exactly one place.
abstract final class FirestorePaths {
  // ---------------------------------------------------------------- collections

  static const String users = 'users';
  static const String patients = 'patients';
  static const String guardianRelationships = 'guardian_relationships';
  static const String patientLinkCodes = 'patient_link_codes';
  static const String prescriptions = 'prescriptions';
  static const String medications = 'medications';
  static const String doseLogs = 'dose_logs';
  static const String appointments = 'appointments';
  static const String notifications = 'notifications';
  static const String auditLogs = 'audit_logs';

  // ------------------------------------------------------------- subcollections

  static const String extractionsSub = 'extractions';
  static const String scheduleVersionsSub = 'schedule_versions';
  static const String adherenceDailySub = 'adherence_daily';

  // ----------------------------------------------------------- document helpers

  static String user(String uid) => '$users/$uid';

  static String patient(String patientId) => '$patients/$patientId';

  static String prescription(String prescriptionId) =>
      '$prescriptions/$prescriptionId';

  static String medication(String medicationId) =>
      '$medications/$medicationId';

  static String doseLog(String doseId) => '$doseLogs/$doseId';

  static String extractions(String prescriptionId) =>
      '${prescription(prescriptionId)}/$extractionsSub';

  static String scheduleVersions(String medicationId) =>
      '${medication(medicationId)}/$scheduleVersionsSub';

  static String adherenceDaily(String patientId) =>
      '${patient(patientId)}/$adherenceDailySub';

  // ------------------------------------------------------- deterministic IDs

  /// Separator for the guardian-relationship composite key.
  ///
  /// Double underscore, because a single underscore appears inside Firebase
  /// UIDs and would make the key ambiguous to split.
  static const String relationshipIdSeparator = '__';

  /// The deterministic ID for a guardian relationship.
  ///
  /// Security Rules cannot run queries, only `get()`. A predictable ID turns
  /// "is this user a guardian of that patient, and with what permissions?"
  /// into one cheap lookup — and Firestore caps document accesses at 10 per
  /// single-document rule evaluation, so every avoided lookup counts.
  static String guardianRelationshipId({
    required String patientId,
    required String guardianUid,
  }) {
    _requireNonEmpty(patientId, 'patientId');
    _requireNonEmpty(guardianUid, 'guardianUid');
    return '$patientId$relationshipIdSeparator$guardianUid';
  }

  static String guardianRelationship({
    required String patientId,
    required String guardianUid,
  }) =>
      '$guardianRelationships/'
      '${guardianRelationshipId(patientId: patientId, guardianUid: guardianUid)}';

  static String patientLinkCode(String code) => '$patientLinkCodes/$code';

  /// The document ID for a daily adherence rollup.
  ///
  /// `yyyy-MM-dd` in the **patient's** local timezone, not UTC — "how did
  /// Tuesday go" is a question about the patient's day, not a UTC window.
  static String adherenceDailyId(DateTime localDate) {
    final y = localDate.year.toString().padLeft(4, '0');
    final m = localDate.month.toString().padLeft(2, '0');
    final d = localDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
  }
}
