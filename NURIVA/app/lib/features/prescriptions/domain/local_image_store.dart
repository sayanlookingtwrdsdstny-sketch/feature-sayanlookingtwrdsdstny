import 'dart:typed_data';

import 'package:nuriva/core/result/result.dart';

/// Owns prescription page images on the device's local filesystem.
///
/// Firestore only ever sees prescription *metadata* (ARCHITECTURE.md §18's
/// Module 04 deviation) — the bytes live here, keyed by a deterministic
/// `(patientId, prescriptionId, pageIndex)` path so nothing extra needs to be
/// stored in Firestore to find them again on the same device.
///
/// **This is the source of the module's one real limitation**: a page saved
/// here is visible only on the device that saved it. It does not sync to
/// another guardian's phone and does not survive a reinstall.
abstract interface class LocalImageStore {
  /// Saves [pages] (already-compressed JPEG bytes, one entry per page) for
  /// `(patientId, prescriptionId)`, page 0 first.
  Future<Result<void>> savePages({
    required String patientId,
    required String prescriptionId,
    required List<Uint8List> pages,
  });

  /// The local file path for each of [pageCount] pages, in order — whether or
  /// not the file actually exists on this device. Callers check existence
  /// with [pageExists] before reading.
  Future<List<String>> pageFilePaths({
    required String patientId,
    required String prescriptionId,
    required int pageCount,
  });

  /// Whether the file at [path] (from [pageFilePaths]) exists on this device.
  Future<bool> pageExists(String path);

  /// Deletes every saved page for `(patientId, prescriptionId)` on this
  /// device. A no-op, not a failure, when none exist here.
  Future<void> deletePages({
    required String patientId,
    required String prescriptionId,
  });
}
