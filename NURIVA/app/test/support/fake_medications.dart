import 'dart:async';

import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/medications/domain/medication_repositories.dart';

/// In-memory medication store. **Tests only.**
final class FakeMedicationRepository implements MedicationRepository {
  final Map<String, Medication> _byId = {};
  final StreamController<void> _changed = StreamController.broadcast();
  int _nextId = 1;

  AppFailure? nextFailure;

  List<Medication> get all => _byId.values.toList();

  Medication? medicationOf(String id) => _byId[id];

  @override
  Stream<List<Medication>> watchMedicationsForPatient(String patientId) =>
      Stream.multi((controller) {
        List<Medication> forPatient() =>
            _byId.values.where((m) => m.patientId == patientId).toList();

        controller.add(forPatient());
        final sub = _changed.stream.listen((_) => controller.add(forPatient()));
        controller.onCancel = sub.cancel;
      });

  @override
  Stream<List<Medication>> watchMedicationsForPrescription({
    required String patientId,
    required String prescriptionId,
  }) =>
      watchMedicationsForPatient(patientId).map(
        (medications) => [
          for (final medication in medications)
            if (medication.prescriptionId == prescriptionId) medication,
        ],
      );

  @override
  Future<Result<Medication>> createPendingMedication({
    required String patientId,
    required String medicineName,
    required List<LocalTimeOfDay> timesLocal,
    required DateTime startDate,
    required String createdByUid,
    required String payloadHash,
    String? prescriptionId,
    String? extractionId,
    String? strength,
    String? form,
    String? dosage,
    FoodInstruction foodInstruction = FoodInstruction.none,
    DateTime? endDate,
    String? notes,
  }) async {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      return Failure(failure);
    }

    final medication = Medication(
      id: 'medication-${_nextId++}',
      patientId: patientId,
      prescriptionId: prescriptionId,
      extractionId: extractionId,
      medicineName: medicineName,
      strength: strength,
      form: form,
      dosage: dosage,
      timesLocal: timesLocal,
      foodInstruction: foodInstruction,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      status: MedicationStatus.pendingApproval,
      payloadHash: payloadHash,
      createdByUid: createdByUid,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    _byId[medication.id] = medication;
    _changed.add(null);
    return Success(medication);
  }

  @override
  Future<Result<void>> deletePendingMedication(String medicationId) async {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      return Failure(failure);
    }
    _byId.remove(medicationId);
    _changed.add(null);
    return const Success(null);
  }
}
