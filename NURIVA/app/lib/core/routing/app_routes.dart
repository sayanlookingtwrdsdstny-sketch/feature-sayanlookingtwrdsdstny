/// Every route in NURIVA, named once.
///
/// Paths are centralized because things outside the widget tree construct
/// them: the notification layer deep-links a tap to dose confirmation, and the
/// session guard redirects. A typo'd path string in either place fails
/// silently at runtime.
abstract final class AppRoutes {
  // Launch
  static const String splash = '/';

  // Signed-out flow
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String privacy = '/privacy';

  // Account completion
  static const String verifyEmail = '/verify-email';
  static const String completeProfile = '/complete-profile';

  // Main
  static const String home = '/home';
  static const String medications = '/medications';
  static const String prescriptions = '/prescriptions';
  static const String appointments = '/appointments';
  static const String family = '/family';
  static const String settings = '/settings';

  /// Developer-only design system catalogue. Registered by the router only
  /// when `AppConfig.allowDeveloperTools` is true.
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

  /// Routes reachable without an account.
  static const Set<String> public = {
    welcome,
    login,
    register,
    forgotPassword,
    privacy,
  };

  /// Screens that only make sense before the account is fully set up. A
  /// signed-in user reaching one of these is sent home.
  static const Set<String> onboardingOnly = {
    welcome,
    login,
    register,
    forgotPassword,
    verifyEmail,
    completeProfile,
  };

  /// Whether [location] is reachable while signed out.
  static bool isPublic(String location) => public.contains(pathOf(location));

  /// [location] without its query string.
  static String pathOf(String location) {
    final index = location.indexOf('?');
    return index == -1 ? location : location.substring(0, index);
  }
}
