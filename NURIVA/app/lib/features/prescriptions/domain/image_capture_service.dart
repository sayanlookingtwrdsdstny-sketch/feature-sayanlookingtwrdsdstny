import 'dart:typed_data';

import 'package:nuriva/core/result/result.dart';

/// Captures or picks prescription page images and compresses them before
/// they ever reach [LocalImageStore] — phone photos are 4-12 MB
/// (ARCHITECTURE.md §14), and there is no reason to keep that on-device.
abstract interface class ImageCaptureService {
  /// Takes one photo with the camera. `null` if the user cancels.
  Future<Result<Uint8List?>> captureFromCamera();

  /// Picks one or more photos from the gallery, capped at [maxImages]. Empty
  /// if the user cancels.
  Future<Result<List<Uint8List>>> pickFromGallery({int maxImages = 10});
}
