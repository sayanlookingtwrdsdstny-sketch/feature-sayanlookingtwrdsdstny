import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/session_route_guard.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

const _unverified = AuthUser(uid: 'u', email: 'a@b.co', emailVerified: false);
const _verified = AuthUser(uid: 'u', email: 'a@b.co', emailVerified: true);
const _profile = UserProfile(
  uid: 'u',
  displayName: 'Asha',
  email: 'a@b.co',
  roles: {UserRole.patient},
  consent: ConsentRecord(version: 'v'),
);

String? _redirect(AuthSession session, String location) =>
    SessionRouteGuard(() => session).redirectFor(location);

void main() {
  test('the splash is allowed in every session state', () {
    for (final s in [
      const SessionLoading(),
      const SignedOut(),
      const AwaitingVerification(_unverified),
      const NeedsProfile(_verified),
      const SignedIn(_verified, _profile),
      const SessionUnavailable(_verified),
    ]) {
      expect(_redirect(s, AppRoutes.splash), isNull, reason: '$s');
    }
  });

  group('signed out', () {
    const s = SignedOut();

    test('can reach the public flow', () {
      expect(_redirect(s, AppRoutes.welcome), isNull);
      expect(_redirect(s, AppRoutes.login), isNull);
      expect(_redirect(s, AppRoutes.register), isNull);
      expect(_redirect(s, AppRoutes.privacy), isNull);
    });

    test('is sent to welcome from anything protected', () {
      expect(_redirect(s, AppRoutes.home), AppRoutes.welcome);
      expect(_redirect(s, AppRoutes.verifyEmail), AppRoutes.welcome);
      expect(_redirect(s, AppRoutes.doseConfirmFor('d1')), AppRoutes.welcome);
    });
  });

  group('awaiting verification', () {
    const s = AwaitingVerification(_unverified);

    test('is held on the verification screen', () {
      expect(_redirect(s, AppRoutes.verifyEmail), isNull);
      expect(_redirect(s, AppRoutes.home), AppRoutes.verifyEmail);
      expect(_redirect(s, AppRoutes.login), AppRoutes.verifyEmail);
    });
  });

  group('needs profile', () {
    const s = NeedsProfile(_verified);

    test('is held on complete-profile, but may read the notice', () {
      expect(_redirect(s, AppRoutes.completeProfile), isNull);
      expect(_redirect(s, AppRoutes.privacy), isNull);
      expect(_redirect(s, AppRoutes.home), AppRoutes.completeProfile);
    });
  });

  group('signed in', () {
    const s = SignedIn(_verified, _profile);

    test('reaches protected routes', () {
      expect(_redirect(s, AppRoutes.home), isNull);
      expect(_redirect(s, AppRoutes.doseConfirmFor('d1')), isNull);
    });

    test('is sent home from onboarding screens', () {
      for (final route in AppRoutes.onboardingOnly) {
        expect(_redirect(s, route), AppRoutes.home, reason: route);
      }
    });

    test('can still open the privacy notice', () {
      expect(_redirect(s, AppRoutes.privacy), isNull);
    });
  });

  group('loading', () {
    const s = SessionLoading();

    test('stays on a public screen instead of flashing the splash', () {
      expect(_redirect(s, AppRoutes.login), isNull);
    });

    test('holds a protected deep link on the splash', () {
      expect(_redirect(s, AppRoutes.home), AppRoutes.splash);
    });
  });

  test('an unavailable session waits on the splash (which offers retry)', () {
    expect(
      _redirect(const SessionUnavailable(_verified), AppRoutes.home),
      AppRoutes.splash,
    );
  });

  test('re-reads the session on every call, so sign-out takes effect', () {
    AuthSession current = const SignedIn(_verified, _profile);
    final guard = SessionRouteGuard(() => current);

    expect(guard.redirectFor(AppRoutes.home), isNull);
    current = const SignedOut();
    expect(guard.redirectFor(AppRoutes.home), AppRoutes.welcome);
  });
}
