import 'package:nuriva/core/routing/app_routes.dart';

/// Decides whether a navigation attempt is allowed, and where to send it
/// instead if not.
///
/// Pure logic, deliberately free of Flutter and go_router imports: the redirect
/// rule is security-adjacent (it is what keeps a signed-out user off patient
/// data screens) and deserves to be testable without building a widget tree.
abstract interface class RouteGuard {
  /// Returns the location to redirect to, or `null` to allow [location].
  String? redirectFor(String location);
}

/// Allows every route. The Module 1 placeholder, replaced in Module 2.
final class OpenAccessGuard implements RouteGuard {
  const OpenAccessGuard();

  @override
  String? redirectFor(String location) => null;
}

/// Redirects unauthenticated users away from protected routes.
///
/// [isAuthenticated] is called on **every** evaluation rather than captured
/// once, so a revoked session takes effect on the next navigation instead of
/// lingering until the object is rebuilt.
final class AuthRouteGuard implements RouteGuard {
  const AuthRouteGuard({required this.isAuthenticated});

  final bool Function() isAuthenticated;

  @override
  String? redirectFor(String location) {
    final signedIn = isAuthenticated();
    final isPublic = AppRoutes.isPublic(location);

    if (!signedIn && !isPublic) return AppRoutes.login;

    // Splash is excluded: a signed-in user lands there first and it is the
    // screen that resolves onboarding state, so bouncing it to home would skip
    // profile completion and patient linking.
    if (signedIn && isPublic && location != AppRoutes.splash) {
      return AppRoutes.home;
    }

    return null;
  }
}
