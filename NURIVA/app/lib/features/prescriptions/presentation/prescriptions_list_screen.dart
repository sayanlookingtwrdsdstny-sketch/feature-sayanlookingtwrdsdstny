import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_copy.dart';
import 'package:nuriva/features/prescriptions/presentation/widgets/add_prescription_sheet.dart';

/// Every prescription recorded for one patient.
final class PrescriptionsListScreen extends ConsumerWidget {
  const PrescriptionsListScreen({required this.patientId, super.key});

  final String patientId;

  Future<void> _addPrescription(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;
    final created = await showAddPrescriptionSheet(
      context: context,
      ref: ref,
      patientId: patientId,
      uploadedByUid: uid,
    );
    if (created == true && context.mounted) {
      NurivaDialogs.toast(context, 'Prescription uploaded.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(prescriptionsForPatientProvider(patientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Prescriptions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPrescription(context, ref),
        tooltip: 'Add a prescription',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(prescriptionsForPatientProvider(patientId)),
          child: switch (prescriptions) {
            AsyncData(:final value) when value.isEmpty => ListView(
                children: const [
                  SizedBox(height: NurivaTokens.space16),
                  NurivaStateView.empty(
                    title: 'No prescriptions yet',
                    message: 'Tap the camera button to add the first one.',
                    icon: Icons.description_outlined,
                  ),
                ],
              ),
            AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  NurivaTokens.pageInset,
                  NurivaTokens.space4,
                  NurivaTokens.pageInset,
                  NurivaTokens.space16,
                ),
                children: [
                  for (final prescription in _sorted(value)) ...[
                    _PrescriptionTile(
                      prescription: prescription,
                      patientId: patientId,
                    ),
                    const SizedBox(height: NurivaTokens.space3),
                  ],
                ],
              ),
            AsyncError() => ListView(
                children: const [
                  SizedBox(height: NurivaTokens.space16),
                  NurivaStateView.error(
                    title: 'Could not load prescriptions',
                    message: 'Pull to retry.',
                  ),
                ],
              ),
            _ => const NurivaStateView.loading(),
          },
        ),
      ),
    );
  }

  List<Prescription> _sorted(List<Prescription> prescriptions) =>
      [...prescriptions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

final class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({required this.prescription, required this.patientId});

  final Prescription prescription;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return NurivaListTile(
      title: prescription.doctorName?.trim().isNotEmpty == true
          ? prescription.doctorName!
          : 'Prescription',
      subtitle:
          '${DateFormat.yMMMd().format(prescription.createdAt)} · '
          '${prescription.pageCount} page${prescription.pageCount == 1 ? '' : 's'}',
      leadingIcon: Icons.description_outlined,
      trailing: NurivaStatusChip(
        label: PrescriptionCopy.forStatus(prescription.status),
        status: NurivaStatus.info,
      ),
      onTap: () => context.push(
        AppRoutes.prescriptionDetailFor(patientId, prescription.id),
      ),
    );
  }
}
