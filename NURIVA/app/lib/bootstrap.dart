import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/config/app_config.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/logging/app_logger.dart';

/// Starts the application with error handling and DI in place.
///
/// Everything that must happen before the first frame lives here, so `main.dart`
/// stays a one-liner and the startup sequence is testable and greppable.
Future<void> bootstrap(Widget Function() appBuilder) async {
  final config = AppConfig.fromEnvironment();
  final logger = AppLogger(
    config: config,
    sink: config.logLevel == LogLevel.none
        ? const NullLogSink()
        : const ConsoleLogSink(),
  );

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Framework-level errors (build, layout, paint).
      FlutterError.onError = (details) {
        logger.error(
          'Flutter framework error',
          context: {'library': details.library ?? 'unknown'},
          cause: details.exception,
          stackTrace: details.stack,
        );
        if (config.allowDeveloperTools) {
          FlutterError.presentError(details);
        }
      };

      // Errors from the engine that never reach the framework.
      PlatformDispatcher.instance.onError = (error, stack) {
        logger.error(
          'Uncaught platform error',
          cause: error,
          stackTrace: stack,
        );
        return true;
      };

      await initializeBackend(config, logger);

      logger.info('Starting NURIVA', context: {
        'flavor': config.flavor.name,
        'horizonDays': config.doseHorizonDays,
      });

      runApp(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
          ],
          child: appBuilder(),
        ),
      );
    },
    (error, stack) {
      // Anything that escaped both handlers above.
      logger.error('Unhandled zone error', cause: error, stackTrace: stack);
    },
  );
}

/// Backend initialization seam.
///
/// **Deliberately a no-op in Module 1.** Firebase cannot be initialized until a
/// Firebase project exists, and creating one fixes the Firestore region
/// permanently — a decision that depends on the jurisdiction NURIVA will
/// operate in (see `PROJECT_STATE.md`, open question 1).
///
/// Writing a fake `Firebase.initializeApp()` here would be worse than leaving
/// it out: it would look configured while silently talking to nothing. When the
/// region is settled, `flutterfire configure` generates the options and this
/// function initializes Firebase and App Check.
@visibleForTesting
Future<void> initializeBackend(AppConfig config, AppLogger logger) async {
  logger.warning(
    'Backend not configured — running without Firebase',
    context: {'reason': 'awaiting_firestore_region_decision'},
  );
}
