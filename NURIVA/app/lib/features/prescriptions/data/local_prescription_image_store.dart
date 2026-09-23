import 'dart:io';
import 'dart:typed_data';

import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/local_image_store.dart';
import 'package:path_provider/path_provider.dart';

/// [LocalImageStore] backed by the app's local documents directory.
///
/// Layout: `<appDocumentsDir>/prescriptions/<patientId>/<prescriptionId>/page_<n>.jpg`
/// — deterministic, so nothing beyond `(patientId, prescriptionId, pageCount)`
/// needs to be stored anywhere to find a page again.
final class LocalPrescriptionImageStore implements LocalImageStore {
  LocalPrescriptionImageStore(this._documentsDir);

  /// Provided rather than resolved internally so tests can point this at a
  /// temp directory instead of the real app documents directory.
  final Future<Directory> Function() _documentsDir;

  static Future<Directory> defaultDocumentsDir() =>
      getApplicationDocumentsDirectory();

  Future<Directory> _prescriptionDir({
    required String patientId,
    required String prescriptionId,
  }) async {
    final root = await _documentsDir();
    return Directory(
      '${root.path}/prescriptions/$patientId/$prescriptionId',
    );
  }

  @override
  Future<Result<void>> savePages({
    required String patientId,
    required String prescriptionId,
    required List<Uint8List> pages,
  }) =>
      guardAsync(() async {
        final dir = await _prescriptionDir(
          patientId: patientId,
          prescriptionId: prescriptionId,
        );
        await dir.create(recursive: true);
        for (var i = 0; i < pages.length; i++) {
          await File('${dir.path}/page_$i.jpg').writeAsBytes(pages[i]);
        }
      });

  @override
  Future<List<String>> pageFilePaths({
    required String patientId,
    required String prescriptionId,
    required int pageCount,
  }) async {
    final dir = await _prescriptionDir(
      patientId: patientId,
      prescriptionId: prescriptionId,
    );
    return [
      for (var i = 0; i < pageCount; i++) '${dir.path}/page_$i.jpg',
    ];
  }

  @override
  Future<bool> pageExists(String path) => File(path).exists();

  @override
  Future<void> deletePages({
    required String patientId,
    required String prescriptionId,
  }) async {
    final dir = await _prescriptionDir(
      patientId: patientId,
      prescriptionId: prescriptionId,
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
