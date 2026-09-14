import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/config/app_config.dart';
import 'package:nuriva/core/logging/app_logger.dart';
import 'package:nuriva/core/time/clock.dart';

/// Dependency injection roots.
///
/// NURIVA uses Riverpod for both state and DI rather than adding a separate
/// service locator. Two reasons that matter here: dependencies resolve without
/// a `BuildContext`, which the notification and background layers do not have;
/// and a test can override any of these with `ProviderContainer(overrides: ...)`
/// without a global mutable registry to reset between tests.
///
/// Every provider below is overridden in `bootstrap.dart` or in tests. The
/// defaults that throw are deliberate: a missing override should fail loudly at
/// startup, not silently produce a half-configured app.

/// Build-time configuration. Overridden in `bootstrap.dart`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap or tests',
  ),
);

/// Where log lines go. Console outside production.
final logSinkProvider = Provider<LogSink>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.logLevel == LogLevel.none
      ? const NullLogSink()
      : const ConsoleLogSink();
});

/// The application logger, with redaction applied.
final loggerProvider = Provider<AppLogger>((ref) {
  return AppLogger(
    config: ref.watch(appConfigProvider),
    sink: ref.watch(logSinkProvider),
  );
});

/// Source of "now".
///
/// Overridden with a `FakeClock` in any test that touches scheduling, dose
/// state, or adherence — which is most of the clinically significant logic.
final clockProvider = Provider<Clock>((ref) => const SystemClock());
