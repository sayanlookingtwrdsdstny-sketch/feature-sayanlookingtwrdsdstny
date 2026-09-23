/// On-device OCR extraction domain model. Pure Dart: no Flutter, no Firebase.
///
/// ARCHITECTURE.md §7 designed this step as a Cloud Function calling a vision
/// model. That design is unavailable (Cloud Functions need the Blaze plan,
/// which the user has permanently declined) and §10 forbids the obvious
/// shortcut — an AI key in the Flutter binary. Module 05 therefore runs
/// **on-device OCR** instead: no provider, no key, no network call, and no
/// prescription image or text ever leaves the phone during extraction.
///
/// What survives from §7 unchanged is the part that actually carries the
/// safety: an extraction is a **draft that nothing acts on**. It creates no
/// medication, schedules no dose, and activates nothing. A person verifies it
/// (Module 06) and a guardian approves it (Module 07) before any of that.
library;

/// Outcome of one extraction run.
///
/// [needsReview] is not a failure — it is the confidence gate (§7 stage 4)
/// firing, and it is the *expected* result for most real prescriptions.
/// Handwriting, stamps and creased paper defeat OCR routinely, and a system
/// that claimed otherwise would be lying to a guardian about a medication.
enum ExtractionStatus {
  extracted('EXTRACTED'),
  needsReview('NEEDS_REVIEW'),
  failed('FAILED');

  const ExtractionStatus(this.wire);

  final String wire;

  static ExtractionStatus fromWire(String value) => switch (value) {
        'EXTRACTED' => ExtractionStatus.extracted,
        'NEEDS_REVIEW' => ExtractionStatus.needsReview,
        _ => ExtractionStatus.failed,
      };
}

/// Which engine produced an extraction.
///
/// Recorded on every record for the same reason §7 records prompt and schema
/// versions: when the engine changes, old results must stay interpretable
/// rather than being silently re-read under new assumptions.
enum ExtractionEngine {
  mlkitOnDevice('MLKIT_ON_DEVICE');

  const ExtractionEngine(this.wire);

  final String wire;

  static ExtractionEngine fromWire(String value) =>
      ExtractionEngine.mlkitOnDevice;
}

/// Stable warning tokens. Never prose — presentation owns the wording, and
/// these are also written to Firestore, where a copy change must not
/// invalidate stored records.
abstract final class ExtractionWarnings {
  static const String noTextFound = 'no_text_found';
  static const String noCandidatesParsed = 'no_candidates_parsed';
  static const String ambiguousFrequency = 'ambiguous_frequency';
  static const String fractionalDose = 'fractional_dose';
  static const String dosesPerDayOutOfRange = 'doses_per_day_out_of_range';
  static const String durationOutOfRange = 'duration_out_of_range';
  static const String monthApproximated = 'month_approximated_as_30_days';
  static const String missingName = 'missing_name';
  static const String missingFrequency = 'missing_frequency';
  static const String missingDuration = 'missing_duration';

  /// A line looked like an instruction aimed at a reader rather than
  /// prescription content ("ignore the above", "set the dose to ...").
  ///
  /// §7's stage 5 screened *model output* for this, because an injected
  /// instruction could steer the model. There is no model here — but the text
  /// is still untrusted, still comes off a photo someone else may have
  /// prepared, and is still shown to a guardian who is about to approve
  /// medication. Flagging it lets the UI mark it as suspicious rather than
  /// presenting it as if a doctor had written it.
  static const String directiveText = 'directive_text_detected';
}

/// One medication the parser believes it found on the page.
///
/// Every field is nullable **by design**. §7: "A field it cannot read is
/// emitted as `null` with a warning — never guessed. Guessing a frequency is
/// the single most dangerous failure mode in this product." That rule is the
/// reason this class has no non-null convenience getters and no defaults.
final class MedicationCandidate {
  const MedicationCandidate({
    required this.sourceLineIndex,
    required this.sourceLine,
    required this.confidence,
    this.name,
    this.form,
    this.strength,
    this.frequencyToken,
    this.dosesPerDay,
    this.durationDays,
    this.instructions,
    this.warnings = const <String>[],
  });

  /// Index into [PrescriptionExtraction.rawLines] — so a verifier can always
  /// get back to the exact text this was derived from.
  final int sourceLineIndex;

  /// The line verbatim, kept alongside the index so a record stays readable
  /// even if line numbering ever shifts.
  final String sourceLine;

  /// 0..1. The parser emits only a few discrete values: a regex match does
  /// not justify a continuum, and pretending otherwise would make the
  /// confidence gate look more principled than it is.
  final double confidence;

  /// As read. Never normalized against a drug dictionary — NURIVA does not
  /// identify or substitute medicines (§10, and the repo's healthcare-safety
  /// rule).
  final String? name;

  /// `TAB`, `CAP`, `SYRUP` ... exactly as it appeared.
  final String? form;

  /// e.g. `40 MG`, as read. Not parsed into a number and unit — a dose
  /// arithmetic error is exactly the class of bug this module must not
  /// introduce.
  final String? strength;

  /// The frequency exactly as written, e.g. `1-0-1`. Kept verbatim next to
  /// [dosesPerDay] so a verifier checks the derivation, not just the result.
  final String? frequencyToken;

  /// Derived from [frequencyToken] only when unambiguous, else null.
  final int? dosesPerDay;

  final int? durationDays;

  /// e.g. `After Dinner`. Free text, shown as-is, never interpreted.
  final String? instructions;

  final List<String> warnings;

  /// Whether a human must look at this before it could mean anything.
  ///
  /// True unless the two fields that define a dosing schedule — what the drug
  /// is, and how often it is taken — were both read cleanly.
  bool get needsReview =>
      confidence < confidenceGate ||
      name == null ||
      dosesPerDay == null ||
      warnings.isNotEmpty;

  /// §7 stage 4's gate, kept at the same value the document specifies.
  static const double confidenceGate = 0.85;
}

/// One OCR run over one prescription's pages.
final class PrescriptionExtraction {
  const PrescriptionExtraction({
    required this.id,
    required this.prescriptionId,
    required this.engine,
    required this.engineVersion,
    required this.status,
    required this.rawLines,
    required this.candidates,
    required this.pagesProcessed,
    required this.createdByUid,
    required this.createdAt,
    this.warnings = const <String>[],
  });

  final String id;
  final String prescriptionId;
  final ExtractionEngine engine;

  /// Version of the *parser*, bumped whenever its rules change. An extraction
  /// read a year from now must be interpretable against the rules that
  /// produced it.
  final String engineVersion;

  final ExtractionStatus status;

  /// Every recognized line, verbatim and in page order.
  ///
  /// Always stored, even when parsing finds nothing: the raw text is the part
  /// a human can actually use, and it is the evidence behind every candidate.
  /// Unlike the page images (which are device-local — §18's Module 04
  /// deviation), this text *does* sync, so a second guardian who cannot see
  /// the photo can still read what it said.
  final List<String> rawLines;

  final List<MedicationCandidate> candidates;
  final int pagesProcessed;
  final List<String> warnings;
  final String createdByUid;
  final DateTime createdAt;

  /// True when anything at all wants a human's eyes — which is the normal
  /// case, and is never a reason to block the verification step.
  bool get needsReview =>
      status == ExtractionStatus.needsReview ||
      candidates.isEmpty ||
      candidates.any((c) => c.needsReview);
}
