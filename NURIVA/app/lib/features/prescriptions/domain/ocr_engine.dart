import 'package:nuriva/core/result/result.dart';

/// Reads text off a prescription page image.
///
/// A port, so `domain/` and `application/` stay free of the ML Kit plugin and
/// remain testable without a device or a platform channel — the same split
/// `ImageCaptureService` and `LocalImageStore` use. The ML Kit implementation
/// lives in `data/`.
abstract interface class OcrEngine {
  /// Identifies the engine build behind the result, recorded on every
  /// extraction for traceability.
  String get version;

  /// Recognized lines from the image at [imagePath], in reading order.
  ///
  /// An image with no legible text is a [Success] holding an empty list, not
  /// a failure: "this photo has nothing readable in it" is an ordinary,
  /// expected answer for a creased or handwritten prescription, and the
  /// caller reports it as a warning rather than an error.
  Future<Result<List<String>>> recognizeLines(String imagePath);

  /// Releases native resources. ML Kit holds a detector open until closed.
  Future<void> dispose();
}
