import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/prescriptions/application/prescription_providers.dart';

/// Entry point for "Prescriptions". A guardian with more than one viewable
/// patient picks which one first; exactly one skips straight to their list.
///
/// "Viewable" ([viewablePrescriptionPatientsProvider]) means the
/// self-patient, or a guarded patient whose relationship carries
/// `viewPrescriptions` — a guardian without that permission has nothing to
/// see here even though the patient appears elsewhere (e.g. in Patients).
final class PrescriptionPatientPickerScreen extends ConsumerWidget {
  const PrescriptionPatientPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(viewablePrescriptionPatientsProvider);

    return switch (patients) {
      AsyncError() => const Scaffold(
          body: NurivaStateView.error(
            title: 'Could not load your patients',
            message: 'Check your connection and try again.',
          ),
        ),
      AsyncData(:final value) when value.isEmpty => const Scaffold(
          body: NurivaStateView.empty(
            title: 'No patients yet',
            message: 'Add a patient before uploading a prescription.',
            icon: Icons.family_restroom_outlined,
          ),
        ),
      AsyncData(:final value) when value.length == 1 => _AutoNavigate(
          patientId: value.first.id,
        ),
      AsyncData(:final value) => Scaffold(
          appBar: AppBar(title: const Text('Prescriptions')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NurivaTokens.pageInset,
                NurivaTokens.space4,
                NurivaTokens.pageInset,
                NurivaTokens.space10,
              ),
              children: [
                const NurivaSectionHeader(title: 'Whose prescriptions?'),
                for (final patient in value) ...[
                  NurivaListTile(
                    title: patient.displayName,
                    leadingIcon: Icons.description_outlined,
                    onTap: () => context
                        .push(AppRoutes.prescriptionsFor(patient.id)),
                  ),
                  const SizedBox(height: NurivaTokens.space2),
                ],
              ],
            ),
          ),
        ),
      _ => const Scaffold(body: NurivaStateView.loading()),
    };
  }
}

/// Redirects to the one viewable patient's list without making the user
/// choose. `go()`, not `push()` — "back" from the list should return to
/// wherever the user came from, not to a picker screen they never saw.
final class _AutoNavigate extends StatefulWidget {
  const _AutoNavigate({required this.patientId});

  final String patientId;

  @override
  State<_AutoNavigate> createState() => _AutoNavigateState();
}

class _AutoNavigateState extends State<_AutoNavigate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.prescriptionsFor(widget.patientId));
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: NurivaStateView.loading());
}
