import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:gleisner_web/models/create_post_draft.dart';
import 'package:gleisner_web/models/post.dart';

void main() {
  group('CreatePostDraft.toJsonString / tryDecode round-trip', () {
    test('preserves all fields', () {
      final original = CreatePostDraft(
        userId: 'user-1',
        step: 2,
        selectedTrackId: 'track-1',
        selectedMediaType: MediaType.article,
        visibility: 'draft',
        importance: 0.75,
        articleGenre: ArticleGenre.essay,
        externalPublish: true,
        title: 'Hello',
        body: 'World',
        bodyFormat: 'delta',
        mediaUrl: 'https://example.com/a.jpg',
        mediaUrls: const [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ],
        thumbnailUrl: 'https://example.com/thumb.jpg',
        durationSeconds: 42,
        eventAt: DateTime.utc(2026, 4, 1, 12),
        savedAt: DateTime.utc(2026, 5, 16, 10),
      );

      final round = CreatePostDraft.tryDecode(
        original.toJsonString(),
        expectedUserId: 'user-1',
      );

      expect(round, isNotNull);
      expect(round!.userId, 'user-1');
      expect(round.step, 2);
      expect(round.selectedTrackId, 'track-1');
      expect(round.selectedMediaType, MediaType.article);
      expect(round.visibility, 'draft');
      expect(round.importance, 0.75);
      expect(round.articleGenre, ArticleGenre.essay);
      expect(round.externalPublish, true);
      expect(round.title, 'Hello');
      expect(round.body, 'World');
      expect(round.bodyFormat, 'delta');
      expect(round.mediaUrl, 'https://example.com/a.jpg');
      expect(round.mediaUrls, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
      expect(round.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(round.durationSeconds, 42);
      expect(round.eventAt, DateTime.utc(2026, 4, 1, 12));
    });
  });

  group('CreatePostDraft.tryDecode security / validation', () {
    CreatePostDraft baseline() => CreatePostDraft(
      userId: 'user-1',
      step: 1,
      savedAt: DateTime.utc(2026, 5, 16),
    );

    test('rejects mismatched userId', () {
      final draft = baseline();
      final result = CreatePostDraft.tryDecode(
        draft.toJsonString(),
        expectedUserId: 'someone-else',
      );
      expect(result, isNull);
    });

    test('rejects payload without userId', () {
      final raw = jsonEncode({'step': 1, 'visibility': 'public'});
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result, isNull);
    });

    test('rejects malformed JSON', () {
      final result = CreatePostDraft.tryDecode(
        '{not-json',
        expectedUserId: 'user-1',
      );
      expect(result, isNull);
    });

    test('rejects JSON whose root is not an object', () {
      final result = CreatePostDraft.tryDecode('[]', expectedUserId: 'user-1');
      expect(result, isNull);
    });

    test('falls back to "public" for unknown visibility', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'visibility': 'private', // not in allow-list {public, draft}
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.visibility, 'public');
    });

    test('falls back to "public" when visibility is not a string', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'visibility': 42,
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.visibility, 'public');
    });

    test('clamps step to 0..2', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'step': 999,
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.step, 2);
    });

    test('clamps step to 0 when value is negative', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'step': -5,
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.step, 0);
    });

    test('clamps importance to 0.0..1.0', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'importance': 17.0,
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.importance, 1.0);
    });

    test('drops unknown articleGenre rather than throwing', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'articleGenre': 'not_a_real_genre',
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result, isNotNull);
      expect(result!.articleGenre, isNull);
    });

    test('drops unknown selectedMediaType rather than throwing', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'selectedMediaType': 'hologram',
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result, isNotNull);
      expect(result!.selectedMediaType, isNull);
    });

    test('filters non-string entries out of mediaUrls', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'mediaUrls': [
          'https://example.com/a.jpg',
          42,
          null,
          'https://example.com/b.jpg',
        ],
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.mediaUrls, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
    });

    test('returns null mediaUrls when value is not a list', () {
      final raw = jsonEncode({
        'userId': 'user-1',
        'mediaUrls': 'oops',
        'savedAt': DateTime.utc(2026, 5, 16).toIso8601String(),
      });
      final result = CreatePostDraft.tryDecode(raw, expectedUserId: 'user-1');
      expect(result?.mediaUrls, isNull);
    });
  });

  group('CreatePostDraft.hasMeaningfulInput', () {
    CreatePostDraft empty() =>
        CreatePostDraft(userId: 'user-1', savedAt: DateTime.utc(2026, 5, 16));

    test('false for a fresh step-0 draft with no input', () {
      expect(empty().hasMeaningfulInput, isFalse);
    });

    test('true when step has advanced', () {
      final d = CreatePostDraft(
        userId: 'user-1',
        step: 1,
        savedAt: DateTime.utc(2026, 5, 16),
      );
      expect(d.hasMeaningfulInput, isTrue);
    });

    test('true when a track has been selected', () {
      final d = CreatePostDraft(
        userId: 'user-1',
        selectedTrackId: 'track-1',
        savedAt: DateTime.utc(2026, 5, 16),
      );
      expect(d.hasMeaningfulInput, isTrue);
    });

    test('true when title is non-empty', () {
      final d = CreatePostDraft(
        userId: 'user-1',
        title: 'hello',
        savedAt: DateTime.utc(2026, 5, 16),
      );
      expect(d.hasMeaningfulInput, isTrue);
    });

    test('true when mediaUrls contains items', () {
      final d = CreatePostDraft(
        userId: 'user-1',
        mediaUrls: const ['https://example.com/a.jpg'],
        savedAt: DateTime.utc(2026, 5, 16),
      );
      expect(d.hasMeaningfulInput, isTrue);
    });
  });
}
