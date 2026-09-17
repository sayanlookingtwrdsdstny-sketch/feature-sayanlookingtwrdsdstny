import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

import '../../../support/fake_auth.dart';

/// The field whose visible label is [label].
Finder _field(String label) => find.descendant(
      of: find.widgetWithText(NurivaTextField, label),
      matching: find.byType(TextFormField),
    );

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final target = _field(label);
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
}

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
  });

  Future<void> start(WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(testApp(auth: auth, profiles: profiles));
    await pastSplash(tester);
  }

  group('registration', () {
    testWidgets('a complete sign-up lands on email confirmation',
        (tester) async {
      await start(tester);
      await _tapText(tester, 'Create account');
      expect(find.text('Create your account'), findsOneWidget);

      await _enter(tester, 'Your name', 'Asha Rao');
      await _enter(tester, 'Email', 'asha@example.com');
      await _enter(tester, 'Password', 'correct-horse');
      await _tapText(tester, 'A family member');
      await _tapText(
        tester,
        'I agree that NURIVA can store and use my health information to '
        'provide reminders, and share it only with family members I approve.',
      );
      await _tapText(tester, 'Create account');

      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining('asha@example.com'), findsOneWidget);
      expect(auth.verificationEmailsSent, 1);

      final uid = auth.uidOf('asha@example.com');
      expect(profiles.profileOf(uid)!.roles, {UserRole.guardian});
    });

    testWidgets('consent is required and nothing is created without it',
        (tester) async {
      await start(tester);
      await _tapText(tester, 'Create account');

      await _enter(tester, 'Your name', 'Asha Rao');
      await _enter(tester, 'Email', 'asha@example.com');
      await _enter(tester, 'Password', 'correct-horse');
      await _tapText(tester, 'Myself');
      await _tapText(tester, 'Create account');

      expect(
        find.text('Please agree to the privacy notice to continue.'),
        findsOneWidget,
      );
      expect(auth.currentUser, isNull);
    });

    testWidgets('empty submit shows every field message', (tester) async {
      await start(tester);
      await _tapText(tester, 'Create account');
      await _tapText(tester, 'Create account');

      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(find.text("Choose who you'll manage medication for."),
          findsOneWidget);
    });

    testWidgets('an email already in use explains what to do', (tester) async {
      auth.seedAccount(email: 'asha@example.com', password: 'whatever1');
      await start(tester);
      await _tapText(tester, 'Create account');

      await _enter(tester, 'Your name', 'Asha Rao');
      await _enter(tester, 'Email', 'asha@example.com');
      await _enter(tester, 'Password', 'correct-horse');
      await _tapText(tester, 'Myself');
      await _tapText(
        tester,
        'I agree that NURIVA can store and use my health information to '
        'provide reminders, and share it only with family members I approve.',
      );
      await _tapText(tester, 'Create account');

      expect(find.textContaining('An account already uses this email'),
          findsOneWidget);
    });

    testWidgets('the privacy notice opens from the consent field',
        (tester) async {
      await start(tester);
      await _tapText(tester, 'Create account');
      await _tapText(tester, 'Read the privacy notice');

      expect(find.text('Privacy notice'), findsOneWidget);

      // The notice is a lazy list; later sections exist only once scrolled to.
      final list = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.textContaining('Mumbai, India'),
        200,
        scrollable: list,
      );
      expect(find.textContaining('Mumbai, India'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Digital Personal Data Protection Act'),
        200,
        scrollable: list,
      );
      expect(find.textContaining('Digital Personal Data Protection Act'),
          findsOneWidget);
    });
  });

  group('email verification', () {
    testWidgets('confirming the link moves an existing user to home',
        (tester) async {
      auth.seedAccount(
        email: 'asha@example.com',
        password: 'correct-horse',
        verified: false,
        signedIn: true,
      );
      profiles.seed(UserProfile(
        uid: auth.uidOf('asha@example.com'),
        displayName: 'Asha Rao',
        email: 'asha@example.com',
        roles: const {UserRole.patient},
        consent: const ConsentRecord(version: 'v'),
      ));
      await start(tester);
      expect(find.text('Confirm your email'), findsOneWidget);

      // Not yet verified: stays, with a gentle explanation.
      await _tapText(tester, "I've confirmed my email");
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining("haven't seen the confirmation"),
          findsOneWidget);

      auth.markVerified('asha@example.com');
      await _tapText(tester, "I've confirmed my email");

      expect(find.text('Hello, Asha'), findsOneWidget);
    });

    testWidgets('resending is locked during the cooldown', (tester) async {
      auth.seedAccount(
        email: 'asha@example.com',
        password: 'correct-horse',
        verified: false,
        signedIn: true,
      );
      await start(tester);

      expect(find.textContaining('Send again in'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('Send the email again'), findsOneWidget);
    });

    testWidgets('"use a different account" signs out', (tester) async {
      auth.seedAccount(
        email: 'asha@example.com',
        password: 'correct-horse',
        verified: false,
        signedIn: true,
      );
      await start(tester);
      await _tapText(tester, 'Use a different account');

      expect(find.text('Create account'), findsOneWidget);
    });
  });

  group('sign in', () {
    setUp(() {
      auth.seedAccount(email: 'asha@example.com', password: 'correct-horse');
      profiles.seed(UserProfile(
        uid: auth.uidOf('asha@example.com'),
        displayName: 'Asha Rao',
        email: 'asha@example.com',
        roles: const {UserRole.patient},
        consent: const ConsentRecord(version: 'v'),
      ));
    });

    testWidgets('correct credentials reach home', (tester) async {
      await start(tester);
      await _tapText(tester, 'I already have an account');

      await _enter(tester, 'Email', 'asha@example.com');
      await _enter(tester, 'Password', 'correct-horse');
      await _tapText(tester, 'Sign in');

      expect(find.text('Hello, Asha'), findsOneWidget);
    });

    testWidgets('a wrong password shows the generic mismatch message',
        (tester) async {
      await start(tester);
      await _tapText(tester, 'I already have an account');

      await _enter(tester, 'Email', 'asha@example.com');
      await _enter(tester, 'Password', 'nope-nope');
      await _tapText(tester, 'Sign in');

      expect(find.textContaining("don't match"), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('carries the typed email and confirms neutrally',
        (tester) async {
      await start(tester);
      await _tapText(tester, 'I already have an account');
      await _enter(tester, 'Email', 'asha@example.com');
      await _tapText(tester, 'Forgot password?');

      expect(find.text('Reset your password'), findsOneWidget);
      await _tapText(tester, 'Send reset link');

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining("If there's an account for asha@example.com"),
          findsOneWidget);
      expect(auth.resetEmailsSent, 1);
    });
  });
}
