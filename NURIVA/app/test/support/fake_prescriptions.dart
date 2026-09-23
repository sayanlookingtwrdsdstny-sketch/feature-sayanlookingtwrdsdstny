import 'dart:async';
import 'dart:typed_data';

import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/local_image_store.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_repositories.dart';

/// In-memory prescription metadata store. **Tests only.**
final class FakePrescriptionRepository implements PrescriptionRepository {
  final Map<String, Prescription> _byId = {};
  final StreamController<String> _changed = StreamController.broadcast();
  int _nextId = 1;

  AppFailure? nextFailure;

  void seed(Prescription prescription) {
    _byId[prescription.id] = prescription;
    _changed.add(prescription.patientId);
  }

  Prescription? prescriptionOf(String id) => _byId[id];

  Result<T>? _consumeFailure<T>() {
    final failure = nextFailure;
    if (failure == null) return null;
    nextFailure = null;
    return Failure<T>(failure);
  }

  @override
  Stream<List<Prescription>> watchPrescriptionsForPatient(String patientId) =>
      Stream.multi((controller) {
        List<Prescription> forPatient() =>
            _byId.values.where((p) => p.patientId == patientId).toList();

        controller.add(forPatient());
        final sub = _changed.stream
            .where((p) => p == patientId)
            .listen((_) => controller.add(forPatient()));
        controller.onCancel = sub.cancel;
      });

  @override
  Stream<Prescription?> watchPrescription(String prescriptionId) =>
      Stream.multi((controller) {
        controller.add(_byId[prescriptionId]);
        final sub = _changed.stream
            .listen((_) => controller.add(_byId[prescriptionId]));
        controller.onCancel = sub.cancel;
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
  }) async {
    final injected = _consumeFailure<Prescription>();
    if (injected != null) return injected;

    final now = DateTime.utc(2026);
    final prescription = Prescription(
      id: 'prescription-${_nextId++}',
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
    seed(prescription);
    return Success(prescription);
  }

  @override
  Future<Result<void>> deletePrescription(String prescriptionId) async {
    final injected = _consumeFailure<void>();
    if (injected != null) return injected;

    final prescription = _byId.remove(prescriptionId);
    if (prescription != null) _changed.add(prescription.patientId);
    return const Success(null);
  }
}

/// In-memory local image "store". **Tests only.** Keeps bytes in a map
/// rather than touching disk, so `PrescriptionService` tests need no
/// platform channel.
final class FakeLocalImageStore implements LocalImageStore {
  final Map<String, List<Uint8List>> _pagesByPrescription = {};

  AppFailure? nextFailure;

  bool hasPages(String prescriptionId) =>
      _pagesByPrescription.containsKey(prescriptionId);

  Result<T>? _consumeFailure<T>() {
    final failure = nextFailure;
    if (failure == null) return null;
    nextFailure = null;
    return Failure<T>(failure);
  }

  @override
  Future<Result<void>> savePages({
    required String patientId,
    required String prescriptionId,
    required List<Uint8List> pages,
  }) async {
    final injected = _consumeFailure<void>();
    if (injected != null) return injected;

    _pagesByPrescription[prescriptionId] = pages;
    return const Success(null);
  }

  @override
  Future<List<String>> pageFilePaths({
    required String patientId,
    required String prescriptionId,
    required int pageCount,
  }) async => [
        for (var i = 0; i < pageCount; i++)
          'fake://$patientId/$prescriptionId/page_$i.jpg',
      ];

  @override
  Future<bool> pageExists(String path) async =>
      _pagesByPrescription.keys.any((id) => path.contains(id));

  @override
  Future<void> deletePages({
    required String patientId,
    required String prescriptionId,
  }) async {
    _pagesByPrescription.remove(prescriptionId);
  }
}
