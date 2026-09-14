import 'package:flutter/material.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// A content container.
///
/// Border, fill and shadow are spent by role rather than stamped on every
/// block: a plain card sits flat on the page, and only [elevated] lifts. One
/// shadow everywhere flattens hierarchy instead of creating it.
final class NurivaCard extends StatelessWidget {
  const NurivaCard({
    required this.child,
    this.padding = const EdgeInsets.all(NurivaTokens.space5),
    this.onTap,
    this.elevated = false,
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Lifts the card off the page. Use only for something that genuinely floats.
  final bool elevated;

  /// Draws a 4dp status rail down the leading edge.
  ///
  /// From Module 11 this is how a dose row shows taken / late / missed at a
  /// glance without relying on text alone.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final content = Padding(padding: padding, child: child);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: NurivaTokens.brLg,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
        boxShadow: elevated
            ? NurivaTokens.shadowSoft(context.theme.brightness)
            : null,
      ),
      child: accent == null
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(NurivaTokens.radiusLg),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
    );

    if (onTap == null) return ClipRRect(borderRadius: NurivaTokens.brLg, child: decorated);

    return Material(
      color: Colors.transparent,
      borderRadius: NurivaTokens.brLg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: decorated),
    );
  }
}

/// A small labelled status pill.
///
/// Encodes state in shape and colour as well as words, so what needs attention
/// reads at a glance rather than requiring the user to parse a sentence.
final class NurivaStatusChip extends StatelessWidget {
  const NurivaStatusChip({
    required this.label,
    this.status = NurivaStatus.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final NurivaStatus status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.of(status, context.colors);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NurivaTokens.space3,
        vertical: NurivaTokens.space1 + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? .18 : .12),
        borderRadius: NurivaTokens.brPill,
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: NurivaTokens.space1 + 2),
          ],
          Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section divider for long screens.
final class NurivaSectionHeader extends StatelessWidget {
  const NurivaSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: NurivaTokens.space6,
        bottom: NurivaTokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: NurivaTokens.space1),
                  Text(
                    subtitle!,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A tappable row for lists and settings.
final class NurivaListTile extends StatelessWidget {
  const NurivaListTile({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.status,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Tints the leading icon to carry state.
  final NurivaStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tint = status == null
        ? scheme.primary
        : context.statusColors.of(status!, scheme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: NurivaTokens.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NurivaTokens.space4,
            vertical: NurivaTokens.space3,
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: context.isDark ? .18 : .1),
                    borderRadius: NurivaTokens.brSm,
                  ),
                  child: Icon(leadingIcon, color: tint, size: 22),
                ),
                const SizedBox(width: NurivaTokens.space4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: context.text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: NurivaTokens.space3),
                trailing!,
              ] else if (onTap != null)
                Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
