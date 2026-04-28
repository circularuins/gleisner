import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/widgets/media/video_media_preview.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('VideoMediaPreview', () {
    testWidgets('shows the videocam placeholder when thumbnailUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const VideoMediaPreview(thumbnailUrl: null)),
      );
      await tester.pumpAndSettle();

      // Placeholder branch: videocam icon, no Image.network.
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      // Replace badge is always shown so the user can tap to swap.
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
    });

    testWidgets(
      'shows the videocam placeholder when thumbnailUrl is empty (treated same as null)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const VideoMediaPreview(thumbnailUrl: '')),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets('renders the network thumbnail when thumbnailUrl is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VideoMediaPreview(
            thumbnailUrl: 'http://localhost:4000/thumb.jpg',
          ),
        ),
      );
      // Don't pumpAndSettle — the Image.network would try to load and
      // hang the test. The first frame is enough to verify the branch.
      await tester.pump();

      // Thumbnail branch: Image.network rendered, no placeholder icon.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);

      // Replace badge is still shown.
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });
  });
}
