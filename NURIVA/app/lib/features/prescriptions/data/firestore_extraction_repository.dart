import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nuriva/core/constants/firestore_paths.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/data/auth_error_mapper.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_repositories.dart';

/// [ExtractionRepository] backed by Cloud Firestore.
///
/// Unlike the page images, extraction *text* does go to Firestore. That is
/// deliberate: it is the one part of a prescription that can reach a second
/// guardian's phone at all, since the pixels are device-local (§18's Module
/// 04 deviation). It is also patient data, so it is protected the same way
/// everything else is — `firestore.rules`, gated on `VIEW_PRESCRIPTIONS`.
final class FirestoreExtractionRepository implements ExtractionRepository {
  FirestoreExtractionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String prescriptionId) =>
      _db.collection(FirestorePaths.extractions(prescriptionId));

  @override
  Stream<List<PrescriptionExtraction>> watchExtractions(
    String prescriptionId,
  ) =>
      _collection(prescriptionId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((query) => [
                for (final doc in query.docs)
                  _fromMap(doc.id, prescriptionId, doc.data()),
              ]);

  @override
  Future<Result<PrescriptionExtraction>> createExtraction({
    required String prescriptionId,
    required ExtractionEngine engine,
    required String engineVersion,
    required ExtractionStatus status,
    required List<String> rawLines,
    required List<MedicationCandidate> candidates,
    required int pagesProcessed,
    required String createdByUid,
    List<String> warnings = const <String>[],
  }) =>
      guardAsync(
        () async {
          final ref = _collection(prescriptionId).doc();
          await ref.set({
            'engine': engine.wire,
            'engineVersion': engineVersion,
            'status': status.wire,
            'rawLines': rawLines,
            'candidates': [for (final c in candidates) _candidateToMap(c)],
            'pagesProcessed': pagesProcessed,
            'warnings': warnings,
            'createdByUid': createdByUid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          return PrescriptionExtraction(
            id: ref.id,
            prescriptionId: prescriptionId,
            engine: engine,
            engineVersion: engineVersion,
            status: status,
            rawLines: rawLines,
            candidates: candidates,
            pagesProcessed: pagesProcessed,
            warnings: warnings,
            createdByUid: createdByUid,
            createdAt: DateTime.now(),
          );
        },
        onError: _mapFirestoreError,
      );

  static Map<String, dynamic> _candidateToMap(MedicationCandidate c) => {
        'sourceLineIndex': c.sourceLineIndex,
        'sourceLine': c.sourceLine,
        'confidence': c.confidence,
        'name': c.name,
        'form': c.form,
        'strength': c.strength,
        'frequencyToken': c.frequencyToken,
        'dosesPerDay': c.dosesPerDay,
        'durationDays': c.durationDays,
        'instructions': c.instructions,
        'warnings': c.warnings,
      };

  static MedicationCandidate _candidateFromMap(Map<String, dynamic> data) =>
      MedicationCandidate(
        sourceLineIndex: (data['sourceLineIndex'] as num?)?.toInt() ?? 0,
        sourceLine: (data['sourceLine'] as String?) ?? '',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
        name: data['name'] as String?,
        form: data['form'] as String?,
        strength: data['strength'] as String?,
        frequencyToken: data['frequencyToken'] as String?,
        dosesPerDay: (data['dosesPerDay'] as num?)?.toInt(),
        durationDays: (data['durationDays'] as num?)?.toInt(),
        instructions: data['instructions'] as String?,
        warnings: [
          for (final w in (data['warnings'] as List<dynamic>? ?? const []))
            if (w is String) w,
        ],
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

  static PrescriptionExtraction _fromMap(
    String id,
    String prescriptionId,
    Map<String, dynamic> data,
  ) {
    final createdAt = data['createdAt'];
    return PrescriptionExtraction(
      id: id,
      prescriptionId: prescriptionId,
      engine: ExtractionEngine.fromWire((data['engine'] as String?) ?? ''),
      engineVersion: (data['engineVersion'] as String?) ?? '',
      status: ExtractionStatus.fromWire((data['status'] as String?) ?? ''),
      rawLines: [
        for (final line in (data['rawLines'] as List<dynamic>? ?? const []))
          if (line is String) line,
      ],
      candidates: [
        for (final c in (data['candidates'] as List<dynamic>? ?? const []))
          if (c is Map<String, dynamic>) _candidateFromMap(c),
      ],
      pagesProcessed: (data['pagesProcessed'] as num?)?.toInt() ?? 0,
      warnings: [
        for (final w in (data['warnings'] as List<dynamic>? ?? const []))
          if (w is String) w,
      ],
      createdByUid: (data['createdByUid'] as String?) ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
