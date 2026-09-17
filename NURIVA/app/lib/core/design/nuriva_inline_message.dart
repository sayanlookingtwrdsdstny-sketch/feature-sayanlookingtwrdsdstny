import 'package:flutter/material.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// An inline message inside a form or card — typically why a submit failed.
///
/// Announced to screen readers as a live region, so a user who cannot see the
/// banner still hears why nothing happened.
final class NurivaInlineMessage extends StatelessWidget {
  const NurivaInlineMessage({
    required this.message,
    this.status = NurivaStatus.danger,
    super.key,
  });

  final String message;
  final NurivaStatus status;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.of(status, context.colors);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(NurivaTokens.space4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? .16 : .09),
          borderRadius: NurivaTokens.brMd,
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              switch (status) {
                NurivaStatus.danger => Icons.error_outline,
                NurivaStatus.warning => Icons.warning_amber_outlined,
                NurivaStatus.positive => Icons.check_circle_outline,
                _ => Icons.info_outline,
              },
              color: color,
              size: 22,
            ),
            const SizedBox(width: NurivaTokens.space3),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
