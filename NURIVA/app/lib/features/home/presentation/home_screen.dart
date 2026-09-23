import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/config/app_version.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

/// Home for a signed-in user.
///
/// NURIVA has no medication data yet, so this is honest about that instead of
/// mocking a dashboard with invented doses. It shows the account and the build
/// state — what is actually true at this version. Module 13 replaces it with
/// the guardian dashboard.
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await NurivaDialogs.confirm(
      context,
      title: 'Sign out of NURIVA?',
      message: "You'll need your email and password to sign back in.",
      confirmLabel: 'Sign out',
    );
    if (ok) await ref.read(accountServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
    final scheme = context.colors;

    if (session is! SignedIn) {
      return const Scaffold(body: NurivaStateView.loading());
    }
    final profile = session.profile;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NurivaTokens.pageInset,
            NurivaTokens.space4,
            NurivaTokens.pageInset,
            NurivaTokens.space12,
          ),
          children: [
            Row(
              children: [
                const NurivaMark(size: 40),
                const SizedBox(width: NurivaTokens.space3),
                Expanded(
                  child: Text(
                    'NURIVA',
                    style: TextStyle(
                      fontSize: NurivaTokens.fontTitle,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (config.allowDeveloperTools)
                  IconButton(
                    onPressed: () => context.push(AppRoutes.gallery),
                    icon: const Icon(Icons.palette_outlined),
                    tooltip: 'Design system',
                  ),
                IconButton(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                ),
              ],
            ),
            const SizedBox(height: NurivaTokens.space8),
            Text(
              'Hello, ${profile.firstName}',
              style: context.text.headlineMedium,
            ),
            const SizedBox(height: NurivaTokens.space2),
            Text(
              "You're signed in. Medication features arrive in the next "
              'modules.',
              style: context.text.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: NurivaTokens.space6),
            _AccountCard(profile: profile),
            const SizedBox(height: NurivaTokens.space3),
            NurivaButton(
              label: 'Patients',
              icon: Icons.family_restroom_outlined,
              variant: NurivaButtonVariant.secondary,
              onPressed: () => context.push(AppRoutes.family),
            ),
            const SizedBox(height: NurivaTokens.space3),
            NurivaButton(
              label: 'Prescriptions',
              icon: Icons.description_outlined,
              variant: NurivaButtonVariant.secondary,
              onPressed: () => context.push(AppRoutes.prescriptions),
            ),
            const SizedBox(height: NurivaTokens.space3),
            NurivaCard(
              accent: context.statusColors.taken,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version ${AppVersion.name}',
                          style: context.text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Module ${AppVersion.module} · '
                          '${config.flavor.name} build',
                          style: context.text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const NurivaStatusChip(
                    label: 'Ready',
                    status: NurivaStatus.positive,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
            ),
            const NurivaSectionHeader(
              title: 'What is built',
              subtitle: 'Modules 01–06',
            ),
            const _BuiltItem(
              icon: Icons.lock_person_outlined,
              title: 'Sign-in and accounts',
              subtitle: 'Registration, email confirmation, password reset',
            ),
            const _BuiltItem(
              icon: Icons.family_restroom_outlined,
              title: 'Patients & guardians',
              subtitle: 'Add a patient, invite/approve/revoke guardians, '
                  'link codes',
            ),
            const _BuiltItem(
              icon: Icons.description_outlined,
              title: 'Prescription upload',
              subtitle: 'Camera/gallery capture, saved on-device — see the '
                  "prescription's detail screen for why",
            ),
            const _BuiltItem(
              icon: Icons.document_scanner_outlined,
              title: 'Reading a prescription',
              subtitle: 'Your phone reads the text on the photo — nothing is '
                  'sent anywhere, and nothing is scheduled from it',
            ),
            const _BuiltItem(
              icon: Icons.fact_check_outlined,
              title: 'Checking a prescription',
              subtitle: 'Read it against the photo and record each medicine — '
                  'nothing is scheduled until a guardian approves it',
            ),
            const _BuiltItem(
              icon: Icons.palette_outlined,
              title: 'Design system',
              subtitle: 'Tokens, buttons, cards, inputs, dialogs, states',
            ),
            const _BuiltItem(
              icon: Icons.layers_outlined,
              title: 'Architecture',
              subtitle: 'Clean layers, typed errors, dependency injection',
            ),
            const NurivaSectionHeader(title: 'Next', subtitle: 'Not yet built'),
            NurivaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Module 07 — Guardian Approval',
                          style: context.text.titleMedium,
                        ),
                      ),
                      const NurivaStatusChip(
                        label: 'Pending',
                        status: NurivaStatus.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: NurivaTokens.space2),
                  Text(
                    'A guardian approves a medicine before any reminder is '
                    'ever scheduled.',
                    style: context.text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return NurivaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your account', style: context.text.titleMedium),
          const SizedBox(height: 2),
          Text(
            profile.email,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: NurivaTokens.space3),
          Wrap(
            spacing: NurivaTokens.space2,
            runSpacing: NurivaTokens.space2,
            children: [
              if (profile.isPatient)
                const NurivaStatusChip(
                  label: 'My medication',
                  status: NurivaStatus.info,
                  icon: Icons.person_outline,
                ),
              if (profile.isGuardian)
                const NurivaStatusChip(
                  label: 'Caring for family',
                  status: NurivaStatus.info,
                  icon: Icons.family_restroom_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _BuiltItem extends StatelessWidget {
  const _BuiltItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return NurivaListTile(
      leadingIcon: icon,
      title: title,
      subtitle: subtitle,
      status: NurivaStatus.positive,
      trailing: Icon(
        Icons.check_circle,
        color: context.statusColors.taken,
        size: 22,
      ),
    );
  }
}
