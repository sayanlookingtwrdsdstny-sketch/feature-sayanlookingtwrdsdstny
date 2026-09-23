import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/medications/domain/medication_draft.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';
import 'package:nuriva/features/prescriptions/domain/extraction_models.dart';

/// The editable fields for one medicine.
///
/// Seeded from an OCR candidate where one exists, and blank where it does
/// not. It never pre-fills a dose time or a frequency from OCR: Module 05
/// established that on a tabular prescription the frequency cell arrives
/// detached from the medicine it belongs to, so anything offered here would
/// be a guess wearing the costume of a default. A person reading the photo
/// enters the times.
final class MedicationDraftForm extends StatefulWidget {
  const MedicationDraftForm({
    required this.onSubmit,
    this.candidate,
    super.key,
  });

  /// Returns a failure message to display, or null on success — in which
  /// case this widget closes the sheet it is hosted in.
  final Future<String?> Function(MedicationDraft draft) onSubmit;

  final MedicationCandidate? candidate;

  @override
  State<MedicationDraftForm> createState() => _MedicationDraftFormState();
}

class _MedicationDraftFormState extends State<MedicationDraftForm> {
  late final TextEditingController _name;
  late final TextEditingController _strength;
  late final TextEditingController _form;
  late final TextEditingController _dosage;
  late final TextEditingController _notes;

  final List<LocalTimeOfDay> _times = [];
  FoodInstruction _food = FoodInstruction.none;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final candidate = widget.candidate;
    _name = TextEditingController(text: candidate?.name ?? '');
    _strength = TextEditingController(text: candidate?.strength ?? '');
    _form = TextEditingController(text: candidate?.form ?? '');
    // No dosage seed: an OCR candidate carries a frequency token, not an
    // amount-per-dose, and the two are not interchangeable.
    _dosage = TextEditingController();
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _form.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      final time = LocalTimeOfDay(picked.hour, picked.minute);
      if (!_times.contains(time)) _times.add(time);
      _times.sort();
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final message = await widget.onSubmit(
      MedicationDraft(
        medicineName: _name.text,
        timesLocal: _times,
        startDate: _startDate,
        strength: _strength.text,
        form: _form.text,
        dosage: _dosage.text,
        foodInstruction: _food,
        endDate: _endDate,
        notes: _notes.text,
      ),
    );

    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Read these off the prescription. Leave anything you cannot read '
          'blank rather than guessing.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: NurivaTokens.space5),
        NurivaTextField(
          label: 'Medicine name',
          controller: _name,
          hint: 'As written on the prescription',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: NurivaTokens.space4),
        Row(
          children: [
            Expanded(
              child: NurivaTextField(
                label: 'Strength',
                controller: _strength,
                hint: 'e.g. 40 mg',
              ),
            ),
            const SizedBox(width: NurivaTokens.space3),
            Expanded(
              child: NurivaTextField(
                label: 'Form',
                controller: _form,
                hint: 'e.g. Tablet',
              ),
            ),
          ],
        ),
        const SizedBox(height: NurivaTokens.space4),
        NurivaTextField(
          label: 'How much each time',
          controller: _dosage,
          hint: 'e.g. 1 tablet',
        ),
        const SizedBox(height: NurivaTokens.space5),
        const NurivaSectionHeader(
          title: 'When it is taken',
          subtitle: 'Add every time of day a dose is due',
        ),
        if (_times.isEmpty)
          Text(
            'No times added yet.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: NurivaTokens.space2,
            runSpacing: NurivaTokens.space2,
            children: [
              for (final time in _times)
                InputChip(
                  label: Text(time.wire),
                  onDeleted: () => setState(() => _times.remove(time)),
                ),
            ],
          ),
        const SizedBox(height: NurivaTokens.space3),
        NurivaButton(
          label: 'Add a time',
          variant: NurivaButtonVariant.secondary,
          icon: Icons.schedule_outlined,
          onPressed: _addTime,
        ),
        const SizedBox(height: NurivaTokens.space5),
        const NurivaSectionHeader(title: 'Food'),
        DropdownButtonFormField<FoodInstruction>(
          initialValue: _food,
          decoration: const InputDecoration(labelText: 'With food?'),
          items: [
            for (final option in FoodInstruction.values)
              DropdownMenuItem(value: option, child: Text(_foodLabel(option))),
          ],
          onChanged: (value) =>
              setState(() => _food = value ?? FoodInstruction.none),
        ),
        const SizedBox(height: NurivaTokens.space5),
        const NurivaSectionHeader(title: 'Dates'),
        NurivaListTile(
          title: 'Starts',
          subtitle: dateFormat.format(_startDate),
          onTap: () => _pickDate(isStart: true),
        ),
        NurivaListTile(
          title: 'Ends',
          subtitle: _endDate == null
              ? 'No end date'
              : dateFormat.format(_endDate!),
          onTap: () => _pickDate(isStart: false),
          trailing: _endDate == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear end date',
                  onPressed: () => setState(() => _endDate = null),
                ),
        ),
        const SizedBox(height: NurivaTokens.space4),
        NurivaTextField(
          label: 'Notes',
          controller: _notes,
          hint: 'Anything else worth remembering',
          maxLines: 3,
        ),
        if (_error != null) ...[
          const SizedBox(height: NurivaTokens.space4),
          NurivaInlineMessage(message: _error!),
        ],
        const SizedBox(height: NurivaTokens.space5),
        NurivaButton(
          label: 'Save for approval',
          isBusy: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: NurivaTokens.space3),
        Text(
          'Saving does not start any reminders. A guardian approves it '
          'first.',
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _foodLabel(FoodInstruction instruction) => switch (instruction) {
        FoodInstruction.none => 'No instruction',
        FoodInstruction.beforeFood => 'Before food',
        FoodInstruction.afterFood => 'After food',
        FoodInstruction.withFood => 'With food',
        FoodInstruction.emptyStomach => 'On an empty stomach',
      };
}
