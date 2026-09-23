import 'dart:math';

/// Generates the 6-character codes used to invite a guardian (ARCHITECTURE
/// §6). Pure Dart — no Firebase — so the alphabet and length are unit
/// tested without a backend.
abstract final class LinkCodeGenerator {
  /// Excludes characters that are easy to confuse when read aloud or
  /// handwritten: `0`/`O`, `1`/`I`/`L`. A code is meant to be dictated over
  /// the phone to a family member, not just tapped from a screen.
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static const int length = 6;

  static String generate({Random? random}) {
    final rng = random ?? Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }
}
