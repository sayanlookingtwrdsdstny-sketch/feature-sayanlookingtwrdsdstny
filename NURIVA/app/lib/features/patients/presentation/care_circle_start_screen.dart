import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';

/// Shown once, the first time a signed-in user has no patient in their care
/// circle (ARCHITECTURE §5). Two entry points: create a patient they manage,
/// or join one someone else already created.
final class CareCircleStartScreen extends StatelessWidget {
  const CareCircleStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.family_restroom_outlined,
      title: 'Who are you here for?',
      subtitle: 'Add someone you care for, or join a family member who has '
          'already added them.',
      children: [
        NurivaCard(
          onTap: () => context.push(AppRoutes.addPatient),
          child: const _StartOption(
            icon: Icons.person_add_alt_outlined,
            title: 'Add a patient',
            description: "I'm setting up medication reminders for someone — "
                'myself or a family member.',
          ),
        ),
        const SizedBox(height: NurivaTokens.space4),
        NurivaCard(
          onTap: () => context.push(AppRoutes.joinPatient),
          child: const _StartOption(
            icon: Icons.qr_code_outlined,
            title: 'Enter a link code',
            description: 'A family member already added a patient and gave '
                'me a code to join as a guardian.',
          ),
        ),
      ],
    );
  }
}

final class _StartOption extends StatelessWidget {
  const _StartOption({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: context.isDark ? .18 : .1),
            borderRadius: NurivaTokens.brMd,
          ),
          child: Icon(icon, color: scheme.primary),
        ),
        const SizedBox(width: NurivaTokens.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleMedium),
              const SizedBox(height: NurivaTokens.space1),
              Text(
                description,
                style: context.text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );
  }
}
