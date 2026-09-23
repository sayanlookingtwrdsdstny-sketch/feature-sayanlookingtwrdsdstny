import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/prescriptions/application/extraction_service.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';
import 'package:nuriva/features/prescriptions/domain/prescription_models.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_copy.dart';

/// The Module 05 surface: run on-device OCR over this prescription, and show
/// what it read.
///
/// The screen's job is to be *useful without being trusted*. Everything here
/// is labelled as a draft, the raw text is always available beside the
/// proposals, and no control on this panel creates a medicine or a reminder —
/// because none exists to create yet (Modules 06-08).
final class ExtractionPanel extends ConsumerStatefulWidget {
  const ExtractionPanel({required this.prescription, super.key});

  final Prescription prescription;

  @override
  ConsumerState<ExtractionPanel> createState() => _ExtractionPanelState();
}

class _ExtractionPanelState extends ConsumerState<ExtractionPanel> {
  bool _running = false;
  bool _showRawText = false;

  Future<void> _run() async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;

    setState(() => _running = true);
    final result = await ref.read(extractionServiceProvider).extract(
          prescription: widget.prescription,
          requestedByUid: uid,
        );
    if (!mounted) return;
    setState(() => _running = false);

    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => NurivaDialogs.toast(
        context,
        PrescriptionCopy.forFailure(failure),
        status: NurivaStatus.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extractions = ref.watch(extractionsProvider(widget.prescription.id));
    final latest = extractions.value?.firstOrNull;

    // Offering the action at all requires pages to read. Without this the
    // screen shows an inviting primary button directly beneath its own
    // "not on this device" notice, and tapping it can only produce an error
    // the panel already had the information to prevent.
    final pages = ref.watch(localPrescriptionPagesProvider((
      patientId: widget.prescription.patientId,
      prescriptionId: widget.prescription.id,
      pageCount: widget.prescription.pageCount,
    )));
    final hasLocalPages = pages.value?.any((path) => path != null) ?? false;

    final canRun = ExtractionService.canExtractFrom(widget.prescription.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NurivaSectionHeader(
          title: 'Reading the prescription',
          subtitle: 'Your phone reads the text. Nothing is sent anywhere.',
        ),
        if (latest == null && canRun && !hasLocalPages)
          NurivaCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.smartphone_outlined,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: NurivaTokens.space3),
                Expanded(
                  child: Text(
                    "This prescription's photos aren't on this phone, so it "
                    "can't be read here. Open it on the phone that took "
                    'them.',
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else if (latest == null && canRun)
          NurivaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Read the text on this prescription so you can check it '
                  'without squinting at the photo. This happens on your '
                  'phone — the image never leaves it.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: NurivaTokens.space4),
                NurivaButton(
                  label: 'Read this prescription',
                  icon: Icons.document_scanner_outlined,
                  isBusy: _running,
                  onPressed: _running ? null : _run,
                ),
              ],
            ),
          )
        else if (latest == null &&
            widget.prescription.status == PrescriptionStatus.processing)
          const NurivaCard(child: Text('Reading this prescription…'))
        else if (latest == null)
          NurivaCard(
            child: Text(
              'This prescription has no reading recorded.',
              style: context.text.bodyMedium,
            ),
          )
        else ...[
          _ExtractionResult(
            extraction: latest,
            showRawText: _showRawText,
            onToggleRawText: () =>
                setState(() => _showRawText = !_showRawText),
          ),
          const SizedBox(height: NurivaTokens.space5),
          // The only way out of reading and into recording. Module 06 owns
          // everything past this button.
          NurivaButton(
            label: 'Check it and add the medicines',
            icon: Icons.fact_check_outlined,
            onPressed: () => context.push(
              AppRoutes.prescriptionVerifyFor(
                widget.prescription.patientId,
                widget.prescription.id,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

final class _ExtractionResult extends StatelessWidget {
  const _ExtractionResult({
    required this.extraction,
    required this.showRawText,
    required this.onToggleRawText,
  });

  final PrescriptionExtraction extraction;
  final bool showRawText;
  final VoidCallback onToggleRawText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The load-bearing sentence on this screen. A guardian who reads only
        // one line must read this one.
        const NurivaInlineMessage(
          message: 'This is a draft of what the phone could read — not a '
              'medicine record. Check every line against the photo. Nothing '
              'is scheduled until a person sets it up and a guardian '
              'approves it.',
          status: NurivaStatus.warning,
        ),
        const SizedBox(height: NurivaTokens.space3),
        Row(
          children: [
            NurivaStatusChip(
              label: PrescriptionCopy.forExtractionStatus(extraction.status),
              status: extraction.status == ExtractionStatus.extracted
                  ? NurivaStatus.positive
                  : NurivaStatus.warning,
            ),
            const SizedBox(width: NurivaTokens.space2),
            Expanded(
              child: Text(
                '${extraction.pagesProcessed} '
                '${extraction.pagesProcessed == 1 ? "page" : "pages"} read',
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        for (final warning in extraction.warnings) ...[
          const SizedBox(height: NurivaTokens.space2),
          NurivaInlineMessage(
            message: PrescriptionCopy.forWarning(warning),
            status: warning == ExtractionWarnings.directiveText
                ? NurivaStatus.danger
                : NurivaStatus.info,
          ),
        ],
        if (extraction.candidates.isNotEmpty) ...[
          const NurivaSectionHeader(title: 'Possible medicines'),
          for (final candidate in extraction.candidates) ...[
            _CandidateCard(candidate: candidate),
            const SizedBox(height: NurivaTokens.space3),
          ],
        ],
        const SizedBox(height: NurivaTokens.space2),
        NurivaButton(
          label: showRawText ? 'Hide the full text' : 'Show the full text',
          variant: NurivaButtonVariant.secondary,
          icon: showRawText ? Icons.expand_less : Icons.expand_more,
          onPressed: onToggleRawText,
        ),
        if (showRawText) ...[
          const SizedBox(height: NurivaTokens.space3),
          NurivaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in extraction.rawLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: SelectableText(line, style: context.text.bodyMedium),
                  ),
                if (extraction.rawLines.isEmpty)
                  Text(
                    'No text could be read from these pages.',
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

final class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final MedicationCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final muted =
        context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);

    return NurivaCard(
      accent: candidate.needsReview
          ? context.statusColors.of(NurivaStatus.warning, context.colors)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate.name ?? 'Name could not be read',
            style: context.text.titleSmall?.copyWith(
              fontStyle: candidate.name == null ? FontStyle.italic : null,
            ),
          ),
          const SizedBox(height: NurivaTokens.space2),
          _Field(label: 'Form', value: candidate.form),
          _Field(label: 'Strength', value: candidate.strength),
          _Field(
            label: 'As written',
            value: candidate.frequencyToken,
          ),
          _Field(
            label: 'Doses per day',
            value: candidate.dosesPerDay?.toString(),
          ),
          _Field(
            label: 'Days',
            value: candidate.durationDays?.toString(),
          ),
          _Field(label: 'Instructions', value: candidate.instructions),
          const SizedBox(height: NurivaTokens.space2),
          Text('From: "${candidate.sourceLine}"', style: muted),
          for (final warning in candidate.warnings) ...[
            const SizedBox(height: NurivaTokens.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: NurivaTokens.space2),
                Expanded(
                  child: Text(PrescriptionCopy.forWarning(warning), style: muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One label/value row. A field the parser could not read says so in words
/// rather than showing a blank, so "not read" is never mistaken for "none".
final class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not read',
              style: value == null
                  ? context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    )
                  : context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
