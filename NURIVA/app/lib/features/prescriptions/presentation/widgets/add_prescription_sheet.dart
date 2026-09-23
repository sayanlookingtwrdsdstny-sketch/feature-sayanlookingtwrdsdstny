import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';
import 'package:nuriva/features/prescriptions/application/prescription_service.dart';
import 'package:nuriva/features/prescriptions/presentation/prescription_copy.dart';

/// Opens the add-a-prescription bottom sheet: take/choose photos, then
/// upload. Returns `true` if a prescription was created, so the caller can
/// refresh its list.
Future<bool?> showAddPrescriptionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String patientId,
  required String uploadedByUid,
}) {
  return NurivaDialogs.sheet<bool>(
    context,
    title: 'Add a prescription',
    child: _AddPrescriptionContent(
      patientId: patientId,
      uploadedByUid: uploadedByUid,
    ),
  );
}

final class _AddPrescriptionContent extends ConsumerStatefulWidget {
  const _AddPrescriptionContent({
    required this.patientId,
    required this.uploadedByUid,
  });

  final String patientId;
  final String uploadedByUid;

  @override
  ConsumerState<_AddPrescriptionContent> createState() =>
      _AddPrescriptionContentState();
}

class _AddPrescriptionContentState
    extends ConsumerState<_AddPrescriptionContent> {
  final List<Uint8List> _pages = [];
  bool _busy = false;
  String? _error;

  Future<void> _addFromCamera() async {
    setState(() => _error = null);
    final result =
        await ref.read(imageCaptureServiceProvider).captureFromCamera();
    if (!mounted) return;
    final bytes = result.valueOrNull;
    if (bytes != null) {
      setState(() => _pages.add(bytes));
    } else if (result.failureOrNull != null) {
      setState(() => _error = PrescriptionCopy.forFailure(result.failureOrNull!));
    }
  }

  Future<void> _addFromGallery() async {
    setState(() => _error = null);
    final remaining = PrescriptionService.maxPages - _pages.length;
    if (remaining <= 0) {
      setState(() => _error = PrescriptionCopy.forField('pages', 'too_many'));
      return;
    }
    final result = await ref
        .read(imageCaptureServiceProvider)
        .pickFromGallery(maxImages: remaining);
    if (!mounted) return;
    result.fold(
      onSuccess: (pages) => setState(() => _pages.addAll(pages)),
      onFailure: (failure) =>
          setState(() => _error = PrescriptionCopy.forFailure(failure)),
    );
  }

  Future<void> _upload() async {
    if (_busy || _pages.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(prescriptionServiceProvider).uploadPrescription(
          patientId: widget.patientId,
          uploadedByUid: widget.uploadedByUid,
          pages: _pages,
        );
    if (!mounted) return;
    switch (result) {
      case Success():
        Navigator.of(context).pop(true);
      case Failure(:final failure):
        setState(() {
          _busy = false;
          _error = PrescriptionCopy.forFailure(failure);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Take a photo of each page, or choose photos already on the '
          'phone. Up to ${PrescriptionService.maxPages} pages.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: NurivaTokens.space4),
        Row(
          children: [
            Expanded(
              child: NurivaButton(
                label: 'Camera',
                icon: Icons.photo_camera_outlined,
                variant: NurivaButtonVariant.secondary,
                onPressed: _busy ? null : _addFromCamera,
              ),
            ),
            const SizedBox(width: NurivaTokens.space3),
            Expanded(
              child: NurivaButton(
                label: 'Gallery',
                icon: Icons.photo_library_outlined,
                variant: NurivaButtonVariant.secondary,
                onPressed: _busy ? null : _addFromGallery,
              ),
            ),
          ],
        ),
        if (_pages.isNotEmpty) ...[
          const SizedBox(height: NurivaTokens.space5),
          Wrap(
            spacing: NurivaTokens.space3,
            runSpacing: NurivaTokens.space3,
            children: [
              for (var i = 0; i < _pages.length; i++)
                _PageThumbnail(
                  bytes: _pages[i],
                  onRemove: _busy ? null : () => setState(() => _pages.removeAt(i)),
                ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: NurivaTokens.space4),
          NurivaInlineMessage(message: _error!),
        ],
        const SizedBox(height: NurivaTokens.space6),
        NurivaButton(
          label: _pages.isEmpty
              ? 'Add a photo first'
              : 'Upload ${_pages.length} page${_pages.length == 1 ? '' : 's'}',
          onPressed: _pages.isEmpty ? null : _upload,
          isBusy: _busy,
        ),
      ],
    );
  }
}

final class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: NurivaTokens.brSm,
          child: Image.memory(
            bytes,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.cancel),
              color: context.colors.error,
              tooltip: 'Remove',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 22,
            ),
          ),
      ],
    );
  }
}
