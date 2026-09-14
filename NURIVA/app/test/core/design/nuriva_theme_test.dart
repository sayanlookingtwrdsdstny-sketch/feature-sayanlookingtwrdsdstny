import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/design/design.dart';

void main() {
  group('NurivaTheme', () {
    test('light and dark carry the matching status colours', () {
      final light = NurivaTheme.light();
      final dark = NurivaTheme.dark();

      final lightStatus = light.extension<NurivaStatusColors>();
      final darkStatus = dark.extension<NurivaStatusColors>();

      expect(lightStatus, isNotNull);
      expect(darkStatus, isNotNull);
      expect(lightStatus!.taken, NurivaTokens.taken);
      expect(darkStatus!.taken, NurivaTokens.takenDark);
    });

    test('brightness is set correctly on each theme', () {
      expect(NurivaTheme.light().brightness, Brightness.light);
      expect(NurivaTheme.dark().brightness, Brightness.dark);
    });

    test('body text is at least the accessible minimum', () {
      final size = NurivaTheme.light().textTheme.bodyLarge?.fontSize;
      expect(size, NurivaTokens.fontBody);
      expect(size, greaterThanOrEqualTo(16));
    });

    test('buttons meet the enlarged touch-target height', () {
      final style = NurivaTheme.light().filledButtonTheme.style;
      final size = style?.minimumSize?.resolve({});

      expect(size?.height, NurivaTokens.controlHeight);
      expect(size!.height, greaterThanOrEqualTo(48));
    });
  });

  group('NurivaTokens', () {
    test('touch targets exceed the Material 48dp minimum', () {
      expect(NurivaTokens.minTouchTarget, greaterThan(48));
      expect(NurivaTokens.primaryActionHeight,
          greaterThan(NurivaTokens.minTouchTarget));
    });

    test('text scale is clamped to a safe upper bound', () {
      // Unbounded scaling can push a dose action off screen.
      expect(NurivaTokens.maxTextScale, greaterThan(1.0));
      expect(NurivaTokens.maxTextScale, lessThanOrEqualTo(2.0));
    });

    test('spacing follows a 4dp rhythm', () {
      for (final value in [
        NurivaTokens.space1,
        NurivaTokens.space2,
        NurivaTokens.space3,
        NurivaTokens.space4,
        NurivaTokens.space5,
        NurivaTokens.space6,
        NurivaTokens.space8,
        NurivaTokens.space12,
      ]) {
        expect(value % 4, 0, reason: '$value is not a multiple of 4');
      }
    });

    test('dose-state colours are distinct from one another', () {
      // Not a const set: Color overrides ==, which Dart disallows in one.
      final colors = <Color>{
        NurivaTokens.taken,
        NurivaTokens.late,
        NurivaTokens.missed,
        NurivaTokens.skipped,
      };
      expect(colors.length, 4);
    });
  });

  group('NurivaStatusColors.of', () {
    test('maps each semantic status to its colour', () {
      const c = NurivaStatusColors.light();
      final scheme = NurivaTheme.light().colorScheme;

      expect(c.of(NurivaStatus.positive, scheme), c.taken);
      expect(c.of(NurivaStatus.warning, scheme), c.late);
      expect(c.of(NurivaStatus.danger, scheme), c.missed);
      expect(c.of(NurivaStatus.info, scheme), c.due);
      expect(c.of(NurivaStatus.neutral, scheme), c.skipped);
    });
  });
}
