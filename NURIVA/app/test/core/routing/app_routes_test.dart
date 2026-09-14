import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/core/routing/route_guard.dart';

void main() {
  group('doseConfirmFor', () {
    test('builds the deep-link path for a dose', () {
      expect(AppRoutes.doseConfirmFor('d1'), '/dose/d1');
    });

    test('matches the shape of the declared pattern', () {
      expect(AppRoutes.doseConfirm, '/dose/:doseId');
      expect(AppRoutes.doseConfirmFor('abc').split('/').length,
          AppRoutes.doseConfirm.split('/').length);
    });

    test('rejects an empty dose id', () {
      expect(() => AppRoutes.doseConfirmFor(''), throwsArgumentError);
      expect(() => AppRoutes.doseConfirmFor('  '), throwsArgumentError);
    });
  });

  group('isPublic', () {
    test('is true for sign-in routes', () {
      expect(AppRoutes.isPublic(AppRoutes.splash), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.login), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.register), isTrue);
    });

    test('is false for patient data routes', () {
      expect(AppRoutes.isPublic(AppRoutes.home), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.medications), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.prescriptions), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.family), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.settings), isFalse);
    });

    test('is false for a dose deep link', () {
      expect(AppRoutes.isPublic(AppRoutes.doseConfirmFor('d1')), isFalse);
    });

    test('ignores a query string', () {
      expect(AppRoutes.isPublic('${AppRoutes.login}?next=/home'), isTrue);
      expect(AppRoutes.isPublic('${AppRoutes.home}?tab=today'), isFalse);
    });

    test('is false for an unknown route', () {
      expect(AppRoutes.isPublic('/nope'), isFalse);
    });
  });

  group('AuthRouteGuard', () {
    test('sends a signed-out user from a protected route to login', () {
      const guard = AuthRouteGuard(isAuthenticated: _signedOut);

      expect(guard.redirectFor(AppRoutes.home), AppRoutes.login);
      expect(guard.redirectFor(AppRoutes.medications), AppRoutes.login);
      expect(
        guard.redirectFor(AppRoutes.doseConfirmFor('d1')),
        AppRoutes.login,
      );
    });

    test('lets a signed-out user reach public routes', () {
      const guard = AuthRouteGuard(isAuthenticated: _signedOut);

      expect(guard.redirectFor(AppRoutes.login), isNull);
      expect(guard.redirectFor(AppRoutes.register), isNull);
      expect(guard.redirectFor(AppRoutes.splash), isNull);
    });

    test('sends a signed-in user away from login to home', () {
      const guard = AuthRouteGuard(isAuthenticated: _signedIn);

      expect(guard.redirectFor(AppRoutes.login), AppRoutes.home);
      expect(guard.redirectFor(AppRoutes.register), AppRoutes.home);
    });

    test('leaves a signed-in user on splash so it can resolve state', () {
      const guard = AuthRouteGuard(isAuthenticated: _signedIn);

      expect(guard.redirectFor(AppRoutes.splash), isNull);
    });

    test('lets a signed-in user reach protected routes', () {
      const guard = AuthRouteGuard(isAuthenticated: _signedIn);

      expect(guard.redirectFor(AppRoutes.home), isNull);
      expect(guard.redirectFor(AppRoutes.doseConfirmFor('d1')), isNull);
    });

    test('re-evaluates auth state on every call, so a revoke takes effect', () {
      var signedIn = true;
      final guard = AuthRouteGuard(isAuthenticated: () => signedIn);

      expect(guard.redirectFor(AppRoutes.home), isNull);
      signedIn = false;
      expect(guard.redirectFor(AppRoutes.home), AppRoutes.login);
    });
  });

  group('OpenAccessGuard', () {
    test('allows every route', () {
      const guard = OpenAccessGuard();

      for (final location in [
        AppRoutes.splash,
        AppRoutes.home,
        AppRoutes.settings,
        AppRoutes.doseConfirmFor('d1'),
      ]) {
        expect(guard.redirectFor(location), isNull, reason: location);
      }
    });
  });
}

bool _signedIn() => true;

bool _signedOut() => false;
