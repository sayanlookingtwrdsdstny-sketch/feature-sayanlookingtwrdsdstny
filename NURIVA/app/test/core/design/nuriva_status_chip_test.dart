import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/design/design.dart';

import '../../support/fake_auth.dart';

/// Regression tests for the Module 02 chip overflow.
///
/// At large system font the chip's label outgrew its width and the inner Row
/// overflowed. These pin both placements that matter: squeezed into a narrow
/// space, and sitting beside an Expanded (where a naive `Flexible` fix would
/// have thrown instead).
Widget _host(Widget child, {double textScale = 1.6}) => MaterialApp(
      theme: NurivaTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  const chip = NurivaStatusChip(
    label: 'Caring for family',
    status: NurivaStatus.info,
    icon: Icons.family_restroom_outlined,
  );

  testWidgets('wraps instead of overflowing when squeezed', (tester) async {
    final errors = await collectFlutterErrors(() async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 90, child: chip)),
      );
    });

    expect(errors, isEmpty, reason: errors.join('\n\n'));
    // A substring match, not exact: the icon's WidgetSpan adds a placeholder
    // character before the label in the RichText's plain-text value.
    expect(
      find.textContaining('Caring for family', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('sits beside an Expanded without throwing', (tester) async {
    final errors = await collectFlutterErrors(() async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 320,
            child: Row(
              children: [
                Expanded(child: Text('Module 03 — Patient & Guardian')),
                NurivaStatusChip(
                  label: 'Pending',
                  status: NurivaStatus.warning,
                ),
              ],
            ),
          ),
        ),
      );
    });

    expect(errors, isEmpty, reason: errors.join('\n\n'));
  });

  testWidgets('still shows its icon and label at normal size', (tester) async {
    await tester.pumpWidget(_host(chip, textScale: 1.0));

    expect(find.byIcon(Icons.family_restroom_outlined), findsOneWidget);
    // A substring match, not exact: the icon's WidgetSpan adds a placeholder
    // character before the label in the RichText's plain-text value.
    expect(
      find.textContaining('Caring for family', findRichText: true),
      findsOneWidget,
    );
  });
}
