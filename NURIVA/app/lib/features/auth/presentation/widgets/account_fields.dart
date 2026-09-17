import 'package:flutter/material.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/presentation/auth_copy.dart';

/// The three ways someone uses NURIVA, in everyday words.
///
/// The screen never says "patient" or "guardian" — those are system roles, not
/// how a person describes themselves.
enum RoleChoice {
  self(
    Icons.person_outline,
    'Myself',
    'I take medication and want reminders',
    {UserRole.patient},
  ),
  family(
    Icons.family_restroom_outlined,
    'A family member',
    'I help someone else with their medication',
    {UserRole.guardian},
  ),
  both(
    Icons.groups_outlined,
    'Both',
    "My own medication and a family member's",
    {UserRole.patient, UserRole.guardian},
  );

  const RoleChoice(this.icon, this.title, this.description, this.roles);

  final IconData icon;
  final String title;
  final String description;
  final Set<UserRole> roles;
}

/// Form field for choosing a [RoleChoice].
final class RoleChoiceField extends FormField<RoleChoice> {
  RoleChoiceField({super.key, super.initialValue})
      : super(
          validator: (value) =>
              value == null ? AuthCopy.forField('roles', 'empty') : null,
          builder: (state) => _RoleChoiceGroup(state: state),
        );
}

final class _RoleChoiceGroup extends StatelessWidget {
  const _RoleChoiceGroup({required this.state});

  final FormFieldState<RoleChoice> state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: NurivaTokens.space1,
            bottom: NurivaTokens.space2,
          ),
          child: Text(
            "Who will you manage medication for?",
            style: context.text.titleMedium,
          ),
        ),
        for (final choice in RoleChoice.values) ...[
          _RoleOption(
            choice: choice,
            selected: state.value == choice,
            onTap: () => state.didChange(choice),
          ),
          const SizedBox(height: NurivaTokens.space2),
        ],
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(left: NurivaTokens.space1),
            child: Text(
              state.errorText!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
      ],
    );
  }
}

final class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final RoleChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.title}. ${choice.description}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: NurivaTokens.brMd,
          child: AnimatedContainer(
            duration: NurivaTokens.durationFast,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(
              horizontal: NurivaTokens.space4,
              vertical: NurivaTokens.space3,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: context.isDark ? .16 : .07)
                  : scheme.surfaceContainerLow,
              borderRadius: NurivaTokens.brMd,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  choice.icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: NurivaTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(choice.title, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        choice.description,
                        style: context.text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: NurivaTokens.space2),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The DPDP consent checkbox.
///
/// Unticked by default — consent under the DPDP Act must be a clear
/// affirmative act, so a pre-ticked box would not count.
final class ConsentField extends FormField<bool> {
  ConsentField({required VoidCallback onReadNotice, super.key})
      : super(
          initialValue: false,
          validator: (value) => value == true
              ? null
              : AuthCopy.forField('consent', 'required'),
          builder: (state) =>
              _ConsentBody(state: state, onReadNotice: onReadNotice),
        );
}

final class _ConsentBody extends StatelessWidget {
  const _ConsentBody({required this.state, required this.onReadNotice});

  final FormFieldState<bool> state;
  final VoidCallback onReadNotice;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final checked = state.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => state.didChange(!checked),
          borderRadius: NurivaTokens.brMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NurivaTokens.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: checked,
                  onChanged: (v) => state.didChange(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
                const SizedBox(width: NurivaTokens.space1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: NurivaTokens.space3),
                    child: Text(
                      'I agree that NURIVA can store and use my health '
                      'information to provide reminders, and share it only '
                      'with family members I approve.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: NurivaTokens.space10),
          child: NurivaButton(
            label: 'Read the privacy notice',
            variant: NurivaButtonVariant.text,
            onPressed: onReadNotice,
          ),
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(left: NurivaTokens.space1),
            child: Text(
              state.errorText!,
              style: context.text.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
