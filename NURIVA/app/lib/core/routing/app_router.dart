import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/core/routing/route_guard.dart';
import 'package:nuriva/features/design_gallery/presentation/design_gallery_screen.dart';
import 'package:nuriva/features/home/presentation/foundation_home_screen.dart';
import 'package:nuriva/features/splash/presentation/splash_screen.dart';

/// The active route guard. Module 02 overrides this with [AuthRouteGuard]
/// bound to real Firebase auth state.
final routeGuardProvider = Provider<RouteGuard>(
  (ref) => const OpenAccessGuard(),
);

/// The application router.
final routerProvider = Provider<GoRouter>((ref) {
  final guard = ref.watch(routeGuardProvider);
  final config = ref.watch(appConfigProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) => guard.redirectFor(state.matchedLocation),
    errorBuilder: (context, state) => Scaffold(
      body: NurivaStateView.error(
        title: 'That screen could not be opened',
        message: 'Go back and try again.',
        actionLabel: 'Go home',
        onAction: () => context.go(AppRoutes.home),
      ),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const FoundationHomeScreen(),
      ),
      // Developer-only. Registered at all only outside production, so the
      // route cannot be reached in a prod build even by deep link.
      if (config.allowDeveloperTools)
        GoRoute(
          path: AppRoutes.gallery,
          builder: (context, state) => const DesignGalleryScreen(),
        ),
    ],
  );
});
