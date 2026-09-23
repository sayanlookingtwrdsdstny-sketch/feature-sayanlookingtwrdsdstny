import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';

/// Every patient in the signed-in user's care circle — their own
/// self-record (if any) and everyone they actively guard.
final class PatientsListScreen extends ConsumerWidget {
  const PatientsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfPatientProvider);
    final guarded = ref.watch(guardianPatientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.addPatient),
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Add a patient',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.joinPatient),
            icon: const Icon(Icons.qr_code_outlined),
            tooltip: 'Enter a link code',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          // Both providers are plain (non-autoDispose) StreamProviders — once
          // a Firestore listen errors, the stream is done and Riverpod keeps
          // serving that terminal AsyncError forever; merely re-entering this
          // route does not resubscribe it. Invalidating is what actually
          // creates a fresh listen, which is what the "Pull to retry" copy
          // below promises.
          onRefresh: () async {
            ref.invalidate(selfPatientProvider);
            ref.invalidate(guardianPatientsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NurivaTokens.pageInset,
              NurivaTokens.space4,
              NurivaTokens.pageInset,
              NurivaTokens.space10,
            ),
            children: [
              if (self.value != null) ...[
                const NurivaSectionHeader(title: 'You'),
                _PatientTile(patient: self.value!, subtitle: 'Self'),
                const SizedBox(height: NurivaTokens.space4),
              ],
              const NurivaSectionHeader(title: 'People you care for'),
              switch (guarded) {
                AsyncData(:final value) when value.isEmpty => const NurivaCard(
                  child: Text('No one yet. Add a patient to get started.'),
                ),
                AsyncData(:final value) => Column(
                  children: [
                    for (final patient in value) ...[
                      _PatientTile(patient: patient),
                      const SizedBox(height: NurivaTokens.space3),
                    ],
                  ],
                ),
                AsyncError() => const NurivaCard(
                  child: Text('Could not load your patients. Pull to retry.'),
                ),
                _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: NurivaTokens.space6),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

final class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, this.subtitle});

  final Patient patient;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return NurivaListTile(
      title: patient.displayName,
      subtitle: subtitle,
      leadingIcon: Icons.person_outline,
      onTap: () => context.push(AppRoutes.patientDetailFor(patient.id)),
    );
  }
}
