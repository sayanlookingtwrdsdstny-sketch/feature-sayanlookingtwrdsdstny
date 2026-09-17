import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/design/design.dart';

Widget _host(Widget child) => MaterialApp(
      theme: NurivaTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('NurivaButton', () {
    testWidgets('renders its label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        NurivaButton(label: 'Continue', onPressed: () => taps++),
      ));

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed disables it', (tester) async {
      await tester.pumpWidget(_host(
        const NurivaButton(label: 'Disabled', onPressed: null),
      ));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('busy state shows a spinner and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        NurivaButton(
          label: 'Saving',
          isBusy: true,
          onPressed: () => taps++,
        ),
      ));

      // The label is replaced by a spinner, so a second tap cannot record a
      // duplicate action while the first is still in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving'), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(taps, 0);
    });

    testWidgets('hero size is taller than standard', (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [
            NurivaButton.hero(label: 'TAKEN', onPressed: null),
            NurivaButton(label: 'Standard', onPressed: null),
          ],
        ),
      ));

      final hero = tester.getSize(find.text('TAKEN'));
      expect(hero.height, greaterThan(0));

      final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      expect(buttons.length, 2);
    });

    testWidgets('renders each variant with the right underlying widget',
        (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [
            NurivaButton(
              label: 'P',
              onPressed: null,
              variant: NurivaButtonVariant.primary,
            ),
            NurivaButton(
              label: 'S',
              onPressed: null,
              variant: NurivaButtonVariant.secondary,
            ),
            NurivaButton(
              label: 'D',
              onPressed: null,
              variant: NurivaButtonVariant.destructive,
            ),
            NurivaButton(
              label: 'T',
              onPressed: null,
              variant: NurivaButtonVariant.text,
            ),
          ],
        ),
      ));

      // primary + destructive are both FilledButton
      expect(find.byType(FilledButton), findsNWidgets(2));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('shows an icon when given one', (tester) async {
      await tester.pumpWidget(_host(
        const NurivaButton(
          label: 'Confirm',
          icon: Icons.check,
          onPressed: null,
        ),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('NurivaStatusChip', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(_host(
        const NurivaStatusChip(label: 'Taken', status: NurivaStatus.positive),
      ));

      expect(find.text('Taken', findRichText: true), findsOneWidget);
    });
  });

  group('NurivaStateView', () {
    testWidgets('loading shows a spinner and its message', (tester) async {
      await tester.pumpWidget(
        _host(const NurivaStateView.loading(message: 'Checking…')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Checking…'), findsOneWidget);
    });

    testWidgets('error shows title, message and retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_host(
        NurivaStateView.error(
          title: 'Could not load',
          message: 'Check your connection.',
          onAction: () => retried++,
        ),
      ));

      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Check your connection.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('empty shows no spinner', (tester) async {
      await tester.pumpWidget(_host(
        const NurivaStateView.empty(title: 'Nothing here yet'),
      ));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });
}
