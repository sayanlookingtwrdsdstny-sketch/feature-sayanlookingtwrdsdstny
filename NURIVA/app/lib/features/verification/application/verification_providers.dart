import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/features/medications/data/firestore_medication_repository.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/medications/domain/medication_repositories.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';
import 'package:nuriva/features/verification/application/verification_service.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => FirestoreMedicationRepository(FirebaseFirestore.instance),
);

final verificationServiceProvider = Provider<VerificationService>(
  (ref) => VerificationService(
    medications: ref.watch(medicationRepositoryProvider),
    prescriptions: ref.watch(prescriptionRepositoryProvider),
  ),
);

/// Key for [medicationsForPrescriptionProvider].
typedef PrescriptionMedicationsKey = ({
  String patientId,
  String prescriptionId,
});

/// Drafts already captured from one prescription.
final medicationsForPrescriptionProvider =
    StreamProvider.family<List<Medication>, PrescriptionMedicationsKey>(
  (ref, key) => ref
      .watch(medicationRepositoryProvider)
      .watchMedicationsForPrescription(
        patientId: key.patientId,
        prescriptionId: key.prescriptionId,
      ),
);
