/// Decides whether a navigation attempt is allowed, and where to send it
/// instead if not.
///
/// Implementations are pure logic, free of Flutter and go_router, so the
/// redirect rule — what keeps a signed-out user off patient data — is testable
/// without a widget tree. The app's implementation is `SessionRouteGuard`.
abstract interface class RouteGuard {
  /// Returns the location to redirect to, or `null` to allow [location].
  String? redirectFor(String location);
}
