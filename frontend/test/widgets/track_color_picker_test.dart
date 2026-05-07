import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/theme/gleisner_tokens.dart';
import 'package:gleisner_web/widgets/common/track_color_picker.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('TrackColorPicker', () {
    testWidgets('renders the section heading and the More colors toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TrackColorPicker(
            selectedHex: trackColorPresets[0],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select a color'), findsOneWidget);
      expect(find.text('More colors'), findsOneWidget);
      // The HEX text field is collapsed until the user expands "More colors".
      expect(find.text('Custom color (HEX)'), findsNothing);
    });

    testWidgets(
      'tapping a preset swatch fires onChanged with that uppercase HEX',
      (tester) async {
        String? lastEmitted;
        await tester.pumpWidget(
          _wrap(
            TrackColorPicker(
              selectedHex: trackColorPresets[0],
              onChanged: (hex) => lastEmitted = hex,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Each preset is wrapped in Semantics(button: true, label: 'Color #...')
        // so the screen-reader path is also the canonical lookup path here.
        await tester.tap(
          find.bySemanticsLabel('Color ${trackColorPresets[1]}'),
        );
        await tester.pumpAndSettle();

        expect(lastEmitted, trackColorPresets[1].toUpperCase());
      },
    );

    testWidgets('expanding More colors reveals the HEX text field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TrackColorPicker(
            selectedHex: trackColorPresets[0],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('More colors'));
      await tester.pumpAndSettle();

      expect(find.text('Custom color (HEX)'), findsOneWidget);
    });

    testWidgets('typing a valid HEX into the text field fires onChanged', (
      tester,
    ) async {
      String? lastEmitted;
      await tester.pumpWidget(
        _wrap(
          TrackColorPicker(
            selectedHex: trackColorPresets[0],
            onChanged: (hex) => lastEmitted = hex,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the custom-input section first.
      await tester.tap(find.text('More colors'));
      await tester.pumpAndSettle();

      // Find the HEX TextField via its decoration label (the only TextField
      // inside this widget when the section is expanded).
      final hexField = find.widgetWithText(TextField, 'Custom color (HEX)');
      expect(hexField, findsOneWidget);

      await tester.enterText(hexField, '#abcdef');
      await tester.pump();

      // The picker normalizes the value to uppercase before propagating.
      expect(lastEmitted, '#ABCDEF');
    });

    testWidgets(
      'typing an invalid HEX shows the error and suppresses onChanged',
      (tester) async {
        var emitCount = 0;
        await tester.pumpWidget(
          _wrap(
            TrackColorPicker(
              selectedHex: trackColorPresets[0],
              onChanged: (_) => emitCount++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('More colors'));
        await tester.pumpAndSettle();

        final hexField = find.widgetWithText(TextField, 'Custom color (HEX)');
        await tester.enterText(hexField, 'nope');
        await tester.pump();

        expect(find.text('Invalid HEX format (e.g. #ff0000)'), findsOneWidget);
        expect(emitCount, 0);
      },
    );
  });
}
