import 'package:flutter/material.dart';
import 'package:nuriva/core/design/design.dart';

/// A live catalogue of the NURIVA design system.
///
/// **Developer-only.** It is reachable only when `AppConfig.allowDeveloperTools`
/// is true, which is never the case in a production flavor — §9 of the brief
/// says not to add screens end users do not need.
///
/// It earns its place during development: it is how the design system gets
/// verified on a real device across light/dark and large font settings, which
/// is exactly the check that catches contrast and overflow problems before they
/// reach a dose reminder screen.
final class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  bool _busy = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _simulateWork() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _busy = false);
    NurivaDialogs.toast(context, 'Action completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          NurivaTokens.pageInset,
          0,
          NurivaTokens.pageInset,
          NurivaTokens.space12,
        ),
        children: [
          const NurivaSectionHeader(
            title: 'Brand',
            subtitle: 'Mark and wordmark',
          ),
          NurivaCard(
            child: Center(
              child: Column(
                children: [
                  const NurivaWordmark(markSize: 64, showTagline: true),
                  const SizedBox(height: NurivaTokens.space6),
                  Wrap(
                    spacing: NurivaTokens.space4,
                    children: [
                      const NurivaMark(size: 32),
                      const NurivaMark(size: 44),
                      NurivaMark(size: 44, color: context.statusColors.missed),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const NurivaSectionHeader(
            title: 'Buttons',
            subtitle: 'One primary action per screen',
          ),
          NurivaButton.hero(
            label: 'TAKEN',
            icon: Icons.check_circle_outline,
            onPressed: _busy ? null : _simulateWork,
            isBusy: _busy,
          ),
          const SizedBox(height: NurivaTokens.space3),
          NurivaButton(
            label: 'Primary action',
            onPressed: _busy ? null : _simulateWork,
            isBusy: _busy,
          ),
          const SizedBox(height: NurivaTokens.space3),
          NurivaButton(
            label: 'Secondary action',
            variant: NurivaButtonVariant.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: NurivaTokens.space3),
          NurivaButton(
            label: 'Delete medication',
            icon: Icons.delete_outline,
            variant: NurivaButtonVariant.destructive,
            onPressed: () async {
              final ok = await NurivaDialogs.confirm(
                context,
                title: 'Delete this medication?',
                message: 'Its schedule and future reminders will be removed. '
                    'Doses already recorded are kept.',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (!context.mounted) return;
              NurivaDialogs.toast(
                context,
                ok ? 'Deleted' : 'Cancelled',
                status: ok ? NurivaStatus.danger : NurivaStatus.neutral,
              );
            },
          ),
          const SizedBox(height: NurivaTokens.space2),
          NurivaButton(
            label: 'Disabled',
            onPressed: null,
          ),
          const SizedBox(height: NurivaTokens.space2),
          Center(
            child: NurivaButton(
              label: 'Text action',
              variant: NurivaButtonVariant.text,
              onPressed: () {},
            ),
          ),

          const NurivaSectionHeader(
            title: 'Status',
            subtitle: 'Dose states carry colour and shape',
          ),
          NurivaCard(
            child: Wrap(
              spacing: NurivaTokens.space2,
              runSpacing: NurivaTokens.space2,
              children: const [
                NurivaStatusChip(
                  label: 'Taken',
                  status: NurivaStatus.positive,
                  icon: Icons.check,
                ),
                NurivaStatusChip(
                  label: 'Due',
                  status: NurivaStatus.info,
                  icon: Icons.schedule,
                ),
                NurivaStatusChip(
                  label: 'Late',
                  status: NurivaStatus.warning,
                  icon: Icons.hourglass_bottom,
                ),
                NurivaStatusChip(
                  label: 'Missed',
                  status: NurivaStatus.danger,
                  icon: Icons.close,
                ),
                NurivaStatusChip(label: 'Skipped'),
              ],
            ),
          ),

          const NurivaSectionHeader(title: 'Cards and rows'),
          NurivaCard(
            accent: context.statusColors.missed,
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Elevated card with status rail',
                    style: context.text.titleMedium),
                const SizedBox(height: NurivaTokens.space2),
                Text(
                  'A rail plus a chip means state reads at a glance, without '
                  'depending on colour alone.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NurivaTokens.space3),
          NurivaListTile(
            leadingIcon: Icons.medication_outlined,
            title: 'List row',
            subtitle: 'With leading icon and chevron',
            onTap: () {},
          ),

          const NurivaSectionHeader(
            title: 'Inputs',
            subtitle: 'Persistent labels, validation on submit',
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                const NurivaTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: NurivaTokens.space5),
                NurivaTextField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  helper: 'Tap the eye to reveal',
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Use at least 8 characters'
                      : null,
                ),
                const SizedBox(height: NurivaTokens.space4),
                NurivaButton(
                  label: 'Validate form',
                  variant: NurivaButtonVariant.secondary,
                  onPressed: () => _formKey.currentState?.validate(),
                ),
              ],
            ),
          ),

          const NurivaSectionHeader(title: 'Overlays'),
          NurivaButton(
            label: 'Open bottom sheet',
            variant: NurivaButtonVariant.secondary,
            onPressed: () => NurivaDialogs.sheet<void>(
              context,
              title: 'Move to tomorrow?',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This records the dose as moved and keeps it in history.',
                    style: context.text.bodyLarge,
                  ),
                  const SizedBox(height: NurivaTokens.space6),
                  NurivaButton(
                    label: 'Move',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          const NurivaSectionHeader(
            title: 'States',
            subtitle: 'Loading, empty and error',
          ),
          _StatePreview(
            child: const NurivaStateView.loading(
              message: 'Checking today\'s medication…',
            ),
          ),
          const SizedBox(height: NurivaTokens.space3),
          _StatePreview(
            child: NurivaStateView.empty(
              title: 'No prescriptions yet',
              message: 'Upload a prescription to get started.',
              icon: Icons.description_outlined,
              actionLabel: 'Upload',
              onAction: () {},
            ),
          ),
          const SizedBox(height: NurivaTokens.space3),
          _StatePreview(
            child: NurivaStateView.error(
              title: 'Could not load medications',
              message: 'Check your connection and try again.',
              onAction: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// Frames a full-screen state view at a readable size inside the gallery.
final class _StatePreview extends StatelessWidget {
  const _StatePreview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: NurivaTokens.brLg,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
