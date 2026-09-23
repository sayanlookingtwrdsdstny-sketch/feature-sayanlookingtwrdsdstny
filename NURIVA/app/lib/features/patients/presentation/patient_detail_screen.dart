import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/presentation/patient_copy.dart';
import 'package:nuriva/features/patients/presentation/widgets/invite_guardian_sheet.dart';

/// One patient: who guards them, who is waiting on approval, and an invite
/// action for the guardians who already have access.
final class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authUserProvider).value?.uid;
    final myRelationship = ref.watch(myRelationshipProvider(patientId));
    final relationships = ref.watch(relationshipsForPatientProvider(patientId));
    final self = ref.watch(selfPatientProvider).value;
    final guarded = ref.watch(guardianPatientsProvider).value ?? const [];
    Patient? patient = self?.id == patientId ? self : null;
    if (patient == null) {
      for (final p in guarded) {
        if (p.id == patientId) {
          patient = p;
          break;
        }
      }
    }

    final mine = myRelationship.value;
    final isPrimary = mine?.isPrimary ?? false;
    final isActiveGuardian = mine?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(patient?.displayName ?? 'Patient')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NurivaTokens.pageInset,
            NurivaTokens.space4,
            NurivaTokens.pageInset,
            NurivaTokens.space10,
          ),
          children: [
            if (patient != null)
              NurivaCard(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 32),
                    const SizedBox(width: NurivaTokens.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.displayName, style: context.text.titleLarge),
                          Text(
                            _dobLabel(patient),
                            style: context.text.bodyMedium
                                ?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: NurivaTokens.space6),
            if (isActiveGuardian)
              NurivaButton(
                label: 'Invite a guardian',
                icon: Icons.person_add_alt_outlined,
                variant: NurivaButtonVariant.secondary,
                onPressed: () => showInviteGuardianSheet(
                  context: context,
                  ref: ref,
                  patientId: patientId,
                  myPermissions: mine!.permissions,
                ),
              ),
            const SizedBox(height: NurivaTokens.space6),
            switch (relationships) {
              AsyncData(:final value) => _RelationshipLists(
                  relationships: value,
                  patientId: patientId,
                  myUid: uid,
                  isPrimary: isPrimary,
                ),
              AsyncError() => const NurivaCard(
                  child: Text('Could not load guardians. Pull to retry.'),
                ),
              _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: NurivaTokens.space6),
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
          ],
        ),
      ),
    );
  }

  String _dobLabel(Patient patient) {
    if (patient.dob.millisecondsSinceEpoch == 0) return '';
    return 'Born ${patient.dob.year}-${patient.dob.month.toString().padLeft(2, '0')}-'
        '${patient.dob.day.toString().padLeft(2, '0')}';
  }
}

final class _RelationshipLists extends ConsumerWidget {
  const _RelationshipLists({
    required this.relationships,
    required this.patientId,
    required this.myUid,
    required this.isPrimary,
  });

  final List<GuardianRelationship> relationships;
  final String patientId;
  final String? myUid;
  final bool isPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        relationships.where((r) => r.status == RelationshipStatus.pending);
    final active =
        relationships.where((r) => r.status == RelationshipStatus.active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPrimary && pending.isNotEmpty) ...[
          const NurivaSectionHeader(title: 'Waiting for your approval'),
          for (final r in pending) ...[
            _PendingTile(relationship: r),
            const SizedBox(height: NurivaTokens.space3),
          ],
          const SizedBox(height: NurivaTokens.space4),
        ],
        const NurivaSectionHeader(title: 'Guardians'),
        for (final r in active) ...[
          _ActiveGuardianTile(
            relationship: r,
            canRevoke: isPrimary && !r.isPrimary ||
                (!r.isPrimary && r.guardianUid == myUid),
          ),
          const SizedBox(height: NurivaTokens.space3),
        ],
      ],
    );
  }
}

final class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.relationship});

  final GuardianRelationship relationship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NurivaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NurivaStatusChip(label: 'Pending', status: NurivaStatus.warning),
          const SizedBox(height: NurivaTokens.space2),
          Text(
            'A guardian is waiting to be approved.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: NurivaTokens.space3),
          Row(
            children: [
              Expanded(
                child: NurivaButton(
                  label: 'Reject',
                  variant: NurivaButtonVariant.destructive,
                  size: NurivaButtonSize.standard,
                  onPressed: () => _respond(context, ref, approve: false),
                ),
              ),
              const SizedBox(width: NurivaTokens.space3),
              Expanded(
                child: NurivaButton(
                  label: 'Approve',
                  size: NurivaButtonSize.standard,
                  onPressed: () => _respond(context, ref, approve: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;
    final service = ref.read(careCircleServiceProvider);
    final result = approve
        ? await service.approveRelationship(
            relationshipId: relationship.id,
            responderUid: uid,
          )
        : await service.rejectRelationship(
            relationshipId: relationship.id,
            responderUid: uid,
          );
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => NurivaDialogs.toast(
        context,
        approve ? 'Guardian approved.' : 'Request rejected.',
      ),
      onFailure: (failure) => NurivaDialogs.toast(
        context,
        PatientCopy.forFailure(failure),
        status: NurivaStatus.danger,
      ),
    );
  }
}

final class _ActiveGuardianTile extends ConsumerWidget {
  const _ActiveGuardianTile({
    required this.relationship,
    required this.canRevoke,
  });

  final GuardianRelationship relationship;
  final bool canRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authUserProvider).value?.uid;
    final isSelf = relationship.guardianUid == uid;

    return NurivaListTile(
      title: relationship.isPrimary
          ? 'Primary guardian${isSelf ? ' (you)' : ''}'
          : 'Guardian${isSelf ? ' (you)' : ''}',
      subtitle: relationship.permissions.map((p) => p.wire).join(', '),
      leadingIcon: Icons.shield_outlined,
      trailing: canRevoke
          ? IconButton(
              onPressed: () => _revoke(context, ref),
              icon: Icon(
                isSelf ? Icons.logout : Icons.person_remove_outlined,
              ),
              tooltip: isSelf ? 'Leave' : 'Revoke',
            )
          : null,
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;
    final isSelf = relationship.guardianUid == uid;
    final confirmed = await NurivaDialogs.confirm(
      context,
      title: isSelf ? 'Leave this patient?' : 'Revoke this guardian?',
      message: isSelf
          ? "You'll lose access and will need a new invite to rejoin."
          : 'They will lose access immediately.',
      confirmLabel: isSelf ? 'Leave' : 'Revoke',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await ref.read(careCircleServiceProvider).revokeRelationship(
          relationshipId: relationship.id,
          actorUid: uid,
        );
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => NurivaDialogs.toast(context, 'Removed.'),
      onFailure: (failure) => NurivaDialogs.toast(
        context,
        PatientCopy.forFailure(failure),
        status: NurivaStatus.danger,
      ),
    );
  }
}
