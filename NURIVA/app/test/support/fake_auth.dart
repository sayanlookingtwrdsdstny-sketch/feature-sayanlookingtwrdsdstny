import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/app.dart';
import 'package:nuriva/core/config/app_config.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/domain/auth_repositories.dart';

/// In-memory auth backend. **Tests only** — it never ships in the app, so
/// there is no way for a build to accidentally "authenticate" against it.
///
/// Mirrors the Firebase behaviours the app depends on: an unknown user and a
/// wrong password fail identically, verification only becomes visible after
/// [reloadUser], and duplicate emails are rejected.
final class FakeAuthRepository implements AuthRepository {
  final Map<String, _Account> _accounts = {};
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  int _nextUid = 1;

  int verificationEmailsSent = 0;
  int resetEmailsSent = 0;

  /// When set, the next call returns this failure instead of running.
  AppFailure? nextFailure;

  void seedAccount({
    required String email,
    required String password,
    String displayName = 'Asha Rao',
    bool verified = true,
    bool signedIn = false,
  }) {
    final account = _Account(
      uid: 'uid-${_nextUid++}',
      email: email,
      password: password,
      displayName: displayName,
      verified: verified,
    );
    _accounts[email] = account;
    if (signedIn) _setCurrent(account.toUser());
  }

  /// Simulates the user tapping the link in the verification email. Like
  /// Firebase, the app only sees it after [reloadUser].
  void markVerified(String email) => _accounts[email]!.verified = true;

  String uidOf(String email) => _accounts[email]!.uid;

  void _setCurrent(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  Result<T>? _consumeFailure<T>() {
    final failure = nextFailure;
    if (failure == null) return null;
    nextFailure = null;
    return Failure<T>(failure);
  }

  @override
  Stream<AuthUser?> userChanges() => Stream.multi((controller) {
        controller.add(_current);
        final sub = _changes.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    final injected = _consumeFailure<AuthUser>();
    if (injected != null) return injected;

    final account = _accounts[email];
    if (account == null || account.password != password) {
      return const Failure(
        AppFailure.validation(field: 'credentials', reason: 'invalid'),
      );
    }
    final user = account.toUser();
    _setCurrent(user);
    return Success(user);
  }

  @override
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final injected = _consumeFailure<AuthUser>();
    if (injected != null) return injected;

    if (_accounts.containsKey(email)) {
      return const Failure(AppFailure.conflict(reason: 'email_in_use'));
    }
    final account = _Account(
      uid: 'uid-${_nextUid++}',
      email: email,
      password: password,
      displayName: displayName,
      verified: false,
    );
    _accounts[email] = account;
    final user = account.toUser();
    _setCurrent(user);
    return Success(user);
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    final injected = _consumeFailure<void>();
    if (injected != null) return injected;
    if (_current == null) {
      return const Failure(AppFailure.unauthenticated());
    }
    verificationEmailsSent++;
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPasswordReset({required String email}) async {
    final injected = _consumeFailure<void>();
    if (injected != null) return injected;
    resetEmailsSent++;
    return const Success(null);
  }

  @override
  Future<Result<AuthUser?>> reloadUser() async {
    final injected = _consumeFailure<AuthUser?>();
    if (injected != null) return injected;
    final current = _current;
    if (current == null) return const Success(null);
    final refreshed = _accounts[current.email]!.toUser();
    if (refreshed != current) _setCurrent(refreshed);
    return Success(refreshed);
  }

  @override
  Future<Result<void>> signOut() async {
    _setCurrent(null);
    return const Success(null);
  }
}

final class _Account {
  _Account({
    required this.uid,
    required this.email,
    required this.password,
    required this.displayName,
    required this.verified,
  });

  final String uid;
  final String email;
  final String password;
  final String displayName;
  bool verified;

  AuthUser toUser() => AuthUser(
        uid: uid,
        email: email,
        emailVerified: verified,
        displayName: displayName,
      );
}

/// In-memory profile store. **Tests only.**
final class FakeProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};
  final StreamController<String> _changed = StreamController.broadcast();

  AppFailure? nextFailure;

  UserProfile? profileOf(String uid) => _profiles[uid];

  void seed(UserProfile profile) {
    _profiles[profile.uid] = profile;
    _changed.add(profile.uid);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.multi((controller) {
        controller.add(_profiles[uid]);
        final sub = _changed.stream
            .where((changed) => changed == uid)
            .listen((_) => controller.add(_profiles[uid]));
        controller.onCancel = sub.cancel;
      });

  @override
  Future<Result<void>> createProfile({
    required String uid,
    required String email,
    required String displayName,
    required Set<UserRole> roles,
    required String consentVersion,
  }) async {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      return Failure(failure);
    }
    seed(
      UserProfile(
        uid: uid,
        displayName: displayName,
        email: email,
        roles: roles,
        consent: ConsentRecord(
          version: consentVersion,
          acceptedAt: DateTime.utc(2026, 9, 15),
        ),
      ),
    );
    return const Success(null);
  }
}

const devConfig = AppConfig(
  flavor: Flavor.dev,
  logLevel: LogLevel.none,
  defaultGraceMinutes: 30,
  defaultEscalationMinutes: 30,
  doseHorizonDays: 14,
);

const prodConfig = AppConfig(
  flavor: Flavor.prod,
  logLevel: LogLevel.none,
  defaultGraceMinutes: 30,
  defaultEscalationMinutes: 30,
  doseHorizonDays: 14,
);

/// The whole app, wired to in-memory fakes instead of Firebase.
Widget testApp({
  required FakeAuthRepository auth,
  required FakeProfileRepository profiles,
  AppConfig config = devConfig,
}) =>
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: const NurivaApp(),
    );

/// A fully set-up, signed-in account.
({FakeAuthRepository auth, FakeProfileRepository profiles}) signedInFakes({
  String name = 'Asha Rao',
  Set<UserRole> roles = const {UserRole.patient},
}) {
  final auth = FakeAuthRepository()
    ..seedAccount(
      email: 'asha@example.com',
      password: 'correct-horse',
      displayName: name,
      signedIn: true,
    );
  final profiles = FakeProfileRepository()
    ..seed(
      UserProfile(
        uid: auth.uidOf('asha@example.com'),
        displayName: name,
        email: 'asha@example.com',
        roles: roles,
        consent: const ConsentRecord(version: '2026-09-15'),
      ),
    );
  return (auth: auth, profiles: profiles);
}

/// Sizes the test surface like a real phone (360 x 800 logical). The default
/// 800x600 is shorter than any handset and hides content a user would see.
void usePhoneSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Runs [body] and returns every framework error it raised, with the full
/// diagnostic report.
///
/// `tester.takeException()` returns only the error object — "A RenderFlex
/// overflowed by 40 pixels" — and drops the report that names the offending
/// widget and its source line. Capturing the reports keeps a layout failure
/// diagnosable. The handler is restored before returning, as flutter_test
/// requires.
Future<List<FlutterErrorDetails>> collectFlutterErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Pumps past the splash's minimum dwell and lets navigation settle.
Future<void> pastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}
