import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/track.dart';
import 'package:gleisner_web/utils/track_activity.dart';

Post _post(String id, String? trackId, DateTime createdAt) => Post(
  id: id,
  mediaType: MediaType.thought,
  importance: 0.5,
  createdAt: createdAt,
  updatedAt: createdAt,
  author: const PostAuthor(id: 'u1', username: 'tester'),
  trackId: trackId,
);

Track _track(String id, String name) =>
    Track(id: id, name: name, color: '#888888', createdAt: DateTime(2026));

void main() {
  group('computeTrackActivity', () {
    final now = DateTime.utc(2026, 5, 25, 12, 0, 0);

    test('counts posts within the 7-day window', () {
      final posts = [
        _post('1', 't1', now.subtract(const Duration(days: 1))),
        _post('2', 't1', now.subtract(const Duration(days: 6, hours: 23))),
        _post('3', 't1', now.subtract(const Duration(days: 8))), // out
        _post('4', 't2', now.subtract(const Duration(days: 2))),
      ];
      final activity = computeTrackActivity(posts, now: now);

      expect(activity['t1']?.weekPostCount, 2);
      expect(activity['t2']?.weekPostCount, 1);
      // t3 absent from input → must be absent from map (caller treats as empty)
      expect(activity.containsKey('t3'), isFalse);
    });

    test('marks tracks with posts in the last 24h as fresh', () {
      final posts = [
        _post('1', 't1', now.subtract(const Duration(hours: 1))),
        _post('2', 't2', now.subtract(const Duration(hours: 25))),
      ];
      final activity = computeTrackActivity(posts, now: now);

      expect(activity['t1']?.isFresh, isTrue);
      expect(activity['t2']?.isFresh, isFalse);
    });

    test('weekPostCount >= 5 marks track as active (halo eligible)', () {
      final posts = [
        for (var i = 0; i < 5; i++)
          _post('p$i', 't1', now.subtract(Duration(days: i))),
        for (var i = 0; i < 4; i++)
          _post('q$i', 't2', now.subtract(Duration(days: i))),
      ];
      final activity = computeTrackActivity(posts, now: now);

      expect(activity['t1']?.isActive, isTrue);
      expect(activity['t2']?.isActive, isFalse);
    });

    test('posts without trackId are ignored', () {
      final posts = [
        _post('1', null, now.subtract(const Duration(hours: 2))),
        _post('2', 't1', now.subtract(const Duration(hours: 2))),
      ];
      final activity = computeTrackActivity(posts, now: now);

      expect(activity.length, 1);
      expect(activity['t1']?.weekPostCount, 1);
    });

    test('returns empty map when no posts fall in the window', () {
      final posts = [_post('1', 't1', now.subtract(const Duration(days: 30)))];
      expect(computeTrackActivity(posts, now: now), isEmpty);
    });
  });

  group('shuffleTracks', () {
    test('returns a new list (does not mutate input)', () {
      final tracks = [_track('t1', 'A'), _track('t2', 'B'), _track('t3', 'C')];
      final inputCopy = List<Track>.from(tracks);
      final shuffled = shuffleTracks(tracks, 42);

      expect(tracks, equals(inputCopy));
      expect(shuffled, isNot(same(tracks)));
      expect(shuffled.length, tracks.length);
    });

    test('same seed yields same order (deterministic)', () {
      final tracks = [
        _track('t1', 'A'),
        _track('t2', 'B'),
        _track('t3', 'C'),
        _track('t4', 'D'),
      ];
      final a = shuffleTracks(tracks, 12345);
      final b = shuffleTracks(tracks, 12345);
      expect(a.map((t) => t.id), equals(b.map((t) => t.id)));
    });

    test('different seeds usually produce different orders', () {
      final tracks = [for (var i = 0; i < 6; i++) _track('t$i', 'name$i')];
      final a = shuffleTracks(tracks, 1);
      final b = shuffleTracks(tracks, 2);
      // With 6! = 720 permutations the seed-1 and seed-2 outputs being
      // identical would be a strong signal of a broken Random.
      expect(a.map((t) => t.id), isNot(equals(b.map((t) => t.id))));
    });

    test('empty input returns empty list', () {
      expect(shuffleTracks(const [], 1), isEmpty);
    });
  });
}
