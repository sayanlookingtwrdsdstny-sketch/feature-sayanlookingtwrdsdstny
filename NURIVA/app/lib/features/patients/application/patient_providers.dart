import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/constants/timezones.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/patients/application/care_circle_service.dart';
import 'package:nuriva/features/patients/data/firestore_guardian_relationship_repository.dart';
import 'package:nuriva/features/patients/data/firestore_patient_repository.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/domain/patient_repositories.dart';

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => FirestorePatientRepository(FirebaseFirestore.instance),
);

final guardianRelationshipRepositoryProvider =
    Provider<GuardianRelationshipRepository>(
  (ref) => FirestoreGuardianRelationshipRepository(
    FirebaseFirestore.instance,
    ref.watch(clockProvider),
  ),
);

final careCircleServiceProvider = Provider<CareCircleService>(
  (ref) => CareCircleService(
    patients: ref.watch(patientRepositoryProvider),
    relationships: ref.watch(guardianRelationshipRepositoryProvider),
  ),
);

/// The signed-in user's own patient record. `null` while it doesn't exist
/// (a guardian-only user) or hasn't been created yet.
final selfPatientProvider = StreamProvider<Patient?>((ref) {
  final auth = ref.watch(authUserProvider).value;
  if (auth == null) return const Stream.empty();
  return ref.watch(patientRepositoryProvider).watchSelfPatient(auth.uid);
});

/// Patients this user guards via an ACTIVE relationship.
final guardianPatientsProvider = StreamProvider<List<Patient>>((ref) {
  final auth = ref.watch(authUserProvider).value;
  if (auth == null) return const Stream.empty();
  return ref
      .watch(patientRepositoryProvider)
      .watchGuardianPatients(auth.uid);
});

/// Silently creates the signed-in user's own patient record the first time
/// they are resolved as `SignedIn` with the `patient` role — the "self
/// patient" a guardian-managed flow would otherwise make them ask for
/// explicitly. Keyed by `(uid, displayName)` rather than left as a bare
/// singleton, so a sign-out followed by a different sign-in gets a fresh
/// check instead of reusing a cached result for the previous user; a
/// non-patient role short-circuits to `null` with no Firestore call.
/// `ensureSelfPatient` is itself idempotent, so re-running this on every
/// fresh sign-in for the same user is a cheap no-op, not a duplicate write.
final ensureSelfPatientProvider =
    FutureProvider.family<Patient?, ({String uid, String displayName})>(
  (ref, args) async {
    final result = await ref.read(careCircleServiceProvider).ensureSelfPatient(
          uid: args.uid,
          displayName: args.displayName,
          timezone: NurivaTimezones.defaultZone,
        );
    return result.valueOrNull;
  },
);

/// Whether the user has at least one patient in their care circle —
/// themselves or someone they guard. `null` means "not known yet" (still
/// loading, or a stream errored) — callers must not treat that as `false`,
/// or a transient read failure would bounce a signed-in user into
/// onboarding to create a second, duplicate patient.
final hasCareCircleProvider = Provider<bool?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is! SignedIn) return null;

  final self = session.profile.isPatient
      ? ref.watch(
          ensureSelfPatientProvider((
            uid: session.user.uid,
            displayName: session.profile.displayName,
          )),
        )
      : const AsyncData<Patient?>(null);
  final guarded = ref.watch(guardianPatientsProvider);
  if (!self.hasValue || !guarded.hasValue) return null;
  return self.value != null || guarded.value!.isNotEmpty;
});

final relationshipsForPatientProvider =
    StreamProvider.family<List<GuardianRelationship>, String>(
  (ref, patientId) => ref
      .watch(guardianRelationshipRepositoryProvider)
      .watchRelationshipsForPatient(patientId),
);

final myRelationshipProvider =
    StreamProvider.family<GuardianRelationship?, String>(
  (ref, patientId) {
    final auth = ref.watch(authUserProvider).value;
    if (auth == null) return const Stream.empty();
    return ref.watch(guardianRelationshipRepositoryProvider).watchMyRelationship(
          patientId: patientId,
          guardianUid: auth.uid,
        );
  },
);
