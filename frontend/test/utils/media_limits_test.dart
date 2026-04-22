import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/l10n.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/utils/media_limits.dart';

Future<AppLocalizations> _loadL10n(String locale) =>
    AppLocalizations.delegate.load(Locale(locale));

void main() {
  group('maxMinutesFor', () {
    test('returns 1 for video (60 second limit)', () {
      expect(maxMinutesFor(MediaType.video), 1);
    });

    test('returns 5 for audio (300 second limit)', () {
      expect(maxMinutesFor(MediaType.audio), 5);
    });

    test('returns null for media types without a duration limit', () {
      expect(maxMinutesFor(MediaType.image), isNull);
      expect(maxMinutesFor(MediaType.thought), isNull);
      expect(maxMinutesFor(MediaType.article), isNull);
      expect(maxMinutesFor(MediaType.link), isNull);
    });
  });

  group('uploadHintFor (English)', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await _loadL10n('en');
    });

    test('video hint references 1 minute limit', () {
      expect(uploadHintFor(MediaType.video, l10n), 'Up to 1 min');
    });

    test('audio hint references 5 minute limit', () {
      expect(uploadHintFor(MediaType.audio, l10n), 'Up to 5 min');
    });

    test('image hint references maxImagesPerPost', () {
      expect(
        uploadHintFor(MediaType.image, l10n),
        'Up to $maxImagesPerPost images',
      );
    });

    test('types without a hint return null', () {
      expect(uploadHintFor(MediaType.thought, l10n), isNull);
      expect(uploadHintFor(MediaType.article, l10n), isNull);
      expect(uploadHintFor(MediaType.link, l10n), isNull);
    });
  });

  group('uploadHintFor (Japanese)', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await _loadL10n('ja');
    });

    test('video hint uses Japanese characters', () {
      expect(uploadHintFor(MediaType.video, l10n), '最大1分');
    });

    test('audio hint uses Japanese characters', () {
      expect(uploadHintFor(MediaType.audio, l10n), '最大5分');
    });

    test('image hint uses Japanese characters', () {
      expect(uploadHintFor(MediaType.image, l10n), '最大$maxImagesPerPost枚');
    });
  });
}
