import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/constants/timezones.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/domain/patient_models.dart';
import 'package:nuriva/features/patients/presentation/patient_copy.dart';

/// Creates a patient the signed-in user will manage — someone they care for,
/// not themselves (their own record is created silently by
/// [selfPatientProvider]'s ensure-on-sign-in flow, no form needed).
final class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  DateTime? _dob;
  PatientSex _sex = PatientSex.unspecified;
  String _timezone = NurivaTimezones.defaultZone;
  bool _busy = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 60, now.month, now.day),
      firstDate: DateTime(now.year - 130),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null) {
      setState(() => _failure = const AppFailure.validation(
            field: 'dob',
            reason: 'required',
          ));
      return;
    }

    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(careCircleServiceProvider).createManagedPatient(
          displayName: _name.text,
          dob: _dob!,
          sex: _sex,
          timezone: _timezone,
          creatorUid: uid,
        );
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        context.go(AppRoutes.patientDetailFor(value.id));
      case Failure(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Add a patient',
      subtitle: 'You\'ll be their primary guardian — you can invite other '
          'family members to help once they\'re set up.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              NurivaTextField(
                label: 'Their name',
                controller: _name,
                hint: 'Full name',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: NurivaTokens.space5),
              NurivaCard(
                onTap: _pickDob,
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: NurivaTokens.space3),
                    Expanded(
                      child: Text(
                        _dob == null
                            ? 'Date of birth'
                            : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                        style: context.text.bodyLarge,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: NurivaTokens.space5),
              _SexPicker(
                value: _sex,
                onChanged: (v) => setState(() => _sex = v),
              ),
              const SizedBox(height: NurivaTokens.space5),
              DropdownButtonFormField<String>(
                initialValue: _timezone,
                decoration: const InputDecoration(labelText: 'Timezone'),
                items: [
                  for (final zone in NurivaTimezones.common)
                    DropdownMenuItem(value: zone, child: Text(zone)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _timezone = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: NurivaTokens.space6),
        if (_failure != null) ...[
          NurivaInlineMessage(message: PatientCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(label: 'Add patient', onPressed: _submit, isBusy: _busy),
      ],
    );
  }
}

final class _SexPicker extends StatelessWidget {
  const _SexPicker({required this.value, required this.onChanged});

  final PatientSex value;
  final ValueChanged<PatientSex> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PatientSex>(
      segments: const [
        ButtonSegment(value: PatientSex.female, label: Text('Female')),
        ButtonSegment(value: PatientSex.male, label: Text('Male')),
        ButtonSegment(value: PatientSex.unspecified, label: Text('Other')),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
