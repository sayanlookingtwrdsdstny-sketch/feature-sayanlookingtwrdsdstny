import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/config/app_config.dart';

void main() {
  group('Flavor.fromName', () {
    test('parses canonical names', () {
      expect(Flavor.fromName('dev'), Flavor.dev);
      expect(Flavor.fromName('staging'), Flavor.staging);
      expect(Flavor.fromName('prod'), Flavor.prod);
    });

    test('parses aliases', () {
      expect(Flavor.fromName('development'), Flavor.dev);
      expect(Flavor.fromName('stage'), Flavor.staging);
      expect(Flavor.fromName('production'), Flavor.prod);
    });

    test('is case insensitive and trims whitespace', () {
      expect(Flavor.fromName('  PROD '), Flavor.prod);
      expect(Flavor.fromName('Staging'), Flavor.staging);
    });

    test('rejects an unknown name', () {
      expect(() => Flavor.fromName('qa'), throwsArgumentError);
      expect(() => Flavor.fromName(''), throwsArgumentError);
    });
  });

  group('Flavor.isProduction', () {
    test('is true only for prod', () {
      expect(Flavor.prod.isProduction, isTrue);
      expect(Flavor.dev.isProduction, isFalse);
      expect(Flavor.staging.isProduction, isFalse);
    });
  });

  group('LogLevel.fromName', () {
    test('parses every level including aliases', () {
      expect(LogLevel.fromName('debug'), LogLevel.debug);
      expect(LogLevel.fromName('info'), LogLevel.info);
      expect(LogLevel.fromName('warning'), LogLevel.warning);
      expect(LogLevel.fromName('warn'), LogLevel.warning);
      expect(LogLevel.fromName('error'), LogLevel.error);
      expect(LogLevel.fromName('none'), LogLevel.none);
      expect(LogLevel.fromName('off'), LogLevel.none);
    });

    test('rejects an unknown level', () {
      expect(() => LogLevel.fromName('verbose'), throwsArgumentError);
    });
  });

  group('LogLevel.permits', () {
    test('a threshold permits itself', () {
      expect(LogLevel.info.permits(LogLevel.info), isTrue);
    });

    test('a threshold permits more severe levels', () {
      expect(LogLevel.info.permits(LogLevel.warning), isTrue);
      expect(LogLevel.info.permits(LogLevel.error), isTrue);
    });

    test('a threshold blocks less severe levels', () {
      expect(LogLevel.info.permits(LogLevel.debug), isFalse);
      expect(LogLevel.error.permits(LogLevel.warning), isFalse);
    });

    test('debug permits everything', () {
      for (final level in LogLevel.values) {
        expect(LogLevel.debug.permits(level), isTrue, reason: level.name);
      }
    });

    test('none blocks every real level', () {
      expect(LogLevel.none.permits(LogLevel.debug), isFalse);
      expect(LogLevel.none.permits(LogLevel.info), isFalse);
      expect(LogLevel.none.permits(LogLevel.warning), isFalse);
      expect(LogLevel.none.permits(LogLevel.error), isFalse);
    });
  });

  group('AppConfig', () {
    const config = AppConfig(
      flavor: Flavor.dev,
      logLevel: LogLevel.debug,
      defaultGraceMinutes: 30,
      defaultEscalationMinutes: 30,
      doseHorizonDays: 14,
    );

    test('allowDeveloperTools is true outside production', () {
      expect(config.allowDeveloperTools, isTrue);
    });

    test('allowDeveloperTools is false in production regardless of log level',
        () {
      const prod = AppConfig(
        flavor: Flavor.prod,
        logLevel: LogLevel.debug,
        defaultGraceMinutes: 30,
        defaultEscalationMinutes: 30,
        doseHorizonDays: 14,
      );

      expect(prod.allowDeveloperTools, isFalse);
    });

    test('fromEnvironment falls back to development defaults', () {
      final fromEnv = AppConfig.fromEnvironment();

      expect(fromEnv.flavor, Flavor.dev);
      expect(fromEnv.logLevel, LogLevel.debug);
      expect(fromEnv.defaultGraceMinutes, 30);
      expect(fromEnv.defaultEscalationMinutes, 30);
      expect(fromEnv.doseHorizonDays, 14);
    });

    test('toString reports every field', () {
      final text = config.toString();

      expect(text, contains('dev'));
      expect(text, contains('debug'));
      expect(text, contains('30m'));
      expect(text, contains('14d'));
    });
  });
}
