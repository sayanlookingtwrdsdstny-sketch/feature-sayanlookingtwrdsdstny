import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/medications/domain/medication_repositories.dart';

/// [MedicationRepository] backed by Cloud Firestore.
///
/// Writes `status: PENDING_APPROVAL` as a literal, not from a parameter —
/// there is deliberately no code path in this class that can write `ACTIVE`.
/// `firestore.rules` enforces the same thing server-side; this is the
/// client-side half of a rule stated twice on purpose.
final class FirestoreMedicationRepository implements MedicationRepository {
  FirestoreMedicationRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Medication>> watchMedicationsForPatient(String patientId) => _db
      .collection(FirestorePaths.medications)
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((query) => [
            for (final doc in query.docs) _fromMap(doc.id, doc.data()),
          ]);

  /// Filtered by `patientId` on the server — the field the security rule
  /// authorizes on, and therefore the only filter Firestore can prove a
  /// query safe from — then narrowed to the prescription here. See the
  /// interface for why this is not a `prescriptionId` query.
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
  }) =>
      guardAsync(
        () async {
          final ref = _db.collection(FirestorePaths.medications).doc();
          await ref.set({
            'patientId': patientId,
            'prescriptionId': prescriptionId,
            'extractionId': extractionId,
            'medicineName': medicineName,
            'strength': strength,
            'form': form,
            'dosage': dosage,
            'timesLocal': [for (final t in timesLocal) t.wire],
            'foodInstruction': foodInstruction.wire,
            'startDate': Timestamp.fromDate(startDate),
            'endDate': endDate == null ? null : Timestamp.fromDate(endDate),
            'notes': notes,
            'status': MedicationStatus.pendingApproval.wire,
            'payloadHash': payloadHash,
            'createdByUid': createdByUid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final now = DateTime.now();
          return Medication(
            id: ref.id,
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
            createdAt: now,
            updatedAt: now,
          );
        },
        onError: _mapFirestoreError,
      );

  @override
  Future<Result<void>> deletePendingMedication(String medicationId) =>
      guardAsync(
        () => _db.doc(FirestorePaths.medication(medicationId)).delete(),
        onError: _mapFirestoreError,
      );

  static AppFailure _mapFirestoreError(Object error, StackTrace stack) =>
      switch (error) {
        FirebaseException(:final code) => AuthErrorMapper.fromFirestoreCode(
            code,
            cause: error,
            stackTrace: stack,
          ),
        _ => AppFailure.unexpected(cause: error, stackTrace: stack),
      };

  static Medication _fromMap(String id, Map<String, dynamic> data) {
    final startDate = data['startDate'];
    final endDate = data['endDate'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    return Medication(
      id: id,
      patientId: (data['patientId'] as String?) ?? '',
      prescriptionId: data['prescriptionId'] as String?,
      extractionId: data['extractionId'] as String?,
      medicineName: (data['medicineName'] as String?) ?? '',
      strength: data['strength'] as String?,
      form: data['form'] as String?,
      dosage: data['dosage'] as String?,
      timesLocal: [
        for (final raw in (data['timesLocal'] as List<dynamic>? ?? const []))
          if (raw is String) ?LocalTimeOfDay.tryParse(raw),
      ],
      foodInstruction:
          FoodInstruction.fromWire((data['foodInstruction'] as String?) ?? ''),
      startDate: startDate is Timestamp
          ? startDate.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      endDate: endDate is Timestamp ? endDate.toDate() : null,
      notes: data['notes'] as String?,
      status: MedicationStatus.fromWire((data['status'] as String?) ?? ''),
      payloadHash: (data['payloadHash'] as String?) ?? '',
      createdByUid: (data['createdByUid'] as String?) ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAt is Timestamp
          ? updatedAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
