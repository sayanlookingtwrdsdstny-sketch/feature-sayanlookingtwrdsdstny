import 'package:flutter/material.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// Emphasis level of a [NurivaButton].
enum NurivaButtonVariant {
  /// The one action the screen exists for. At most one per screen.
  primary,

  /// A real alternative the user might reasonably choose.
  secondary,

  /// Irreversible or data-losing. Visually distinct so it is never mistaken
  /// for the primary path.
  destructive,

  /// Low-emphasis, for tertiary escapes ("Not now", "Learn more").
  text,
}

/// Size of a [NurivaButton].
enum NurivaButtonSize {
  /// Standard control height.
  standard,

  /// Oversized. Reserved for the dominant action on a screen — from Module 10
  /// this is what TAKEN uses on a medication reminder.
  hero,
}

/// NURIVA's button.
///
/// Two behaviours are built in rather than left to each call site, because
/// forgetting either has real consequences in this product:
///
/// * **Busy state.** While [onPressed] is in flight the button disables itself
///   and shows a spinner. Without this, a patient tapping twice on a slow
///   network can record the same dose twice.
/// * **Full-width by default.** A predictable, large hit area matters more than
///   visual variety for an elderly audience.
final class NurivaButton extends StatelessWidget {
  const NurivaButton({
    required this.label,
    required this.onPressed,
    this.variant = NurivaButtonVariant.primary,
    this.size = NurivaButtonSize.standard,
    this.icon,
    this.isBusy = false,
    this.expand = true,
    super.key,
  });

  /// Convenience constructor for the dominant action on a screen.
  const NurivaButton.hero({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    super.key,
  })  : variant = NurivaButtonVariant.primary,
        size = NurivaButtonSize.hero,
        expand = true;

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  final NurivaButtonVariant variant;
  final NurivaButtonSize size;
  final IconData? icon;

  /// Shows a spinner and blocks input while an action is running.
  final bool isBusy;

  /// Whether the button fills the available width.
  final bool expand;

  bool get _enabled => onPressed != null && !isBusy;

  double get _height => size == NurivaButtonSize.hero
      ? NurivaTokens.primaryActionHeight
      : NurivaTokens.controlHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final child = _buildChild(context);

    final button = switch (variant) {
      NurivaButtonVariant.primary => FilledButton(
          onPressed: _enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(_height),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
          ),
          child: child,
        ),
      NurivaButtonVariant.destructive => FilledButton(
          onPressed: _enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(_height),
            backgroundColor: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
            shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
          ),
          child: child,
        ),
      NurivaButtonVariant.secondary => OutlinedButton(
          onPressed: _enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(_height),
            foregroundColor: scheme.onSurface,
            shape: RoundedRectangleBorder(borderRadius: NurivaTokens.brMd),
          ),
          child: child,
        ),
      NurivaButtonVariant.text => TextButton(
          onPressed: _enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(0, NurivaTokens.minTouchTarget),
            foregroundColor: scheme.primary,
          ),
          child: child,
        ),
    };

    if (!expand || variant == NurivaButtonVariant.text) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildChild(BuildContext context) {
    if (isBusy) {
      return SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: variant == NurivaButtonVariant.primary
              ? context.colors.onPrimary
              : context.colors.primary,
        ),
      );
    }

    final textStyle = TextStyle(
      fontSize: size == NurivaButtonSize.hero
          ? NurivaTokens.fontTitle
          : NurivaTokens.fontBody,
      fontWeight: FontWeight.w600,
    );

    if (icon == null) {
      return Text(label, style: textStyle, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: size == NurivaButtonSize.hero ? 28 : 22),
        const SizedBox(width: NurivaTokens.space2),
        Flexible(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
