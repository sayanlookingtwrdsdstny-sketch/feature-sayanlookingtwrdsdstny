import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/di/providers.dart';
import 'package:nuriva/core/routing/app_routes.dart';

/// Module 01's home screen.
///
/// NURIVA has no patient data yet, so this screen is honest about that rather
/// than mocking up a dashboard with invented medications. It shows the real
/// build state and the roadmap, which is what is actually true and testable at
/// v0.1.0. Module 13 replaces it with the guardian dashboard.
final class FoundationHomeScreen extends ConsumerWidget {
  const FoundationHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final scheme = context.colors;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NurivaTokens.pageInset,
                  NurivaTokens.space6,
                  NurivaTokens.pageInset,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                    const SizedBox(height: NurivaTokens.space8),
                    Text(
                      'Foundation ready',
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: NurivaTokens.space3),
                    Text(
                      'The NURIVA foundation is in place. Medication features '
                      'arrive in the modules below.',
                      style: context.text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: NurivaTokens.space6),
                    _BuildCard(
                      version: '0.1.0',
                      flavor: config.flavor.name,
                    ),
                    const NurivaSectionHeader(
                      title: 'What is built',
                      subtitle: 'Module 01 — Foundation',
                    ),
                  ],
                ),
              ),
            ),
            SliverList.list(
              children: const [
                _FoundationItem(
                  icon: Icons.palette_outlined,
                  title: 'Design system',
                  subtitle: 'Tokens, buttons, cards, inputs, dialogs, states',
                ),
                _FoundationItem(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  subtitle: 'Light and dark, accessibility-first sizing',
                ),
                _FoundationItem(
                  icon: Icons.alt_route_outlined,
                  title: 'Routing',
                  subtitle: 'Declarative routes with an auth-guard seam',
                ),
                _FoundationItem(
                  icon: Icons.layers_outlined,
                  title: 'Architecture',
                  subtitle: 'Clean layers, Result type, dependency injection',
                ),
                _FoundationItem(
                  icon: Icons.shield_outlined,
                  title: 'Error handling and logging',
                  subtitle: 'Typed failures, logs with patient-data redaction',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NurivaTokens.pageInset,
                  0,
                  NurivaTokens.pageInset,
                  NurivaTokens.space12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NurivaSectionHeader(
                      title: 'Next',
                      subtitle: 'Not yet built',
                    ),
                    NurivaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Module 02 — Authentication',
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
                            'Sign in, registration and session management. '
                            'Needs a Firebase project, which fixes the data '
                            'region permanently.',
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Build identity card — the thing actually worth reading on a test build.
final class _BuildCard extends StatelessWidget {
  const _BuildCard({required this.version, required this.flavor});

  final String version;
  final String flavor;

  @override
  Widget build(BuildContext context) {
    return NurivaCard(
      accent: context.statusColors.taken,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version $version',
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Module 01 · $flavor build',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
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
    );
  }
}

final class _FoundationItem extends StatelessWidget {
  const _FoundationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NurivaTokens.space1,
      ),
      child: NurivaListTile(
        leadingIcon: icon,
        title: title,
        subtitle: subtitle,
        status: NurivaStatus.positive,
        trailing: Icon(
          Icons.check_circle,
          color: context.statusColors.taken,
          size: 22,
        ),
      ),
    );
  }
}
