import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/medications/domain/medication_draft.dart';
import 'package:nuriva/features/medications/domain/medication_models.dart';

void main() {
  MedicationDraft draft({
    String medicineName = 'Sompraz',
    List<LocalTimeOfDay>? timesLocal,
    DateTime? startDate,
    DateTime? endDate,
    String? strength,
    String? notes,
  }) =>
      MedicationDraft(
        medicineName: medicineName,
        timesLocal: timesLocal ?? [const LocalTimeOfDay(8, 0)],
        startDate: startDate ?? DateTime(2026, 3, 3),
        endDate: endDate,
        strength: strength,
        notes: notes,
      );

  void expectRejected(Result<MedicationDraft> result, String field) {
    expect(
      result,
      isA<Failure<MedicationDraft>>().having(
        (f) => f.failure,
        'failure',
        isA<ValidationFailure>().having((v) => v.field, 'field', field),
      ),
    );
  }

  group('medicine name', () {
    test('is required', () {
      expectRejected(draft(medicineName: '   ').validate(), 'medicineName');
    });

    test('is capped', () {
      expectRejected(draft(medicineName: 'x' * 121).validate(), 'medicineName');
    });

    test('is trimmed', () {
      final result = draft(medicineName: '  Sompraz  ').validate();
      expect(result.valueOrNull!.medicineName, 'Sompraz');
    });
  });

  group('times', () {
    test('at least one is required', () {
      // A medicine with no time is not a schedule, and Module 09 would have
      // nothing to generate from it.
      expectRejected(draft(timesLocal: []).validate(), 'timesLocal');
    });

    test('are capped at the same bound extraction uses', () {
      expectRejected(
        draft(
          timesLocal: [
            for (var h = 0; h < 13; h++) LocalTimeOfDay(h, 0),
          ],
        ).validate(),
        'timesLocal',
      );
    });

    test('are sorted and de-duplicated', () {
      final result = draft(
        timesLocal: const [
          LocalTimeOfDay(20, 0),
          LocalTimeOfDay(8, 0),
          LocalTimeOfDay(20, 0),
        ],
      ).validate();

      expect(
        result.valueOrNull!.timesLocal,
        const [LocalTimeOfDay(8, 0), LocalTimeOfDay(20, 0)],
      );
    });
  });

  group('dates', () {
    test('an end before the start is rejected', () {
      expectRejected(
        draft(
          startDate: DateTime(2026, 3, 10),
          endDate: DateTime(2026, 3, 9),
        ).validate(),
        'endDate',
      );
    });

    test('a same-day course is a one-day course, not an error', () {
      final day = DateTime(2026, 3, 10);
      final result = draft(startDate: day, endDate: day).validate();
      expect(result.isSuccess, isTrue);
    });

    test('a course longer than a year is rejected', () {
      expectRejected(
        draft(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2027, 1, 1),
        ).validate(),
        'endDate',
      );
    });

    test('exactly a year is allowed', () {
      final result = draft(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      ).validate();
      expect(result.isSuccess, isTrue);
    });

    test('an open-ended course is allowed', () {
      expect(draft().validate().isSuccess, isTrue);
    });
  });

  group('optional text', () {
    test('is capped', () {
      expectRejected(draft(strength: 'x' * 61).validate(), 'strength');
      expectRejected(draft(notes: 'x' * 501).validate(), 'notes');
    });

    test('blank becomes null rather than an empty string', () {
      final result = draft(strength: '   ').validate();
      expect(result.valueOrNull!.strength, isNull);
    });
  });
}
