import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/config/app_config.dart';
import 'package:nuriva/core/logging/app_logger.dart';

/// Captures log lines so tests can assert on what would have been written.
final class _CapturingSink implements LogSink {
  final List<String> lines = [];

  @override
  void write(String line) => lines.add(line);

  String get joined => lines.join('\n');
}

AppConfig _config({
  Flavor flavor = Flavor.dev,
  LogLevel logLevel = LogLevel.debug,
}) =>
    AppConfig(
      flavor: flavor,
      logLevel: logLevel,
      defaultGraceMinutes: 30,
      defaultEscalationMinutes: 30,
      doseHorizonDays: 14,
    );

void main() {
  group('level filtering', () {
    test('emits messages at or above the threshold', () {
      final sink = _CapturingSink();
      final logger =
          AppLogger(config: _config(logLevel: LogLevel.warning), sink: sink);

      logger
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.lines.length, 2);
      expect(sink.joined, contains('w'));
      expect(sink.joined, contains('e'));
      expect(sink.joined, isNot(contains('[DEBUG]')));
      expect(sink.joined, isNot(contains('[INFO]')));
    });

    test('emits nothing at LogLevel.none', () {
      final sink = _CapturingSink();
      final logger =
          AppLogger(config: _config(logLevel: LogLevel.none), sink: sink);

      logger
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.lines, isEmpty);
    });

    test('emits everything at LogLevel.debug', () {
      final sink = _CapturingSink();
      final logger = AppLogger(config: _config(), sink: sink);

      logger
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.lines.length, 4);
    });
  });

  group('line format', () {
    test('includes level and flavor', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).info('started');

      expect(sink.lines.single, startsWith('[INFO] [dev] '));
      expect(sink.lines.single, contains('started'));
    });

    test('appends structured context as key=value pairs', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink)
          .info('dose due', context: {'doseId': 'd1', 'attempt': 2});

      expect(sink.lines.single, contains('doseId=d1'));
      expect(sink.lines.single, contains('attempt=2'));
      expect(sink.lines.single, contains(' | '));
    });

    test('omits the separator when there is no context', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).info('plain');

      expect(sink.lines.single, isNot(contains(' | ')));
    });

    test('omits the separator for empty context', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).info('plain', context: {});

      expect(sink.lines.single, isNot(contains(' | ')));
    });
  });

  group('context redaction', () {
    test('redacts a sensitive key by exact name', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink)
          .info('extracted', context: {'medicineName': 'Metformin'});

      expect(sink.joined, isNot(contains('Metformin')));
      expect(sink.joined, contains('medicineName=[REDACTED]'));
    });

    test('redacts regardless of key casing or separators', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).info('x', context: {
        'Medicine_Name': 'Metformin',
        'DOSAGE': '500mg',
        'food-instruction': 'after food',
      });

      expect(sink.joined, isNot(contains('Metformin')));
      expect(sink.joined, isNot(contains('500mg')));
      expect(sink.joined, isNot(contains('after food')));
    });

    test('keeps non-sensitive identifiers readable', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).info('x', context: {
        'medicationId': 'm1',
        'patientId': 'p1',
        'status': 'DUE',
      });

      expect(sink.joined, contains('medicationId=m1'));
      expect(sink.joined, contains('patientId=p1'));
      expect(sink.joined, contains('status=DUE'));
    });

    test('redacts credentials', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).info('auth', context: {
        'password': 'hunter2',
        'token': 'abc.def.ghi',
        'apiKey': 'sk-live-123',
      });

      expect(sink.joined, isNot(contains('hunter2')));
      expect(sink.joined, isNot(contains('abc.def.ghi')));
      expect(sink.joined, isNot(contains('sk-live-123')));
    });
  });

  group('AppLogger.redact', () {
    test('redacts a key: value pair in free text', () {
      final out = AppLogger.redact('parsed medicineName: Metformin');
      expect(out, isNot(contains('Metformin')));
      expect(out, contains('[REDACTED]'));
    });

    test('redacts a key=value pair in free text', () {
      final out = AppLogger.redact('dosage=500mg');
      expect(out, isNot(contains('500mg')));
    });

    test('redacts a quoted value including its spaces', () {
      final out = AppLogger.redact('foodInstruction: "after food, twice"');
      expect(out, isNot(contains('after food')));
    });

    test('leaves text with no sensitive keys untouched', () {
      const input = 'dose d1 moved to MISSED after grace period';
      expect(AppLogger.redact(input), input);
    });

    test('redacts several occurrences in one message', () {
      final out = AppLogger.redact('medicineName: Aspirin, strength: 75mg');
      expect(out, isNot(contains('Aspirin')));
      expect(out, isNot(contains('75mg')));
    });

    test('does not redact an identifier that merely contains a key name', () {
      // `medicationId` must survive even though `medicationName` is sensitive.
      final out = AppLogger.redact('medicationId=m1');
      expect(out, contains('m1'));
    });
  });

  group('error logging', () {
    test('records the cause type without leaking its message', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).error(
        'save failed',
        cause: StateError('patient Meera Sharma not found'),
      );

      expect(sink.joined, contains('cause=StateError'));
      expect(sink.joined, isNot(contains('Meera')));
    });

    test('writes the stack trace outside production', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(), sink: sink).error(
        'boom',
        stackTrace: StackTrace.fromString('#0 frame'),
      );

      expect(sink.lines.length, 2);
      expect(sink.joined, contains('#0 frame'));
    });

    test('suppresses the stack trace in production', () {
      final sink = _CapturingSink();
      AppLogger(config: _config(flavor: Flavor.prod), sink: sink).error(
        'boom',
        stackTrace: StackTrace.fromString('#0 frame'),
      );

      expect(sink.lines.length, 1);
      expect(sink.joined, isNot(contains('#0 frame')));
    });
  });

  group('sinks', () {
    test('NullLogSink discards everything', () {
      const sink = NullLogSink();
      expect(() => sink.write('anything'), returnsNormally);
    });
  });
}
