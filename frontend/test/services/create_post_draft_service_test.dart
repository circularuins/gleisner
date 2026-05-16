import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gleisner_web/models/create_post_draft.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/services/create_post_draft_service.dart';

void main() {
  late CreatePostDraftService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = CreatePostDraftService();
  });

  CreatePostDraft sampleDraft({String userId = 'user-1'}) => CreatePostDraft(
    userId: userId,
    step: 2,
    selectedTrackId: 'track-1',
    selectedMediaType: MediaType.thought,
    visibility: 'public',
    importance: 0.5,
    title: 'hello',
    body: 'world',
    savedAt: DateTime.utc(2026, 5, 16),
  );

  test('save then load returns equivalent draft', () async {
    await service.save(sampleDraft());

    final loaded = await service.load('user-1');

    expect(loaded, isNotNull);
    expect(loaded!.userId, 'user-1');
    expect(loaded.title, 'hello');
    expect(loaded.body, 'world');
    expect(loaded.selectedTrackId, 'track-1');
    expect(loaded.selectedMediaType, MediaType.thought);
  });

  test('load returns null when no draft is stored', () async {
    final loaded = await service.load('user-1');
    expect(loaded, isNull);
  });

  test('load returns null when called with a different userId', () async {
    await service.save(sampleDraft(userId: 'user-1'));

    // shared_preferences key is user-scoped: a different userId looks at a
    // different key entirely.
    final loaded = await service.load('user-2');
    expect(loaded, isNull);
  });

  test(
    'load returns null and clears the slot when payload is corrupted',
    () async {
      SharedPreferences.setMockInitialValues({
        'create_post_draft_user-1': '{not-json',
      });
      final svc = CreatePostDraftService();

      final loaded = await svc.load('user-1');
      expect(loaded, isNull);

      // A subsequent load should remain null (the corrupted slot was wiped).
      final loadedAgain = await svc.load('user-1');
      expect(loadedAgain, isNull);
    },
  );

  test('clear removes the stored draft for that user only', () async {
    await service.save(sampleDraft(userId: 'user-1'));
    await service.save(sampleDraft(userId: 'user-2'));

    await service.clear('user-1');

    expect(await service.load('user-1'), isNull);
    expect(await service.load('user-2'), isNotNull);
  });

  test('save overwrites the previous draft for the same user', () async {
    await service.save(sampleDraft());
    await service.save(
      CreatePostDraft(
        userId: 'user-1',
        title: 'second',
        savedAt: DateTime.utc(2026, 5, 16, 10),
      ),
    );

    final loaded = await service.load('user-1');
    expect(loaded?.title, 'second');
  });
}
