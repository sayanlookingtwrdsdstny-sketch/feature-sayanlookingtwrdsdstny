/// Which deployment this build talks to.
///
/// NURIVA uses three **fully separate Firebase projects**, not one project with
/// prefixed collections. Shared-project separation is one rules bug away from
/// test data landing in production medication records, and there is no undo for
/// that in a health app.
enum Flavor {
  dev,
  staging,
  prod;

  static Flavor fromName(String name) => switch (name.toLowerCase().trim()) {
        'dev' || 'development' => Flavor.dev,
        'staging' || 'stage' => Flavor.staging,
        'prod' || 'production' => Flavor.prod,
        _ => throw ArgumentError.value(name, 'name', 'Unknown flavor'),
      };

  /// True for the production deployment, where real patient data lives.
  bool get isProduction => this == Flavor.prod;
}

/// How much detail reaches the log sink.
enum LogLevel {
  debug,
  info,
  warning,
  error,
  none;

  static LogLevel fromName(String name) => switch (name.toLowerCase().trim()) {
        'debug' => LogLevel.debug,
        'info' => LogLevel.info,
        'warning' || 'warn' => LogLevel.warning,
        'error' => LogLevel.error,
        'none' || 'off' => LogLevel.none,
        _ => throw ArgumentError.value(name, 'name', 'Unknown log level'),
      };

  /// Whether a message at [other] should be emitted when this is the threshold.
  bool permits(LogLevel other) => other.index >= index;
}

/// Build-time configuration.
///
/// Everything here is **non-secret**. Values arrive via `--dart-define`, which
/// is recoverable from a release binary — so an API key must never be passed
/// this way. Secrets live in Google Secret Manager and are read by Cloud
/// Functions, never by the app.
final class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.logLevel,
    required this.defaultGraceMinutes,
    required this.defaultEscalationMinutes,
    required this.doseHorizonDays,
  });

  /// Reads configuration from `--dart-define` values, falling back to
  /// development defaults so `flutter run` works with no flags.
  factory AppConfig.fromEnvironment() {
    const flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    const logLevelName =
        String.fromEnvironment('LOG_LEVEL', defaultValue: 'debug');
    const graceMinutes = int.fromEnvironment('GRACE_MINUTES', defaultValue: 30);
    const escalationMinutes =
        int.fromEnvironment('ESCALATION_MINUTES', defaultValue: 30);
    const horizonDays = int.fromEnvironment('DOSE_HORIZON_DAYS', defaultValue: 14);

    return AppConfig(
      flavor: Flavor.fromName(flavorName),
      logLevel: LogLevel.fromName(logLevelName),
      defaultGraceMinutes: graceMinutes,
      defaultEscalationMinutes: escalationMinutes,
      doseHorizonDays: horizonDays,
    );
  }

  final Flavor flavor;
  final LogLevel logLevel;

  /// Minutes after a dose is DUE before it becomes MISSED.
  ///
  /// A per-patient setting overrides this; it is only the default for a newly
  /// created patient.
  final int defaultGraceMinutes;

  /// Minutes after a dose is MISSED before the guardian is alerted.
  final int defaultEscalationMinutes;

  /// How many days ahead dose instances are materialized.
  ///
  /// Bounded on purpose: open-ended medications ("take daily, ongoing") would
  /// otherwise generate unbounded documents.
  final int doseHorizonDays;

  /// Whether developer affordances (debug banners, verbose errors) are allowed.
  ///
  /// Always false in production, regardless of log level, so a misconfigured
  /// `--dart-define` cannot expose internals to patients.
  bool get allowDeveloperTools => !flavor.isProduction;

  @override
  String toString() => 'AppConfig(flavor: ${flavor.name}, '
      'logLevel: ${logLevel.name}, '
      'grace: ${defaultGraceMinutes}m, '
      'escalation: ${defaultEscalationMinutes}m, '
      'horizon: ${doseHorizonDays}d)';
}
