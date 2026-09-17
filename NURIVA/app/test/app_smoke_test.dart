import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/config/app_version.dart';
import 'package:nuriva/core/design/design.dart';

import 'support/fake_auth.dart';

/// End-to-end smoke test for the whole application, wired to in-memory fakes.
///
/// Unit tests verify pieces in isolation; this verifies they assemble into a
/// running app. It caught two real render defects in Module 01 that analyze,
/// unit tests and a successful APK build had all missed. Keep it green.
void main() {
  testWidgets('launches on the branded splash', (tester) async {
    await tester.pumpWidget(testApp(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(),
    ));
    await tester.pump();

    expect(find.text('NURIVA'), findsOneWidget);
    expect(find.text('Medication care, together'), findsOneWidget);
    expect(find.byType(NurivaMark), findsOneWidget);
  });

  testWidgets('a signed-out user lands on welcome', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(testApp(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(),
    ));
    await pastSplash(tester);

    expect(find.textContaining('shared with family'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a signed-in user lands on home with their name and version',
      (tester) async {
    usePhoneSurface(tester);
    final fakes = signedInFakes();
    await tester.pumpWidget(
      testApp(auth: fakes.auth, profiles: fakes.profiles),
    );
    await pastSplash(tester);

    expect(find.text('Hello, Asha'), findsOneWidget);
    expect(find.text('Version ${AppVersion.name}'), findsOneWidget);
    // NurivaStatusChip renders label+icon as one Text.rich span so it can
    // wrap instead of overflowing at large font sizes; an icon's WidgetSpan
    // adds a placeholder character before the text, so only a substring
    // match — not exact equality — finds it.
    expect(
      find.textContaining('My medication', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('signing out returns to welcome', (tester) async {
    usePhoneSurface(tester);
    final fakes = signedInFakes();
    await tester.pumpWidget(
      testApp(auth: fakes.auth, profiles: fakes.profiles),
    );
    await pastSplash(tester);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of NURIVA?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(fakes.auth.currentUser, isNull);
  });

  testWidgets('cancelling sign-out keeps the user signed in', (tester) async {
    usePhoneSurface(tester);
    final fakes = signedInFakes();
    await tester.pumpWidget(
      testApp(auth: fakes.auth, profiles: fakes.profiles),
    );
    await pastSplash(tester);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Asha'), findsOneWidget);
    expect(fakes.auth.currentUser, isNotNull);
  });

  testWidgets('developer build exposes the design gallery', (tester) async {
    usePhoneSurface(tester);
    final fakes = signedInFakes();
    await tester.pumpWidget(
      testApp(auth: fakes.auth, profiles: fakes.profiles),
    );
    await pastSplash(tester);

    await tester.tap(find.byTooltip('Design system'));
    await tester.pumpAndSettle();

    expect(find.text('Brand'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production build has no route to the design gallery',
      (tester) async {
    usePhoneSurface(tester);
    final fakes = signedInFakes();
    await tester.pumpWidget(testApp(
      auth: fakes.auth,
      profiles: fakes.profiles,
      config: prodConfig,
    ));
    await pastSplash(tester);

    expect(find.byTooltip('Design system'), findsNothing);
  });

  testWidgets('renders welcome in dark theme', (tester) async {
    usePhoneSurface(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(testApp(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(),
    ));
    await pastSplash(tester);

    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives 3x system font on welcome and home', (tester) async {
    usePhoneSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final fakes = signedInFakes();
    final errors = await collectFlutterErrors(() async {
      await tester.pumpWidget(
        testApp(auth: fakes.auth, profiles: fakes.profiles),
      );
      await pastSplash(tester);
    });

    expect(errors, isEmpty, reason: errors.join('\n\n'));
    expect(find.text('Hello, Asha'), findsOneWidget);
  });
}
