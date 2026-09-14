/// Source of "now".
///
/// Architecture rule: **no `DateTime.now()` anywhere in `domain/`.** Every piece
/// of NURIVA's clinically significant logic depends on the current time — when a
/// dose becomes DUE, when its grace period elapses into MISSED, whether a dose
/// was taken on time or late, how a schedule materializes across a DST boundary.
///
/// If those read the wall clock directly, their tests become unwriteable: you
/// cannot ask "what happens at 02:30 on a spring-forward night" without being
/// able to say when "now" is. Injecting the clock turns every one of those into
/// an ordinary, fast, deterministic unit test.
abstract interface class Clock {
  /// The current instant, in UTC.
  ///
  /// Always UTC. Local-time reasoning belongs to the scheduling layer, which
  /// pairs an instant with the patient's IANA timezone; a local `DateTime`
  /// floating through the system is how timezone bugs start.
  DateTime nowUtc();
}

/// The real clock. The only implementation that reads the system time.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A clock that returns a time you control. For tests only.
///
/// ```dart
/// final clock = FakeClock(DateTime.utc(2026, 3, 29, 1, 30));
/// clock.advance(const Duration(hours: 1));
/// ```
final class FakeClock implements Clock {
  FakeClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Moves the clock forward by [duration].
  ///
  /// Throws [ArgumentError] if [duration] is negative — time going backwards
  /// is never a scenario NURIVA models, so it is a bug in the test, not a case
  /// to support.
  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Cannot advance a clock backwards',
      );
    }
    _now = _now.add(duration);
  }

  /// Jumps the clock to [instant], in either direction.
  ///
  /// Unlike [advance], this is an explicit reset rather than the passage of
  /// time, so moving backwards is allowed.
  void setTo(DateTime instant) => _now = instant.toUtc();
}
