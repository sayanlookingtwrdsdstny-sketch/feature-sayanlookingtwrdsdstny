import 'package:flutter/material.dart';
import 'package:nuriva/core/design/nuriva_button.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// Full-screen state view: loading, empty, error or success.
///
/// §7 of the product brief requires every important screen to handle these
/// states. Giving them one component means no screen invents its own — and,
/// more importantly, that none of them ship a bare spinner, which tells a
/// non-technical user nothing about what is happening.
final class NurivaStateView extends StatelessWidget {
  const NurivaStateView({
    required this.title,
    this.message,
    this.icon,
    this.status = NurivaStatus.neutral,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  }) : _isLoading = false;

  /// Loading state. Takes a message because "Loading…" alone is not an
  /// explanation.
  const NurivaStateView.loading({String message = 'Just a moment…', super.key})
      : title = message,
        message = null,
        icon = null,
        status = NurivaStatus.neutral,
        actionLabel = null,
        onAction = null,
        secondaryActionLabel = null,
        onSecondaryAction = null,
        _isLoading = true;

  /// Error state. Copy should say what happened and what to do — never an
  /// error code, never an apology.
  const NurivaStateView.error({
    required this.title,
    this.message,
    this.actionLabel = 'Try again',
    this.onAction,
    super.key,
  })  : icon = Icons.error_outline,
        status = NurivaStatus.danger,
        secondaryActionLabel = null,
        onSecondaryAction = null,
        _isLoading = false;

  /// Empty state, for a list with nothing in it yet.
  const NurivaStateView.empty({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  })  : status = NurivaStatus.neutral,
        secondaryActionLabel = null,
        onSecondaryAction = null,
        _isLoading = false;

  final String title;
  final String? message;
  final IconData? icon;
  final NurivaStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool _isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tint = context.statusColors.of(status, scheme);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NurivaTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const SizedBox.square(
                dimension: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else if (icon != null)
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: context.isDark ? .16 : .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: tint),
              ),
            const SizedBox(height: NurivaTokens.space6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: NurivaTokens.space3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: NurivaTokens.space8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: NurivaButton(
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: NurivaTokens.space2),
              NurivaButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
                variant: NurivaButtonVariant.text,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// NURIVA's dialogs and sheets.
///
/// Static helpers rather than widgets so a call site reads as an action
/// (`await NurivaDialogs.confirm(...)`) and always returns a typed answer.
abstract final class NurivaDialogs {
  /// Asks the user to confirm an action.
  ///
  /// Returns `true` only on explicit confirmation; dismissing returns `false`.
  /// Defaulting a dismissal to "no" is deliberate — in this product the
  /// confirmable actions are things like deleting a medication.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          NurivaTokens.space4,
          0,
          NurivaTokens.space4,
          NurivaTokens.space4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: context.colors.error,
                    foregroundColor: context.colors.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a modal bottom sheet with NURIVA's shape and insets.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: NurivaTokens.pageInset,
          right: NurivaTokens.pageInset,
          bottom: MediaQuery.of(context).viewInsets.bottom + NurivaTokens.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleLarge),
            const SizedBox(height: NurivaTokens.space4),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }

  /// Shows a transient confirmation message.
  static void toast(
    BuildContext context,
    String message, {
    NurivaStatus status = NurivaStatus.positive,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                switch (status) {
                  NurivaStatus.positive => Icons.check_circle_outline,
                  NurivaStatus.danger => Icons.error_outline,
                  NurivaStatus.warning => Icons.warning_amber_outlined,
                  _ => Icons.info_outline,
                },
                color: context.colors.onInverseSurface,
                size: 22,
              ),
              const SizedBox(width: NurivaTokens.space3),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
