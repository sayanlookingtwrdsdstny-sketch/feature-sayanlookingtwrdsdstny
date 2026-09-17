import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';

/// First screen for a signed-out user.
final class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              Color.lerp(
                scheme.surface,
                NurivaTokens.brand,
                context.isDark ? .14 : .06,
              )!,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: NurivaTokens.pageInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: NurivaTokens.space12),
                      const Center(child: NurivaWordmark(markSize: 80)),
                      const SizedBox(height: NurivaTokens.space8),
                      Text(
                        'Medication care,\nshared with family',
                        textAlign: TextAlign.center,
                        style: context.text.headlineMedium,
                      ),
                      const SizedBox(height: NurivaTokens.space8),
                      const _ValuePoint(
                        icon: Icons.notifications_active_outlined,
                        title: 'Reminders at the right time',
                        body: 'A clear alert for every dose, and one tap to '
                            'confirm.',
                      ),
                      const _ValuePoint(
                        icon: Icons.family_restroom_outlined,
                        title: 'Family can help',
                        body: 'A trusted family member can keep an eye on '
                            'missed doses.',
                      ),
                      const _ValuePoint(
                        icon: Icons.verified_user_outlined,
                        title: 'You stay in control',
                        body: 'Nothing is scheduled until a person has checked '
                            'and approved it.',
                      ),
                      const Spacer(),
                      const SizedBox(height: NurivaTokens.space8),
                      NurivaButton(
                        label: 'Create account',
                        onPressed: () => context.push(AppRoutes.register),
                      ),
                      const SizedBox(height: NurivaTokens.space3),
                      NurivaButton(
                        label: 'I already have an account',
                        variant: NurivaButtonVariant.secondary,
                        onPressed: () => context.push(AppRoutes.login),
                      ),
                      const SizedBox(height: NurivaTokens.space5),
                      Text(
                        'NURIVA helps you organise medication. It does not '
                        'give medical advice.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: NurivaTokens.space6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ValuePoint extends StatelessWidget {
  const _ValuePoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: NurivaTokens.space5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: context.isDark ? .18 : .1),
              borderRadius: NurivaTokens.brSm,
            ),
            child: Icon(icon, color: scheme.primary, size: 24),
          ),
          const SizedBox(width: NurivaTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: context.text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
