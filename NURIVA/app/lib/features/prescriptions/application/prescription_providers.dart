import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/prescriptions/application/extraction_service.dart';
import 'package:nuriva/features/prescriptions/application/prescription_service.dart';
import 'package:nuriva/features/prescriptions/data/device_image_capture_service.dart';
import 'package:nuriva/features/prescriptions/data/firestore_extraction_repository.dart';
import 'package:nuriva/features/prescriptions/data/firestore_prescription_repository.dart';
import 'package:nuriva/features/prescriptions/data/local_prescription_image_store.dart';
import 'package:nuriva/features/prescriptions/data/mlkit_ocr_engine.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_repositories.dart';
import 'package:nuriva/features/prescriptions/domain/image_capture_service.dart';
import 'package:nuriva/features/prescriptions/domain/local_image_store.dart';
import 'package:nuriva/features/prescriptions/domain/ocr_engine.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_repositories.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => FirestorePrescriptionRepository(FirebaseFirestore.instance),
);

final localImageStoreProvider = Provider<LocalImageStore>(
  (ref) => LocalPrescriptionImageStore(
    LocalPrescriptionImageStore.defaultDocumentsDir,
  ),
);

final imageCaptureServiceProvider = Provider<ImageCaptureService>(
  (ref) => DeviceImageCaptureService(),
);

final prescriptionServiceProvider = Provider<PrescriptionService>(
  (ref) => PrescriptionService(
    prescriptions: ref.watch(prescriptionRepositoryProvider),
    localImages: ref.watch(localImageStoreProvider),
  ),
);

final extractionRepositoryProvider = Provider<ExtractionRepository>(
  (ref) => FirestoreExtractionRepository(FirebaseFirestore.instance),
);

/// ML Kit holds a native detector open until it is closed, so this provider
/// owns that lifetime explicitly rather than leaking one per extraction.
final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final engine = MlKitOcrEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final extractionServiceProvider = Provider<ExtractionService>(
  (ref) => ExtractionService(
    prescriptions: ref.watch(prescriptionRepositoryProvider),
    extractions: ref.watch(extractionRepositoryProvider),
    localImages: ref.watch(localImageStoreProvider),
    ocr: ref.watch(ocrEngineProvider),
  ),
);

/// Every extraction run recorded for a prescription, newest first.
final extractionsProvider =
    StreamProvider.family<List<PrescriptionExtraction>, String>(
  (ref, prescriptionId) =>
      ref.watch(extractionRepositoryProvider).watchExtractions(prescriptionId),
);

/// Every prescription recorded for [patientId].
final prescriptionsForPatientProvider =
    StreamProvider.family<List<Prescription>, String>(
  (ref, patientId) => ref
      .watch(prescriptionRepositoryProvider)
      .watchPrescriptionsForPatient(patientId),
);

final prescriptionProvider =
    StreamProvider.family<Prescription?, String>(
  (ref, prescriptionId) =>
      ref.watch(prescriptionRepositoryProvider).watchPrescription(prescriptionId),
);

/// Key for [localPrescriptionPagesProvider].
typedef PrescriptionPagesKey = ({
  String patientId,
  String prescriptionId,
  int pageCount,
});

/// Local file path for each page of a prescription, on *this* device —
/// `null` in a slot whose file isn't here (ARCHITECTURE.md §18's Module 04
/// limitation: a page saved on one device isn't visible on another).
final localPrescriptionPagesProvider =
    FutureProvider.family<List<String?>, PrescriptionPagesKey>((ref, key) async {
  final store = ref.watch(localImageStoreProvider);
  final paths = await store.pageFilePaths(
    patientId: key.patientId,
    prescriptionId: key.prescriptionId,
    pageCount: key.pageCount,
  );
  final resolved = <String?>[];
  for (final path in paths) {
    resolved.add(await store.pageExists(path) ? path : null);
  }
  return resolved;
});

/// Patients the signed-in user may see prescriptions for: themselves, plus
/// every guarded patient whose relationship carries `viewPrescriptions` —
/// the only prescription-related permission (ARCHITECTURE.md §4). A guardian
/// with e.g. only `viewMedications` sees that patient in Patients, but not
/// here.
final viewablePrescriptionPatientsProvider = Provider<AsyncValue<List<Patient>>>(
  (ref) {
    final self = ref.watch(selfPatientProvider);
    final guarded = ref.watch(guardianPatientsProvider);

    if (self.isLoading || guarded.isLoading) return const AsyncValue.loading();
    if (self.hasError) {
      return AsyncValue.error(self.error!, self.stackTrace ?? StackTrace.empty);
    }
    if (guarded.hasError) {
      return AsyncValue.error(
        guarded.error!,
        guarded.stackTrace ?? StackTrace.empty,
      );
    }

    final patients = <Patient>[
      if (self.value != null) self.value!,
      for (final patient in guarded.value ?? const <Patient>[])
        if (ref
                .watch(myRelationshipProvider(patient.id))
                .value
                ?.has(GuardianPermission.viewPrescriptions) ??
            false)
          patient,
    ];
    return AsyncValue.data(patients);
  },
);
