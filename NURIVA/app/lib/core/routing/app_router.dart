import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/application/session_route_guard.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/presentation/complete_profile_screen.dart';
import 'package:nuriva/features/auth/presentation/forgot_password_screen.dart';
import 'package:nuriva/features/auth/presentation/privacy_notice_screen.dart';
import 'package:nuriva/features/auth/presentation/register_screen.dart';
import 'package:nuriva/features/auth/presentation/sign_in_screen.dart';
import 'package:nuriva/features/auth/presentation/verify_email_screen.dart';
import 'package:nuriva/features/auth/presentation/welcome_screen.dart';
import 'package:nuriva/features/design_gallery/presentation/design_gallery_screen.dart';
import 'package:nuriva/features/home/presentation/home_screen.dart';
import 'package:nuriva/features/patients/application/care_circle_route_guard.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/presentation/add_patient_screen.dart';
import 'package:nuriva/features/patients/presentation/care_circle_start_screen.dart';
import 'package:nuriva/features/patients/presentation/join_patient_screen.dart';
import 'package:nuriva/features/patients/presentation/patient_detail_screen.dart';
import 'package:nuriva/features/patients/presentation/patients_list_screen.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_detail_screen.dart';
import 'package:nuriva/features/verification/presentation/verify_prescription_screen.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_patient_picker_screen.dart';
import 'package:nuriva/features/prescriptions/presentation/prescriptions_list_screen.dart';
import 'package:nuriva/features/splash/presentation/splash_screen.dart';

/// The application router — the composition root for navigation.
///
/// Redirects are driven by [sessionProvider] and [hasCareCircleProvider]:
/// whenever either changes (sign-in, sign-out, verification, profile saved,
/// a patient created or an invite approved) the router re-evaluates the
/// current location, so no screen has to navigate on those events itself.
final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);

  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(hasCareCircleProvider, (_, _) => refresh.value++);

  final sessionGuard = SessionRouteGuard(() => ref.read(sessionProvider));
  final careCircleGuard =
      CareCircleRouteGuard(() => ref.read(hasCareCircleProvider));

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.uri.toString();
      final sessionRedirect = sessionGuard.redirectFor(location);
      if (sessionRedirect != null) return sessionRedirect;

      // Care-circle onboarding only applies once auth is fully resolved —
      // SessionRouteGuard already sent anything but a SignedIn user
      // elsewhere, so reading the session here is just to gate the check,
      // not to duplicate SessionRouteGuard's own redirect logic.
      if (ref.read(sessionProvider) is! SignedIn) return null;
      return careCircleGuard.redirectFor(location);
    },
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
      GoRoute(
        path: AppRoutes.careCircleStart,
        builder: (context, state) => const CareCircleStartScreen(),
      ),
      GoRoute(
        path: AppRoutes.addPatient,
        builder: (context, state) => const AddPatientScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinPatient,
        builder: (context, state) => const JoinPatientScreen(),
      ),
      GoRoute(
        path: AppRoutes.family,
        builder: (context, state) => const PatientsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.patientDetail,
        builder: (context, state) => PatientDetailScreen(
          patientId: state.pathParameters['patientId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.prescriptions,
        builder: (context, state) => const PrescriptionPatientPickerScreen(),
      ),
      GoRoute(
        path: AppRoutes.prescriptionsForPatient,
        builder: (context, state) => PrescriptionsListScreen(
          patientId: state.pathParameters['patientId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.prescriptionDetail,
        builder: (context, state) => PrescriptionDetailScreen(
          patientId: state.pathParameters['patientId']!,
          prescriptionId: state.pathParameters['prescriptionId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.prescriptionVerify,
        builder: (context, state) => VerifyPrescriptionScreen(
          patientId: state.pathParameters['patientId']!,
          prescriptionId: state.pathParameters['prescriptionId']!,
        ),
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
