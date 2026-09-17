import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/core/routing/route_guard.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

/// Routes the user according to their [AuthSession] (ARCHITECTURE §5).
///
/// [session] is read on **every** evaluation rather than captured once, so a
/// sign-out or expired session takes effect on the next navigation.
final class SessionRouteGuard implements RouteGuard {
  const SessionRouteGuard(this.session);

  final AuthSession Function() session;

  @override
  String? redirectFor(String location) {
    final path = AppRoutes.pathOf(location);

    // The splash is always allowed: it resolves the session itself and then
    // navigates, which keeps its minimum brand dwell intact.
    if (path == AppRoutes.splash) return null;

    return switch (session()) {
      // Mid-transition (e.g. the profile is loading right after sign-in):
      // stay on a sign-in screen rather than flashing the splash. Only a
      // protected screen reached cold, by deep link, waits on the splash.
      SessionLoading() => AppRoutes.isPublic(path) ? null : AppRoutes.splash,
      SessionUnavailable() => AppRoutes.splash,
      SignedOut() => AppRoutes.isPublic(path) ? null : AppRoutes.welcome,
      AwaitingVerification() =>
        path == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail,
      NeedsProfile() =>
        (path == AppRoutes.completeProfile || path == AppRoutes.privacy)
            ? null
            : AppRoutes.completeProfile,
      SignedIn() =>
        AppRoutes.onboardingOnly.contains(path) ? AppRoutes.home : null,
    };
  }
}
