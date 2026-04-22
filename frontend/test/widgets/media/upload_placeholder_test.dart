import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/widgets/media/upload_placeholder.dart';

void main() {
  group('UploadPlaceholderContent', () {
    testWidgets('renders icon only when hint is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UploadPlaceholderContent(icon: Icons.videocam_outlined),
          ),
        ),
      );

      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders icon and hint when hint is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UploadPlaceholderContent(
              icon: Icons.audiotrack_outlined,
              hint: 'Up to 5 min',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
      expect(find.text('Up to 5 min'), findsOneWidget);
    });

    testWidgets(
      'hint Text uses ellipsis overflow and maxLines: 2 for locale safety',
      (tester) async {
        // A long hint (simulating a translation that expands in length)
        // should not overflow the container or cause RenderFlex warnings.
        const longHint =
            'Up to five minutes — this is an intentionally long translation '
            'string used to verify that the placeholder hint clips safely.';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UploadPlaceholderContent(
                icon: Icons.add_photo_alternate_outlined,
                hint: longHint,
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.maxLines, 2);
        expect(textWidget.overflow, TextOverflow.ellipsis);
        expect(textWidget.textAlign, TextAlign.center);
      },
    );

    testWidgets('has fixed 200 height and rounded container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UploadPlaceholderContent(icon: Icons.videocam_outlined),
          ),
        ),
      );

      // Exactly one Container at the root of the widget keeps styling
      // in lockstep between create_post and edit_post.
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxHeight, 200);
      expect(container.decoration, isA<BoxDecoration>());
    });
  });
}
