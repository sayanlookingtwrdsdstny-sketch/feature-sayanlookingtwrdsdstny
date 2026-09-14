/// Every route in NURIVA, named once.
///
/// Paths are centralized because two things outside the widget tree need to
/// construct them: the notification layer, which deep-links a tap straight to
/// dose confirmation, and the auth guard, which redirects. A typo'd path string
/// in either place fails silently at runtime.
abstract final class AppRoutes {
  // Onboarding / auth
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String completeProfile = '/complete-profile';
  static const String onboarding = '/onboarding';

  // Main shell
  static const String home = '/home';
  static const String medications = '/medications';
  static const String prescriptions = '/prescriptions';
  static const String appointments = '/appointments';
  static const String family = '/family';
  static const String settings = '/settings';

  /// Developer-only design system catalogue.
  ///
  /// Registered by the router only when `AppConfig.allowDeveloperTools` is
  /// true, so it is unreachable in a production build.
  static const String gallery = '/design-system';

  /// Dose confirmation. The deep-link target for a medication reminder.
  static const String doseConfirm = '/dose/:doseId';

  /// Builds the concrete [doseConfirm] path for [doseId].
  static String doseConfirmFor(String doseId) {
    if (doseId.trim().isEmpty) {
      throw ArgumentError.value(doseId, 'doseId', 'must not be empty');
    }
    return '/dose/$doseId';
  }

  /// Routes reachable without an authenticated session.
  static const Set<String> unauthenticated = {
    splash,
    login,
    register,
  };

  /// Whether [location] is reachable while signed out.
  static bool isPublic(String location) =>
      unauthenticated.contains(_stripQuery(location));

  static String _stripQuery(String location) {
    final index = location.indexOf('?');
    return index == -1 ? location : location.substring(0, index);
  }
}
