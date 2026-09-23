/// The build's version identity, shown in-app on test builds.
///
/// Must match `version:` in pubspec.yaml — `test/core/config/app_version_test.dart`
/// fails the suite if they drift, so a test APK can never display the wrong
/// version.
abstract final class AppVersion {
  static const String name = '0.6.0';
  static const int build = 6;
  static const String module = '06';
  static const String moduleTitle = 'Prescription Verification';
}
