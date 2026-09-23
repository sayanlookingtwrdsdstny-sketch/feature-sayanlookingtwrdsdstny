import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_copy.dart';
import 'package:nuriva/features/verification/application/verification_providers.dart';
import 'package:nuriva/features/verification/presentation/widgets/medication_draft_form.dart';

/// ARCHITECTURE.md §7 step 10 — the screen where a person checks the
/// prescription and records what it actually says.
///
/// §7 imagined this as "original image side-by-side with extracted fields".
/// On a phone that means stacked rather than literally side-by-side, and
/// Module 05's findings change what deserves the space: on a tabular
/// prescription the OCR candidates carry only names and forms, so the
/// **photo and the raw recognized text** are what a verifier actually works
/// from. The candidates are offered as shortcuts, not as the subject.
final class VerifyPrescriptionScreen extends ConsumerWidget {
  const VerifyPrescriptionScreen({
    required this.patientId,
    required this.prescriptionId,
    super.key,
  });

  final String patientId;
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescription = ref.watch(prescriptionProvider(prescriptionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Check the prescription')),
      body: SafeArea(
        child: switch (prescription) {
          AsyncData(value: final Prescription value) => _Body(
              patientId: patientId,
              prescription: value,
            ),
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

final class _Body extends ConsumerWidget {
  const _Body({required this.patientId, required this.prescription});

  final String patientId;
  final Prescription prescription;

  Future<void> _addMedicine(
    BuildContext context,
    WidgetRef ref, {
    MedicationCandidate? candidate,
    String? extractionId,
  }) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;

    await NurivaDialogs.sheet<void>(
      context,
      title: 'Add a medicine',
      child: SingleChildScrollView(
        child: MedicationDraftForm(
          candidate: candidate,
          onSubmit: (draft) async {
            final result = await ref
                .read(verificationServiceProvider)
                .saveVerifiedMedication(
                  prescription: prescription,
                  draft: draft,
                  verifiedByUid: uid,
                  extractionId: extractionId,
                );
            return result.fold(
              onSuccess: (_) => null,
              onFailure: PrescriptionCopy.forFailure,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(localPrescriptionPagesProvider((
      patientId: patientId,
      prescriptionId: prescription.id,
      pageCount: prescription.pageCount,
    )));
    final extractions = ref.watch(extractionsProvider(prescription.id));
    final drafts = ref.watch(medicationsForPrescriptionProvider((
      patientId: patientId,
      prescriptionId: prescription.id,
    )));

    final latest = extractions.value?.firstOrNull;
    final localPages = [
      for (final path in pages.value ?? const <String?>[]) ?path,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NurivaTokens.pageInset,
        NurivaTokens.space4,
        NurivaTokens.pageInset,
        NurivaTokens.space10,
      ),
      children: [
        const NurivaInlineMessage(
          message: 'Type what the prescription says, checking each line '
              'against the photo. Nothing here starts a reminder — a '
              'guardian approves it first.',
          status: NurivaStatus.info,
        ),
        if (localPages.isNotEmpty) ...[
          const NurivaSectionHeader(title: 'The prescription'),
          for (final path in localPages) ...[
            ClipRRect(
              borderRadius: NurivaTokens.brLg,
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            const SizedBox(height: NurivaTokens.space3),
          ],
        ],
        if (latest != null) _RawTextSection(extraction: latest),
        const NurivaSectionHeader(
          title: 'Medicines',
          subtitle: 'Everything captured from this prescription so far',
        ),
        switch (drafts) {
          AsyncData(value: final list) when list.isEmpty => NurivaCard(
              child: Text(
                'Nothing captured yet. Add each medicine you can read on the '
                'prescription.',
                style: context.text.bodyMedium,
              ),
            ),
          AsyncData(value: final list) => Column(
              children: [
                for (final medication in list) ...[
                  _DraftCard(
                    medication: medication,
                    onDiscard: () async {
                      final confirmed = await NurivaDialogs.confirm(
                        context,
                        title: 'Remove this medicine?',
                        message:
                            'It has not been approved, so nothing is using '
                            'it yet.',
                        confirmLabel: 'Remove',
                        isDestructive: true,
                      );
                      if (!confirmed) return;
                      await ref
                          .read(verificationServiceProvider)
                          .discardDraft(medication.id);
                    },
                  ),
                  const SizedBox(height: NurivaTokens.space3),
                ],
              ],
            ),
          AsyncError() => const NurivaCard(
              child: Text('Could not load what has been captured so far.'),
            ),
          _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: NurivaTokens.space6),
              child: Center(child: CircularProgressIndicator()),
            ),
        },
        const SizedBox(height: NurivaTokens.space4),
        NurivaButton(
          label: 'Add a medicine',
          icon: Icons.add,
          onPressed: () => _addMedicine(context, ref, extractionId: latest?.id),
        ),
        if (latest != null && latest.candidates.isNotEmpty) ...[
          const NurivaSectionHeader(
            title: 'Shortcuts from the photo',
            subtitle: 'Starts the form with what the phone read. Check it.',
          ),
          for (final candidate in latest.candidates)
            NurivaListTile(
              title: candidate.name ?? 'Unnamed line',
              subtitle: candidate.sourceLine,
              leadingIcon: Icons.auto_fix_high_outlined,
              onTap: () => _addMedicine(
                context,
                ref,
                candidate: candidate,
                extractionId: latest.id,
              ),
            ),
        ],
      ],
    );
  }
}

final class _RawTextSection extends StatefulWidget {
  const _RawTextSection({required this.extraction});

  final PrescriptionExtraction extraction;

  @override
  State<_RawTextSection> createState() => _RawTextSectionState();
}

class _RawTextSectionState extends State<_RawTextSection> {
  // Open by default. On the layouts this module actually meets, the raw text
  // is the most useful thing on the screen, and hiding it behind a tap would
  // bury the part a verifier works from.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NurivaSectionHeader(
          title: 'What the phone read',
          subtitle: 'Not checked by anyone yet',
          trailing: IconButton(
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            tooltip: _expanded ? 'Hide' : 'Show',
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded)
          NurivaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.extraction.rawLines.isEmpty)
                  Text(
                    'No text could be read from this prescription.',
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  )
                else
                  for (final line in widget.extraction.rawLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child:
                          SelectableText(line, style: context.text.bodyMedium),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.medication, required this.onDiscard});

  final Medication medication;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final muted =
        context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    final times = medication.timesLocal.map((t) => t.wire).join(', ');

    return NurivaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  medication.medicineName,
                  style: context.text.titleSmall,
                ),
              ),
              const NurivaStatusChip(
                label: 'Awaiting approval',
                status: NurivaStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: NurivaTokens.space2),
          if (medication.strength != null || medication.form != null)
            Text(
              [medication.strength, medication.form]
                  .where((v) => v != null)
                  .join(' · '),
              style: muted,
            ),
          if (medication.dosage != null)
            Text('${medication.dosage} each time', style: muted),
          Text('At $times', style: muted),
          Text(
            'From ${DateFormat.yMMMd().format(medication.startDate)}'
            '${medication.endDate == null ? '' : ' to ${DateFormat.yMMMd().format(medication.endDate!)}'}',
            style: muted,
          ),
          const SizedBox(height: NurivaTokens.space3),
          NurivaButton(
            label: 'Remove',
            variant: NurivaButtonVariant.destructive,
            expand: false,
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
}
