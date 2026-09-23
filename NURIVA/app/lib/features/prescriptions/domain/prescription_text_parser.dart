import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';

/// Turns recognized OCR lines into [MedicationCandidate] drafts.
///
/// Pure Dart and deliberately dumb. It matches shapes it can defend and
/// emits `null` for everything else — it never infers, completes or
/// normalizes a medical value. ARCHITECTURE.md §7: "Guessing a frequency is
/// the single most dangerous failure mode in this product, so it is designed
/// out at the schema level."
///
/// Two failure directions, weighed deliberately:
///
/// * **Missing a medication** is cheap. The verification screen shows the raw
///   text beside the image, and the person adds what the parser missed.
/// * **Inventing one** is expensive — not because it could reach a patient
///   (it cannot; Modules 06 and 07 gate that), but because a panel padded
///   with junk candidates teaches guardians to skim the one screen whose
///   whole purpose is careful reading.
///
/// So the bar to emit a candidate at all is high: a line must either name a
/// dosage form, or carry both a strength and a frequency. Prose, headers,
/// vitals and addresses are left alone.
abstract final class PrescriptionTextParser {
  /// Bumped whenever these rules change. Stored on every extraction so an old
  /// record is never reinterpreted under new rules.
  static const String version = 'parser-1';

  /// Business-rule bounds (§7 stage 3). A value outside them is dropped to
  /// null with a warning rather than clamped — clamping would silently
  /// manufacture a plausible-looking dose.
  static const int minDosesPerDay = 1;
  static const int maxDosesPerDay = 12;
  static const int minDurationDays = 1;
  static const int maxDurationDays = 365;

  static final RegExp _form = RegExp(
    r'\b(tablets?|tabs?|capsules?|caps?|syrups?|syp|injections?|inj|'
    r'drops?|ointments?|oint|creams?|gels?|lotions?|powders?|sachets?|'
    r'suspensions?|susp|inhalers?|sprays?)\b',
    caseSensitive: false,
  );

  static final RegExp _strength = RegExp(
    r'\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|gm|ml|iu|%)\b',
    caseSensitive: false,
  );

  /// The dash-separated dosing notation used across Indian prescriptions:
  /// morning-noon-night, sometimes with a fourth slot.
  static final RegExp _frequency = RegExp(
    r'\b\d+(?:\.\d+)?(?:\s*-\s*\d+(?:\.\d+)?){1,3}\b',
  );

  static final RegExp _duration = RegExp(
    r'\b(\d+)\s*(days?|weeks?|wks?|months?|mo)\b',
    caseSensitive: false,
  );

  static final RegExp _instructions = RegExp(
    r'\b(?:(?:before|after)\s+(?:breakfast|lunch|dinner|food|meals?)|'
    r'empty\s+stomach|at\s+bedtime|bedtime|at\s+night|once\s+daily|'
    r'twice\s+daily|sos|stat)\b',
    caseSensitive: false,
  );

  static final RegExp _leadingIndex = RegExp(r'^\s*\d+\s*[.)]?\s+');

  /// Injection-shaped imperatives. Tuned to avoid real prescription language:
  /// a genuine sheet says "Instructions:" and "Take each medication exactly
  /// as prescribed", which must not trip this.
  static final List<RegExp> _directives = <RegExp>[
    RegExp(r'ignore\s+(?:all\s+|the\s+)?(?:previous|prior|above)',
        caseSensitive: false),
    RegExp(r'disregard\s+(?:all\s+|the\s+)?(?:previous|prior|above)',
        caseSensitive: false),
    RegExp(r'(?:system|assistant)\s+prompt', caseSensitive: false),
    RegExp(r'new\s+instructions', caseSensitive: false),
    RegExp(r'set\s+(?:the\s+)?dos(?:e|age)\s+to', caseSensitive: false),
    RegExp(r'\boverride\b', caseSensitive: false),
  ];

  /// Parses [lines] into candidates plus document-level warnings.
  static ParsedPrescription parse(List<String> lines) {
    final cleaned = [
      for (final line in lines)
        if (line.trim().isNotEmpty) line.trim(),
    ];

    if (cleaned.isEmpty) {
      return const ParsedPrescription(
        candidates: <MedicationCandidate>[],
        warnings: <String>[ExtractionWarnings.noTextFound],
      );
    }

    final candidates = <MedicationCandidate>[];
    final warnings = <String>{};

    for (var i = 0; i < cleaned.length; i++) {
      final line = cleaned[i];
      if (_directives.any((d) => d.hasMatch(line))) {
        warnings.add(ExtractionWarnings.directiveText);
      }
      final candidate = _parseLine(line, i);
      if (candidate != null) candidates.add(candidate);
    }

    if (candidates.isEmpty) {
      warnings.add(ExtractionWarnings.noCandidatesParsed);
    }

    return ParsedPrescription(
      candidates: candidates,
      warnings: warnings.toList()..sort(),
    );
  }

  static MedicationCandidate? _parseLine(String line, int index) {
    final formMatch = _form.firstMatch(line);
    final strengthMatch = _strength.firstMatch(line);
    final frequencyMatch = _frequency.firstMatch(line);

    // The bar for treating a line as a medication at all.
    final looksLikeMedication = formMatch != null ||
        (strengthMatch != null && frequencyMatch != null);
    if (!looksLikeMedication) return null;

    final warnings = <String>[];

    final (dosesPerDay, frequencyToken) =
        _parseFrequency(frequencyMatch, warnings);
    final durationDays = _parseDuration(line, warnings);
    final instructionsMatch = _instructions.firstMatch(line);
    final name = _parseName(
      line,
      formMatch: formMatch,
      strengthMatch: strengthMatch,
      frequencyMatch: frequencyMatch,
      instructionsMatch: instructionsMatch,
    );

    // A form word on its own is not a medication. OCR over a table emits
    // stray cell fragments — a bare "tablet", an "L capsule" — and a card
    // whose every field reads "Not read" carries nothing except noise. That
    // noise is not harmless: it is what teaches a guardian to skim the one
    // screen that exists to be read carefully.
    final carriesInformation = name != null ||
        strengthMatch != null ||
        dosesPerDay != null ||
        durationDays != null;
    if (!carriesInformation) return null;

    if (name == null) warnings.add(ExtractionWarnings.missingName);
    if (dosesPerDay == null && frequencyToken == null) {
      warnings.add(ExtractionWarnings.missingFrequency);
    }
    if (durationDays == null) {
      warnings.add(ExtractionWarnings.missingDuration);
    }

    return MedicationCandidate(
      sourceLineIndex: index,
      sourceLine: line,
      confidence: _score(
        hasForm: formMatch != null,
        hasStrength: strengthMatch != null,
        hasDosesPerDay: dosesPerDay != null,
        hasDuration: durationDays != null,
        warningCount: warnings.length,
      ),
      name: name,
      form: formMatch?.group(0)?.trim(),
      strength: strengthMatch?.group(0)?.trim(),
      frequencyToken: frequencyToken,
      dosesPerDay: dosesPerDay,
      durationDays: durationDays,
      instructions: instructionsMatch?.group(0)?.trim(),
      warnings: warnings..sort(),
    );
  }

  /// Returns `(dosesPerDay, tokenAsWritten)`.
  ///
  /// The token is kept even when the doses-per-day derivation is refused, so
  /// a verifier can see what was on the page and decide for themselves.
  static (int?, String?) _parseFrequency(
    RegExpMatch? match,
    List<String> warnings,
  ) {
    final token = match?.group(0)?.replaceAll(RegExp(r'\s+'), '');
    if (token == null) return (null, null);

    final parts = token.split('-');
    var total = 0;
    for (final part in parts) {
      final value = num.tryParse(part);
      if (value == null) {
        warnings.add(ExtractionWarnings.ambiguousFrequency);
        return (null, token);
      }
      // Half tablets are real, but turning "0.5-0-0.5" into a doses-per-day
      // integer means deciding what half a dose means for a schedule. That is
      // a clinical judgement, not a parsing one.
      if (value != value.roundToDouble()) {
        warnings.add(ExtractionWarnings.fractionalDose);
        return (null, token);
      }
      total += value.toInt();
    }

    if (total == 0) {
      warnings.add(ExtractionWarnings.ambiguousFrequency);
      return (null, token);
    }
    if (total < minDosesPerDay || total > maxDosesPerDay) {
      warnings.add(ExtractionWarnings.dosesPerDayOutOfRange);
      return (null, token);
    }
    return (total, token);
  }

  static int? _parseDuration(String line, List<String> warnings) {
    final match = _duration.firstMatch(line);
    if (match == null) return null;

    final count = int.tryParse(match.group(1) ?? '');
    final unit = (match.group(2) ?? '').toLowerCase();
    if (count == null) return null;

    final days = switch (unit) {
      final u when u.startsWith('day') => count,
      final u when u.startsWith('w') => count * 7,
      // A prescriber's "1 Month" is not 30 days in any exact sense. The
      // approximation is recorded rather than hidden, because a duration is
      // what decides when reminders stop.
      _ => count * 30,
    };
    if (!unit.startsWith('day') && !unit.startsWith('w')) {
      warnings.add(ExtractionWarnings.monthApproximated);
    }

    if (days < minDurationDays || days > maxDurationDays) {
      warnings.add(ExtractionWarnings.durationOutOfRange);
      return null;
    }
    return days;
  }

  /// Whatever is left once every structured token is removed.
  static String? _parseName(
    String line, {
    RegExpMatch? formMatch,
    RegExpMatch? strengthMatch,
    RegExpMatch? frequencyMatch,
    RegExpMatch? instructionsMatch,
  }) {
    var rest = line.replaceFirst(_leadingIndex, '');
    for (final match in [
      formMatch,
      strengthMatch,
      frequencyMatch,
      instructionsMatch,
    ]) {
      final text = match?.group(0);
      if (text != null) rest = rest.replaceFirst(text, ' ');
    }
    rest = rest
        .replaceAll(_duration, ' ')
        .replaceAll(RegExp(r'[|,;:]+'), ' ')
        // Removing a strength from "Atarax (10 mg)" leaves "Atarax ( )".
        // The brackets held the token that is now gone, so they go too.
        .replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // A single stray character is noise, not a drug name.
    return rest.length < 2 ? null : rest;
  }

  static double _score({
    required bool hasForm,
    required bool hasStrength,
    required bool hasDosesPerDay,
    required bool hasDuration,
    required int warningCount,
  }) {
    var score = 0.5;
    if (hasForm) score += 0.2;
    if (hasDosesPerDay) score += 0.2;
    if (hasStrength) score += 0.1;
    if (hasDuration) score += 0.1;
    if (warningCount > 0) score -= 0.2;
    // Never claim near-certainty. This is optical character recognition and
    // regular expressions, and the ceiling should say so.
    return score.clamp(0.1, 0.95);
  }
}

/// The parser's output for one prescription.
final class ParsedPrescription {
  const ParsedPrescription({
    required this.candidates,
    required this.warnings,
  });

  final List<MedicationCandidate> candidates;
  final List<String> warnings;

  /// The confidence gate (§7 stage 4), applied across the whole document.
  ///
  /// Anything short of "every candidate read cleanly, and there was at least
  /// one" resolves to [ExtractionStatus.needsReview] — the honest default for
  /// OCR over a photograph of paper.
  ExtractionStatus get status {
    if (candidates.isEmpty) return ExtractionStatus.needsReview;
    if (warnings.isNotEmpty) return ExtractionStatus.needsReview;
    return candidates.any((c) => c.needsReview)
        ? ExtractionStatus.needsReview
        : ExtractionStatus.extracted;
  }
}
