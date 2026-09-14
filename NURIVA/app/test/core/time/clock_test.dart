import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/time/clock.dart';

void main() {
  group('SystemClock', () {
    test('returns a UTC instant', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });

    test('returns a time close to now', () {
      final before = DateTime.now().toUtc();
      final observed = const SystemClock().nowUtc();
      final after = DateTime.now().toUtc();

      expect(observed.isBefore(before.subtract(const Duration(seconds: 5))),
          isFalse);
      expect(
          observed.isAfter(after.add(const Duration(seconds: 5))), isFalse);
    });
  });

  group('FakeClock', () {
    test('returns exactly the instant it was given', () {
      final clock = FakeClock(DateTime.utc(2026, 3, 29, 1, 30));
      expect(clock.nowUtc(), DateTime.utc(2026, 3, 29, 1, 30));
    });

    test('normalizes a local instant to UTC', () {
      final local = DateTime(2026, 3, 29, 1, 30);
      final clock = FakeClock(local);

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc(), local.toUtc());
    });

    test('does not drift between reads', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      expect(clock.nowUtc(), clock.nowUtc());
    });

    test('advance moves time forward by exactly the duration', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 8));
      clock.advance(const Duration(hours: 2, minutes: 30));

      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 10, 30));
    });

    test('advance accumulates across calls', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      clock
        ..advance(const Duration(days: 1))
        ..advance(const Duration(hours: 6));

      expect(clock.nowUtc(), DateTime.utc(2026, 1, 2, 6));
    });

    test('advance accepts zero', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      clock.advance(Duration.zero);

      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1));
    });

    test('advance rejects a negative duration', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));

      expect(
        () => clock.advance(const Duration(seconds: -1)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('advance leaves the clock unchanged when it rejects', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));

      expect(() => clock.advance(const Duration(days: -1)), throwsArgumentError);
      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1));
    });

    test('setTo jumps forward', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      clock.setTo(DateTime.utc(2026, 6, 1));

      expect(clock.nowUtc(), DateTime.utc(2026, 6, 1));
    });

    test('setTo jumps backward, unlike advance', () {
      final clock = FakeClock(DateTime.utc(2026, 6, 1));
      clock.setTo(DateTime.utc(2026, 1, 1));

      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1));
    });

    test('setTo normalizes to UTC', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      final local = DateTime(2026, 5, 5, 12);
      clock.setTo(local);

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc(), local.toUtc());
    });
  });
}
