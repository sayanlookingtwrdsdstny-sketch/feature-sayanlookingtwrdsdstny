import 'package:nuriva/core/config/app_config.dart';

/// Where a log record ends up. Swapped for a fake in tests, and for
/// Crashlytics in release builds.
abstract interface class LogSink {
  void write(String line);
}

/// Writes to the console. The default outside production.
final class ConsoleLogSink implements LogSink {
  const ConsoleLogSink();

  @override
  void write(String line) {
    // ignore: avoid_print — this is the console sink; printing is its job.
    print(line);
  }
}

/// Discards everything. Used when [LogLevel.none] is configured.
final class NullLogSink implements LogSink {
  const NullLogSink();

  @override
  void write(String line) {}
}

/// Structured logger with mandatory redaction.
///
/// NURIVA handles medication data. A medication name is frequently diagnostic —
/// "who is on which drug" is exactly the inference a leaked log enables. So the
/// logger refuses to be a place where that leaks: messages pass through
/// [redact] before they reach any sink.
///
/// The rule callers must follow: **log identifiers and stable tokens, never
/// human-readable clinical values.** `medicationId` is fine; `medicineName` is
/// not. [redact] is the backstop for when someone forgets, not a licence to.
final class AppLogger {
  const AppLogger({
    required this.config,
    required this.sink,
  });

  final AppConfig config;
  final LogSink sink;

  /// Keys whose values are replaced wholesale. Lower-case, matched
  /// case-insensitively against `key: value` and `key=value` pairs.
  static const Set<String> sensitiveKeys = {
    'medicinename',
    'medicationname',
    'dosage',
    'strength',
    'frequency',
    'foodinstruction',
    'diagnosis',
    'notes',
    'displayname',
    'patientname',
    'doctorname',
    'clinicname',
    'email',
    'phone',
    'dob',
    'password',
    'token',
    'apikey',
    'authorization',
  };

  static const String _redacted = '[REDACTED]';

  void debug(String message, {Map<String, Object?>? context}) =>
      _log(LogLevel.debug, message, context);

  void info(String message, {Map<String, Object?>? context}) =>
      _log(LogLevel.info, message, context);

  void warning(String message, {Map<String, Object?>? context}) =>
      _log(LogLevel.warning, message, context);

  void error(
    String message, {
    Map<String, Object?>? context,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final merged = <String, Object?>{
      ...?context,
      if (cause != null) 'cause': cause.runtimeType.toString(),
    };
    _log(LogLevel.error, message, merged);
    if (stackTrace != null && config.allowDeveloperTools) {
      sink.write(stackTrace.toString());
    }
  }

  void _log(LogLevel level, String message, Map<String, Object?>? context) {
    if (!config.logLevel.permits(level)) return;

    final buffer = StringBuffer()
      ..write('[${level.name.toUpperCase()}]')
      ..write(' [${config.flavor.name}] ')
      ..write(redact(message));

    if (context != null && context.isNotEmpty) {
      final safe = context.entries
          .map((e) => '${e.key}=${_redactValueFor(e.key, e.value)}')
          .join(' ');
      buffer.write(' | $safe');
    }

    sink.write(buffer.toString());
  }

  static String _redactValueFor(String key, Object? value) =>
      sensitiveKeys.contains(_normalizeKey(key)) ? _redacted : '$value';

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Replaces the value of any [sensitiveKeys] occurrence in [message].
  ///
  /// Handles `key: value` and `key=value`, quoted or bare. This is a safety
  /// net over free-text messages; structured `context` is the better path
  /// because it redacts by key without pattern matching.
  static String redact(String message) {
    var output = message;
    for (final key in sensitiveKeys) {
      // Matches the key (ignoring separators like _ or -), then : or =,
      // then either a quoted string or a run of non-separator characters.
      final pattern = RegExp(
        '''(\\b${key.split('').join('[_\\- ]?')}\\b\\s*[:=]\\s*)("[^"]*"|'[^']*'|[^,;|}\\s]+)''',
        caseSensitive: false,
      );
      output = output.replaceAllMapped(pattern, (m) => '${m[1]}$_redacted');
    }
    return output;
  }
}
