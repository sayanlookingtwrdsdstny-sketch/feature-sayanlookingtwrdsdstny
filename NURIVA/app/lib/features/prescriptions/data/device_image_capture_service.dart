import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/image_capture_service.dart';

/// [ImageCaptureService] backed by `image_picker` (camera/gallery) and
/// `flutter_image_compress`.
///
/// Every image is compressed to a JPEG before it reaches the caller — phone
/// photos run 4-12 MB (ARCHITECTURE.md §14) and there is no reason to keep
/// that on-device, even though local storage has no Firestore-style byte cap
/// forcing the issue.
final class DeviceImageCaptureService implements ImageCaptureService {
  DeviceImageCaptureService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge after compression. Large enough that a prescription's text
  /// stays legible (and readable by Module 05's AI/OCR later), small enough
  /// to keep on-device storage and rendering cheap.
  static const int _maxDimension = 1600;
  static const int _quality = 80;

  @override
  Future<Result<Uint8List?>> captureFromCamera() => guardAsync(() async {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: _maxDimension.toDouble(),
          maxHeight: _maxDimension.toDouble(),
        );
        if (file == null) return null;
        return _compress(await file.readAsBytes());
      });

  @override
  Future<Result<List<Uint8List>>> pickFromGallery({int maxImages = 10}) =>
      guardAsync(() async {
        final files = await _picker.pickMultiImage(
          maxWidth: _maxDimension.toDouble(),
          maxHeight: _maxDimension.toDouble(),
          limit: maxImages,
        );
        final compressed = <Uint8List>[];
        for (final file in files.take(maxImages)) {
          compressed.add(await _compress(await file.readAsBytes()));
        }
        return compressed;
      });

  Future<Uint8List> _compress(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: _quality,
      format: CompressFormat.jpeg,
    );
    // Compression can occasionally return an empty/invalid result for an
    // already-tiny or corrupt source image; fall back to the original bytes
    // rather than saving nothing.
    return result.isEmpty ? bytes : result;
  }
}
