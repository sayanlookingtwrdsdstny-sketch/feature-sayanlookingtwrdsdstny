import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/patients/application/care_circle_route_guard.dart';

void main() {
  group('CareCircleRouteGuard', () {
    test('holds the user in place while care-circle status is unknown', () {
      final guard = CareCircleRouteGuard(() => null);
      expect(guard.redirectFor(AppRoutes.home), isNull);
      expect(guard.redirectFor(AppRoutes.careCircleStart), isNull);
    });

    test('without a care circle, redirects everywhere except onboarding',
        () {
      final guard = CareCircleRouteGuard(() => false);
      expect(guard.redirectFor(AppRoutes.home), AppRoutes.careCircleStart);
      expect(guard.redirectFor(AppRoutes.careCircleStart), isNull);
    });

    test('with a care circle, onboarding-only routes bounce home', () {
      final guard = CareCircleRouteGuard(() => true);
      expect(guard.redirectFor(AppRoutes.careCircleStart), AppRoutes.home);
      expect(guard.redirectFor(AppRoutes.home), isNull);
    });
  });
}
