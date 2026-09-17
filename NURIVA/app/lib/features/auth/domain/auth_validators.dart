/// Form validation for authentication. Pure functions returning a stable
/// reason token (or `null` when valid); presentation turns tokens into copy.
abstract final class AuthValidators {
  static const int minPasswordLength = 8;
  static const int maxNameLength = 60;

  // Deliberately permissive: one @, something either side, a dot in the
  // domain. Strict RFC matching rejects real addresses; the server is the
  // final authority anyway.
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// `empty` | `invalid` | null
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'empty';
    if (!_email.hasMatch(v)) return 'invalid';
    return null;
  }

  /// `empty` | `too_short` | null
  ///
  /// Length is the only rule. Composition rules ("one symbol, one capital")
  /// push users — especially this audience — toward predictable passwords
  /// they then forget; length is what actually resists guessing.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'empty';
    if (v.length < minPasswordLength) return 'too_short';
    return null;
  }

  /// `empty` | `too_long` | null
  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'empty';
    if (v.length > maxNameLength) return 'too_long';
    return null;
  }

  /// Canonical form for storage and sign-in.
  static String normalizeEmail(String value) => value.trim().toLowerCase();
}
