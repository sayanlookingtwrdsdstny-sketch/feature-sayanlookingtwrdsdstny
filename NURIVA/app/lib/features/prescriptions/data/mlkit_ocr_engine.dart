import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/domain/ocr_engine.dart';

/// [OcrEngine] backed by Google ML Kit's on-device text recognizer.
///
/// **On-device, and that is the point.** ML Kit's text recognition model is
/// bundled into the app and runs locally: no API key, no request, no
/// third-party processor, and no prescription image leaving the phone. That
/// is what makes Module 05 possible at all without the Blaze plan
/// (ARCHITECTURE.md §18), and it is also the strongest privacy posture
/// available under the DPDP Act — there is no cross-border transfer to
/// consent to, because there is no transfer.
///
/// Latin script only. Devanagari is available in ML Kit and may matter later,
/// but the printed prescriptions this module targets are Latin-script, and
/// silently running a script model that does not match the page produces
/// confident nonsense rather than an honest blank.
final class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine();

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  String get version => 'mlkit-latin-0.17';

  @override
  Future<Result<List<String>>> recognizeLines(String imagePath) => guardAsync(
        () async {
          final recognized =
              await _recognizer.processImage(InputImage.fromFilePath(imagePath));
          return [
            for (final block in recognized.blocks)
              for (final line in block.lines) line.text,
          ];
        },
        onError: (error, stack) =>
            AppFailure.unexpected(cause: error, stackTrace: stack),
      );

  @override
  Future<void> dispose() => _recognizer.close();
}
