import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/app.dart';
import 'package:nuriva/core/config/app_config.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/di/providers.dart';

/// End-to-end smoke test for the whole application.
///
/// The unit tests verify pieces in isolation; this one verifies that the pieces
/// actually assemble into a running app — DI resolves, the router builds, the
/// theme applies, and the splash hands off to home. It is the closest thing to
/// "does it launch" that runs without a device.

Widget _app(AppConfig config) => ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const NurivaApp(),
    );

const _devConfig = AppConfig(
  flavor: Flavor.dev,
  logLevel: LogLevel.none,
  defaultGraceMinutes: 30,
  defaultEscalationMinutes: 30,
  doseHorizonDays: 14,
);

const _prodConfig = AppConfig(
  flavor: Flavor.prod,
  logLevel: LogLevel.none,
  defaultGraceMinutes: 30,
  defaultEscalationMinutes: 30,
  doseHorizonDays: 14,
);

/// Sizes the test surface like a real phone.
///
/// The default 800x600 is shorter than any modern handset, so content that a
/// user would actually see scrolls out of the test viewport and reads as
/// "missing". These are smoke tests for a phone app; test on phone dimensions.
void _usePhoneSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('app launches and shows the branded splash', (tester) async {
    await tester.pumpWidget(_app(_devConfig));
    await tester.pump();

    expect(find.text('NURIVA'), findsOneWidget);
    expect(find.text('Medication care, together'), findsOneWidget);
    expect(find.byType(NurivaMark), findsOneWidget);
  });

  testWidgets('splash hands off to home without crashing', (tester) async {
    await tester.pumpWidget(_app(_devConfig));

    // Past the splash dwell.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Foundation ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home lists what the foundation provides', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(_devConfig));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Above the fold.
    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.text('Version 0.1.0'), findsOneWidget);
    expect(find.text('Design system'), findsWidgets);

    // The rest requires scrolling, as it would on a real handset — which also
    // exercises that the scroll view works.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Architecture'), findsOneWidget);

    // All the way to the bottom, where the roadmap card sits.
    await tester.scrollUntilVisible(
      find.textContaining('Module 02'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Module 02'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('developer build exposes the design gallery', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(_devConfig));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // By tooltip, not by icon: the same palette icon also appears on the
    // "Design system" row of the foundation list, so byIcon is ambiguous.
    final entry = find.byTooltip('Design system');
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('TAKEN'), findsOneWidget);
    expect(find.byType(NurivaButton), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production build hides the design gallery entirely',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app(_prodConfig));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Not merely hidden in the UI — the route is never registered, so the
    // gallery is unreachable in production even by deep link.
    expect(find.byTooltip('Design system'), findsNothing);
  });

  testWidgets('renders in dark theme without exploding', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_app(_devConfig));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Foundation ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clamps oversized system text instead of overflowing',
      (tester) async {
    // A user with maximum system font size must still get a usable screen;
    // unbounded scaling would later push a dose action off screen.
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app(_devConfig));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
