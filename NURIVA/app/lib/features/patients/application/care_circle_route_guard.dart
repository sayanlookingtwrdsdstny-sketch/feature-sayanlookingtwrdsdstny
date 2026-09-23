import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/core/routing/route_guard.dart';

/// Routes a signed-in user to care-circle setup when they have no patient
/// yet — neither a self-record nor anyone they guard (ARCHITECTURE §5's
/// "no patient & no relationship -> Onboarding" step).
///
/// Applies only once [SessionRouteGuard] has already allowed a location —
/// composed after it in the router, not instead of it, so auth state is
/// still the first gate. [hasCareCircle] is `null` while that is still
/// unknown (Firestore hasn't answered yet); this guard holds the user in
/// place rather than redirecting on an unresolved read, the same caution
/// [SessionRouteGuard] takes for [SessionLoading].
final class CareCircleRouteGuard implements RouteGuard {
  const CareCircleRouteGuard(this.hasCareCircle);

  final bool? Function() hasCareCircle;

  @override
  String? redirectFor(String location) {
    final path = AppRoutes.pathOf(location);
    final has = hasCareCircle();

    if (has == null) return null;

    if (!has) {
      return AppRoutes.careCircleOnboardingOnly.contains(path)
          ? null
          : AppRoutes.careCircleStart;
    }

    return AppRoutes.careCircleOnboardingOnly.contains(path)
        ? AppRoutes.home
        : null;
  }
}
