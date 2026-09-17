import 'package:flutter/material.dart';
import 'package:nuriva/core/design/design.dart';

/// Shared layout for every sign-in and account screen.
///
/// One layout means the title, spacing and width behave identically across the
/// flow, so moving between screens never feels like switching apps. Content is
/// a scrolling column rather than a `ListView`: a lazy list would not build
/// off-screen form fields, and their validators would silently never run.
final class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.footer,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Optional badge above the title, for confirmation-style screens.
  final IconData? icon;

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                NurivaTokens.pageInset,
                NurivaTokens.space2,
                NurivaTokens.pageInset,
                NurivaTokens.space10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (icon != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: context.isDark ? .18 : .1,
                          ),
                          borderRadius: NurivaTokens.brMd,
                        ),
                        child: Icon(icon, color: scheme.primary, size: 32),
                      ),
                    ),
                    const SizedBox(height: NurivaTokens.space5),
                  ],
                  Text(title, style: context.text.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: NurivaTokens.space2),
                    Text(
                      subtitle!,
                      style: context.text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: NurivaTokens.space8),
                  ...children,
                  if (footer != null) ...[
                    const SizedBox(height: NurivaTokens.space6),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Question? Action" footer line used under auth forms.
final class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    required this.prompt,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        NurivaButton(
          label: actionLabel,
          variant: NurivaButtonVariant.text,
          onPressed: onAction,
        ),
      ],
    );
  }
}
