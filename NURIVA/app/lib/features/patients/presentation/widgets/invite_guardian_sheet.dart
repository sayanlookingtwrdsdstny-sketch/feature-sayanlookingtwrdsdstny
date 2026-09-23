import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/presentation/patient_copy.dart';

/// Opens the invite-a-guardian bottom sheet: choose permissions, generate a
/// code, share it. [myPermissions] bounds what can be granted — nobody can
/// hand out more access than they themselves hold.
Future<void> showInviteGuardianSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String patientId,
  required Set<GuardianPermission> myPermissions,
}) {
  return NurivaDialogs.sheet<void>(
    context,
    title: 'Invite a guardian',
    child: _InviteGuardianContent(
      patientId: patientId,
      myPermissions: myPermissions,
    ),
  );
}

final class _InviteGuardianContent extends ConsumerStatefulWidget {
  const _InviteGuardianContent({
    required this.patientId,
    required this.myPermissions,
  });

  final String patientId;
  final Set<GuardianPermission> myPermissions;

  @override
  ConsumerState<_InviteGuardianContent> createState() =>
      _InviteGuardianContentState();
}

class _InviteGuardianContentState
    extends ConsumerState<_InviteGuardianContent> {
  late final Set<GuardianPermission> _selected =
      GuardianPermission.defaults.intersection(widget.myPermissions);
  bool _busy = false;
  String? _code;
  String? _error;

  Future<void> _generate() async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null || _selected.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(careCircleServiceProvider).createLinkCode(
          patientId: widget.patientId,
          creatorUid: uid,
          requesterPermissions: widget.myPermissions,
          permissions: _selected,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _code = result.valueOrNull?.code;
      _error = result.failureOrNull == null
          ? null
          : PatientCopy.forFailure(result.failureOrNull!);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_code != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share this code. It expires in 24 hours and works once.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: NurivaTokens.space5),
          NurivaCard(
            child: Center(
              child: Text(
                _code!,
                style: context.text.headlineMedium?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: NurivaTokens.space5),
          NurivaButton(
            label: 'Copy code',
            icon: Icons.copy_outlined,
            variant: NurivaButtonVariant.secondary,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _code!));
              if (!context.mounted) return;
              NurivaDialogs.toast(context, 'Code copied.');
            },
          ),
          const SizedBox(height: NurivaTokens.space3),
          NurivaButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose what they can do. You can only grant permissions you have '
          'yourself.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        for (final permission in GuardianPermission.values)
          CheckboxListTile(
            value: _selected.contains(permission),
            enabled: widget.myPermissions.contains(permission),
            title: Text(_permissionLabel(permission)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (checked) {
              setState(() {
                if (checked ?? false) {
                  _selected.add(permission);
                } else {
                  _selected.remove(permission);
                }
              });
            },
          ),
        if (_error != null) ...[
          NurivaInlineMessage(message: _error!),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(
          label: 'Generate code',
          onPressed: _selected.isEmpty ? null : _generate,
          isBusy: _busy,
        ),
      ],
    );
  }

  String _permissionLabel(GuardianPermission permission) => switch (permission) {
        GuardianPermission.viewMedications => 'View medications',
        GuardianPermission.manageMedications =>
          'Manage medications (can activate a dosing schedule)',
        GuardianPermission.viewAdherence => 'View adherence & dose history',
        GuardianPermission.manageAppointments => 'Manage appointments',
        GuardianPermission.viewPrescriptions => 'View prescription images',
      };
}
