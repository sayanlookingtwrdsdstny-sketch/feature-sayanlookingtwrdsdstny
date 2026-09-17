import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/routing/app_routes.dart';

void main() {
  group('doseConfirmFor', () {
    test('builds the deep-link path for a dose', () {
      expect(AppRoutes.doseConfirmFor('d1'), '/dose/d1');
    });

    test('rejects an empty dose id', () {
      expect(() => AppRoutes.doseConfirmFor(''), throwsArgumentError);
      expect(() => AppRoutes.doseConfirmFor('  '), throwsArgumentError);
    });
  });

  group('isPublic', () {
    test('is true for the signed-out flow', () {
      for (final route in [
        AppRoutes.welcome,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.privacy,
      ]) {
        expect(AppRoutes.isPublic(route), isTrue, reason: route);
      }
    });

    test('is false for account-only and patient-data routes', () {
      for (final route in [
        AppRoutes.home,
        AppRoutes.verifyEmail,
        AppRoutes.completeProfile,
        AppRoutes.medications,
        AppRoutes.family,
        AppRoutes.doseConfirmFor('d1'),
      ]) {
        expect(AppRoutes.isPublic(route), isFalse, reason: route);
      }
    });

    test('ignores a query string', () {
      expect(AppRoutes.isPublic('${AppRoutes.forgotPassword}?email=a@b.co'),
          isTrue);
      expect(AppRoutes.isPublic('${AppRoutes.home}?tab=today'), isFalse);
    });
  });

  group('pathOf', () {
    test('strips the query string', () {
      expect(AppRoutes.pathOf('/login?next=/home'), '/login');
      expect(AppRoutes.pathOf('/home'), '/home');
    });
  });
}
