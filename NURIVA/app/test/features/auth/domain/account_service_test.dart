import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/domain/account_service.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

import '../../../support/fake_auth.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late AccountService service;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
    service = AccountService(auth: auth, profiles: profiles);
  });

  Future<Result<AuthUser>> register({
    String name = 'Asha Rao',
    String email = 'asha@example.com',
    String password = 'correct-horse',
    Set<UserRole> roles = const {UserRole.guardian},
    bool consent = true,
  }) =>
      service.register(
        displayName: name,
        email: email,
        password: password,
        roles: roles,
        consentGiven: consent,
      );

  group('register', () {
    test('creates the account, saves the profile with consent, and sends '
        'the verification email', () async {
      final result = await register();

      expect(result.isSuccess, isTrue);
      final uid = result.valueOrNull!.uid;
      final profile = profiles.profileOf(uid)!;
      expect(profile.displayName, 'Asha Rao');
      expect(profile.roles, {UserRole.guardian});
      expect(profile.consent.version, kPrivacyNoticeVersion);
      expect(auth.verificationEmailsSent, 1);
    });

    test('never creates an account without consent', () async {
      final result = await register(consent: false);

      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'field', 'consent'),
      );
      expect(auth.currentUser, isNull);
    });

    test('requires at least one role', () async {
      final result = await register(roles: const {});
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'field', 'roles'),
      );
    });

    test('validates name, email and password before calling the backend',
        () async {
      expect(
        (await register(name: ' ')).failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'f', 'displayName'),
      );
      expect(
        (await register(email: 'nope')).failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'f', 'email'),
      );
      expect(
        (await register(password: 'short')).failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'f', 'password'),
      );
      expect(auth.currentUser, isNull);
    });

    test('normalises the email and trims the name', () async {
      final result =
          await register(name: '  Asha Rao ', email: ' Asha@Example.COM ');

      expect(result.valueOrNull!.email, 'asha@example.com');
      expect(profiles.profileOf(result.valueOrNull!.uid)!.displayName,
          'Asha Rao');
    });

    test('reports an email already in use', () async {
      await register();
      final second = await register();

      expect(
        second.failureOrNull,
        isA<ConflictFailure>().having((f) => f.reason, 'r', 'email_in_use'),
      );
    });

    test('keeps the account if saving the profile fails', () async {
      profiles.nextFailure = const AppFailure.network();

      final result = await register();

      // The account exists and the session will route to "complete profile"
      // rather than deleting a real account over a transient error.
      expect(result.isSuccess, isTrue);
      expect(profiles.profileOf(result.valueOrNull!.uid), isNull);
    });
  });

  group('signIn', () {
    setUp(() => auth.seedAccount(
          email: 'asha@example.com',
          password: 'correct-horse',
        ));

    test('signs in with normalised email', () async {
      final result = await service.signIn(
        email: '  ASHA@example.com ',
        password: 'correct-horse',
      );
      expect(result.isSuccess, isTrue);
    });

    test('a wrong password is a credentials failure', () async {
      final result = await service.signIn(
        email: 'asha@example.com',
        password: 'wrong-password',
      );
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'f', 'credentials'),
      );
    });

    test('rejects empty fields without calling the backend', () async {
      expect((await service.signIn(email: '', password: 'x')).failureOrNull,
          isA<ValidationFailure>());
      expect(
        (await service.signIn(email: 'asha@example.com', password: ''))
            .failureOrNull,
        isA<ValidationFailure>().having((f) => f.field, 'f', 'password'),
      );
    });
  });

  group('password reset', () {
    test('sends for a well-formed email', () async {
      final result = await service.sendPasswordReset(email: 'a@b.co');
      expect(result.isSuccess, isTrue);
      expect(auth.resetEmailsSent, 1);
    });

    test('rejects a malformed email without sending', () async {
      final result = await service.sendPasswordReset(email: 'nope');
      expect(result.isFailure, isTrue);
      expect(auth.resetEmailsSent, 0);
    });
  });

  group('verification', () {
    test('reports unverified until the link is used and reloaded', () async {
      await register();

      expect((await service.checkVerified()).valueOrNull, isFalse);
      auth.markVerified('asha@example.com');
      expect((await service.checkVerified()).valueOrNull, isTrue);
    });
  });

  group('completeProfile', () {
    const user =
        AuthUser(uid: 'u9', email: 'a@b.co', emailVerified: true);

    test('saves a missing profile', () async {
      final result = await service.completeProfile(
        user: user,
        displayName: 'Ravi',
        roles: const {UserRole.patient, UserRole.guardian},
        consentGiven: true,
      );
      expect(result.isSuccess, isTrue);
      expect(profiles.profileOf('u9')!.roles.length, 2);
    });

    test('still requires consent', () async {
      final result = await service.completeProfile(
        user: user,
        displayName: 'Ravi',
        roles: const {UserRole.patient},
        consentGiven: false,
      );
      expect(result.isFailure, isTrue);
      expect(profiles.profileOf('u9'), isNull);
    });
  });
}
