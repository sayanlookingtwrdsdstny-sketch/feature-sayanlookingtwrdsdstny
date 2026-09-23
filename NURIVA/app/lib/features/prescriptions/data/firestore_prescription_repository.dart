import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_repositories.dart';

/// [PrescriptionRepository] backed by Cloud Firestore. Metadata only — see
/// `LocalImageStore` for the page images this deliberately never touches.
final class FirestorePrescriptionRepository implements PrescriptionRepository {
  FirestorePrescriptionRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String prescriptionId) =>
      _db.doc(FirestorePaths.prescription(prescriptionId));

  @override
  Stream<List<Prescription>> watchPrescriptionsForPatient(String patientId) =>
      _db
          .collection(FirestorePaths.prescriptions)
          .where('patientId', isEqualTo: patientId)
          .snapshots()
          .map((query) => [
                for (final doc in query.docs) _fromMap(doc.id, doc.data()),
              ]);

  @override
  Stream<Prescription?> watchPrescription(String prescriptionId) =>
      _doc(prescriptionId).snapshots().map((snap) {
        final data = snap.data();
        return (snap.exists && data != null)
            ? _fromMap(prescriptionId, data)
            : null;
      });

  @override
  Future<Result<Prescription>> createPrescription({
    required String patientId,
    required String uploadedByUid,
    required String mimeType,
    required int pageCount,
    DateTime? prescribedDate,
    String? doctorName,
    String? clinicName,
  }) =>
      guardAsync(
        () async {
          final ref = _db.collection(FirestorePaths.prescriptions).doc();
          await ref.set({
            'patientId': patientId,
            'uploadedByUid': uploadedByUid,
            'mimeType': mimeType,
            'pageCount': pageCount,
            'prescribedDate': prescribedDate == null
                ? null
                : Timestamp.fromDate(prescribedDate),
            'doctorName': doctorName,
            'clinicName': clinicName,
            'status': PrescriptionStatus.uploaded.wire,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final now = DateTime.now();
          return Prescription(
            id: ref.id,
            patientId: patientId,
            uploadedByUid: uploadedByUid,
            mimeType: mimeType,
            pageCount: pageCount,
            status: PrescriptionStatus.uploaded,
            prescribedDate: prescribedDate,
            doctorName: doctorName,
            clinicName: clinicName,
            createdAt: now,
            updatedAt: now,
          );
        },
        onError: _mapFirestoreError,
      );

  @override
  Future<Result<void>> deletePrescription(String prescriptionId) => guardAsync(
        () => _doc(prescriptionId).delete(),
        onError: _mapFirestoreError,
      );

  static AppFailure _mapFirestoreError(Object error, StackTrace stack) =>
      switch (error) {
        FirebaseException(:final code) =>
          AuthErrorMapper.fromFirestoreCode(code, cause: error, stackTrace: stack),
        _ => AppFailure.unexpected(cause: error, stackTrace: stack),
      };

  static Prescription _fromMap(String id, Map<String, dynamic> data) {
    final prescribedDate = data['prescribedDate'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    return Prescription(
      id: id,
      patientId: (data['patientId'] as String?) ?? '',
      uploadedByUid: (data['uploadedByUid'] as String?) ?? '',
      mimeType: (data['mimeType'] as String?) ?? 'image/jpeg',
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
      status: PrescriptionStatus.fromWire((data['status'] as String?) ?? ''),
      prescribedDate:
          prescribedDate is Timestamp ? prescribedDate.toDate() : null,
      doctorName: data['doctorName'] as String?,
      clinicName: data['clinicName'] as String?,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAt is Timestamp
          ? updatedAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
