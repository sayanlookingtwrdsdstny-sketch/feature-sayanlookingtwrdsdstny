import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_copy.dart';

/// One prescription: its pages (where available on this device) and its
/// metadata, with a delete action while it's still `UPLOADED`.
final class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({
    required this.patientId,
    required this.prescriptionId,
    super.key,
  });

  final String patientId;
  final String prescriptionId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await NurivaDialogs.confirm(
      context,
      title: 'Delete this prescription?',
      message: 'This removes it for everyone. Images on other devices, if '
          'any, are not affected.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await ref.read(prescriptionServiceProvider).deletePrescription(
          prescriptionId: prescriptionId,
          patientId: patientId,
        );
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) {
        NurivaDialogs.toast(context, 'Prescription deleted.');
        context.pop();
      },
      onFailure: (failure) => NurivaDialogs.toast(
        context,
        PrescriptionCopy.forFailure(failure),
        status: NurivaStatus.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescription = ref.watch(prescriptionProvider(prescriptionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription'),
        actions: [
          if (prescription.value?.status == PrescriptionStatus.uploaded)
            IconButton(
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SafeArea(
        child: switch (prescription) {
          AsyncData(value: final Prescription value) =>
            _PrescriptionBody(patientId: patientId, prescription: value),
          AsyncData() => const NurivaStateView.empty(
              title: 'Not found',
              message: 'This prescription no longer exists.',
              icon: Icons.description_outlined,
            ),
          AsyncError() => const NurivaStateView.error(
              title: 'Could not load this prescription',
            ),
          _ => const NurivaStateView.loading(),
        },
      ),
    );
  }
}

final class _PrescriptionBody extends ConsumerWidget {
  const _PrescriptionBody({required this.patientId, required this.prescription});

  final String patientId;
  final Prescription prescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(localPrescriptionPagesProvider((
      patientId: patientId,
      prescriptionId: prescription.id,
      pageCount: prescription.pageCount,
    )));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NurivaTokens.pageInset,
        NurivaTokens.space4,
        NurivaTokens.pageInset,
        NurivaTokens.space10,
      ),
      children: [
        NurivaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.yMMMMd().format(prescription.createdAt),
                      style: context.text.titleMedium,
                    ),
                  ),
                  NurivaStatusChip(
                    label: PrescriptionCopy.forStatus(prescription.status),
                    status: NurivaStatus.info,
                  ),
                ],
              ),
              if (prescription.doctorName?.trim().isNotEmpty == true) ...[
                const SizedBox(height: NurivaTokens.space2),
                Text(
                  prescription.doctorName!,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
              if (prescription.clinicName?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  prescription.clinicName!,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const NurivaSectionHeader(title: 'Pages'),
        switch (pages) {
          AsyncData(:final value) => Column(
              children: [
                for (var i = 0; i < value.length; i++) ...[
                  _PageView(path: value[i], index: i),
                  const SizedBox(height: NurivaTokens.space3),
                ],
              ],
            ),
          AsyncError() => const NurivaCard(
              child: Text('Could not check this device for saved pages.'),
            ),
          _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: NurivaTokens.space6),
              child: Center(child: CircularProgressIndicator()),
            ),
        },
      ],
    );
  }
}

final class _PageView extends StatelessWidget {
  const _PageView({required this.path, required this.index});

  final String? path;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return NurivaCard(
        child: Row(
          children: [
            Icon(Icons.smartphone_outlined, color: context.colors.onSurfaceVariant),
            const SizedBox(width: NurivaTokens.space3),
            Expanded(
              child: Text(
                'Page ${index + 1} is not on this device. Prescription photos '
                'are only stored on the phone that took them.',
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: NurivaTokens.brLg,
      child: Image.file(File(path!), fit: BoxFit.contain),
    );
  }
}
