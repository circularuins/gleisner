// Regression test for the public-timeline milestone sheet.
//
// Symptom: tapping a milestone diamond on `/@username` (unauthenticated)
// appeared to do nothing — the modal route opened but the builder rendered
// `SizedBox.shrink()` because the sheet looked the milestone up via
// `timelineProvider`, which is unloaded for unauthenticated viewers (their
// data lives in `publicTimelineProvider`).
//
// Fix: the sheet now uses the milestone object passed into
// `showMilestoneDetailSheet` as its source of truth, and only watches
// `timelineProvider` for live reaction updates when the caller supplies
// `onToggleReaction` (authenticated path). The unauthenticated path therefore
// no longer depends on provider state at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/models/artist.dart';
import 'package:gleisner_web/widgets/timeline/milestone_detail_sheet.dart';

ArtistMilestone _milestone({
  String id = 'm1',
  String title = 'First gig at the Tiny Stage',
  String? description = 'Played to ~30 people. Felt every note.',
}) {
  return ArtistMilestone(
    id: id,
    category: 'performance',
    title: title,
    description: description,
    date: '2025-08-14',
    position: 0,
  );
}

Widget _hostApp({required VoidCallback onTap}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(onPressed: onTap, child: const Text('open')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showMilestoneDetailSheet (public / unauthenticated path)', () {
    testWidgets(
      'renders milestone content even when timelineProvider has no artist',
      (tester) async {
        final milestone = _milestone();
        late BuildContext capturedCtx;

        await tester.pumpWidget(
          _hostApp(
            onTap: () {
              // Public path — caller does NOT supply `onToggleReaction`.
              showMilestoneDetailSheet(capturedCtx, milestone);
            },
          ),
        );
        // Capture a context that is below MaterialApp / Localizations so the
        // sheet's `context.l10n` lookup succeeds.
        capturedCtx = tester.element(find.byType(ElevatedButton));

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // The pre-fix bug rendered SizedBox.shrink() here. We assert the
        // milestone title and description (the "did the sheet actually open"
        // signals) are visible.
        expect(find.text(milestone.title), findsOneWidget);
        expect(find.text(milestone.description!), findsOneWidget);
        // Reaction UI is gated on `onToggleReaction != null`; on the public
        // path it must stay hidden.
        expect(find.text('🔥'), findsNothing);
      },
    );

    testWidgets('renders milestone with no description without crashing', (
      tester,
    ) async {
      final milestone = _milestone(description: null);
      late BuildContext capturedCtx;

      await tester.pumpWidget(
        _hostApp(onTap: () => showMilestoneDetailSheet(capturedCtx, milestone)),
      );
      capturedCtx = tester.element(find.byType(ElevatedButton));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text(milestone.title), findsOneWidget);
    });
  });
}
