import '../l10n/l10n.dart';
import '../models/post.dart' show MediaType;

/// Media duration limits (ADR 025).
/// Keep in sync with backend MAX_VIDEO_DURATION_SECONDS / MAX_AUDIO_DURATION_SECONDS.
const maxVideoDurationSeconds = 60; // 1 minute
const maxAudioDurationSeconds = 300; // 5 minutes

/// Maximum number of images per post.
/// Keep in sync with backend MAX_IMAGES_PER_POST.
const maxImagesPerPost = 10;

/// Returns the duration limit in whole minutes for media types that have one,
/// or null for types without a duration limit (image, thought, article, link).
/// Used by pre-upload hint UI and error messages.
///
/// Enumerate every MediaType explicitly rather than using a wildcard so that
/// adding a future variant (e.g. podcast, reel) triggers a compile-time
/// warning here and forces an explicit decision about its limit.
int? maxMinutesFor(MediaType mediaType) => switch (mediaType) {
  MediaType.video => maxVideoDurationSeconds ~/ 60,
  MediaType.audio => maxAudioDurationSeconds ~/ 60,
  MediaType.image ||
  MediaType.thought ||
  MediaType.article ||
  MediaType.link => null,
};

/// Hint text shown in the empty upload placeholder for a given media type.
/// Returns null when no hint is applicable (text/link/thought/article).
String? uploadHintFor(MediaType mediaType, AppLocalizations l10n) {
  if (mediaType == MediaType.image) {
    return l10n.mediaImageCountHint(maxImagesPerPost);
  }
  final minutes = maxMinutesFor(mediaType);
  return minutes == null ? null : l10n.mediaDurationHint(minutes);
}
