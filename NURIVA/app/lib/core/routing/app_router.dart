import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/application/session_route_guard.dart';
import 'package:nuriva/features/auth/presentation/complete_profile_screen.dart';
import 'package:nuriva/features/auth/presentation/forgot_password_screen.dart';
import 'package:nuriva/features/auth/presentation/privacy_notice_screen.dart';
import 'package:nuriva/features/auth/presentation/register_screen.dart';
import 'package:nuriva/features/auth/presentation/sign_in_screen.dart';
import 'package:nuriva/features/auth/presentation/verify_email_screen.dart';
import 'package:nuriva/features/auth/presentation/welcome_screen.dart';
import 'package:nuriva/features/design_gallery/presentation/design_gallery_screen.dart';
import 'package:nuriva/features/home/presentation/home_screen.dart';
import 'package:nuriva/features/splash/presentation/splash_screen.dart';

/// The application router — the composition root for navigation.
///
/// Redirects are driven by [sessionProvider]: whenever the session changes
/// (sign-in, sign-out, verification, profile saved) the router re-evaluates
/// the current location, so no screen has to navigate on auth events itself.
final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);

  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  final guard = SessionRouteGuard(() => ref.read(sessionProvider));

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => guard.redirectFor(state.uri.toString()),
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
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyNoticeScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
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

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
