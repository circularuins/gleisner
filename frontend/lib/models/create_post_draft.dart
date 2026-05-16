import 'dart:convert';

import 'post.dart';

/// Persisted draft of an in-progress post. Stored in shared_preferences
/// under a user-scoped key so unexpected closures (crash, tab close,
/// accidental dialog dismiss) do not lose input.
///
/// Intentionally minimal:
/// - Selections that reference other domain objects (track, connections)
///   are stored as IDs only and re-resolved on load. The track is looked up
///   from the user's own tracks; connections are not persisted to avoid
///   leaking private post IDs into local storage.
/// - The `userId` field is the trust boundary: [CreatePostDraftService]
///   refuses to return a draft whose `userId` does not match the
///   currently-authenticated user.
class CreatePostDraft {
  final String userId;
  final int step;
  final String? selectedTrackId;
  final MediaType? selectedMediaType;
  final String visibility;
  final double importance;
  final ArticleGenre? articleGenre;
  final bool externalPublish;
  final String title;
  final String body;
  final String? bodyFormat;
  final String? mediaUrl;
  final List<String>? mediaUrls;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final DateTime? eventAt;
  final DateTime savedAt;

  const CreatePostDraft({
    required this.userId,
    this.step = 0,
    this.selectedTrackId,
    this.selectedMediaType,
    this.visibility = 'public',
    this.importance = 0.5,
    this.articleGenre,
    this.externalPublish = false,
    this.title = '',
    this.body = '',
    this.bodyFormat,
    this.mediaUrl,
    this.mediaUrls,
    this.thumbnailUrl,
    this.durationSeconds,
    this.eventAt,
    required this.savedAt,
  });

  /// True when the draft holds enough state to bother restoring or
  /// confirming discard. A bare-step-0 draft with no track is treated as
  /// "empty" and skipped.
  bool get hasMeaningfulInput {
    if (step > 0) return true;
    if (selectedTrackId != null) return true;
    if (title.isNotEmpty || body.isNotEmpty) return true;
    if (mediaUrl != null && mediaUrl!.isNotEmpty) return true;
    if (mediaUrls != null && mediaUrls!.isNotEmpty) return true;
    return false;
  }

  String toJsonString() => jsonEncode({
    'userId': userId,
    'step': step,
    'selectedTrackId': selectedTrackId,
    'selectedMediaType': selectedMediaType?.name,
    'visibility': visibility,
    'importance': importance,
    'articleGenre': articleGenre?.name,
    'externalPublish': externalPublish,
    'title': title,
    'body': body,
    'bodyFormat': bodyFormat,
    'mediaUrl': mediaUrl,
    'mediaUrls': mediaUrls,
    'thumbnailUrl': thumbnailUrl,
    'durationSeconds': durationSeconds,
    'eventAt': eventAt?.toUtc().toIso8601String(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  });

  /// Decode and validate a serialized draft. Returns null when the payload
  /// is malformed, the required `userId` is missing, or the saved userId
  /// does not match [expectedUserId]. All enum / numeric / list fields are
  /// validated against allow-lists so a tampered payload cannot inject
  /// unexpected values into the form state.
  static CreatePostDraft? tryDecode(
    String raw, {
    required String expectedUserId,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final userId = decoded['userId'];
      if (userId is! String || userId.isEmpty) return null;
      if (userId != expectedUserId) return null;

      final stepRaw = decoded['step'];
      final step = stepRaw is int ? stepRaw.clamp(0, 2) : 0;

      final mediaType = _parseMediaType(decoded['selectedMediaType']);

      const visibilityAllowed = {'public', 'draft'};
      final visibilityRaw = decoded['visibility'];
      final visibility =
          visibilityRaw is String && visibilityAllowed.contains(visibilityRaw)
          ? visibilityRaw
          : 'public';

      final importanceRaw = decoded['importance'];
      final importance = importanceRaw is num
          ? importanceRaw.toDouble().clamp(0.0, 1.0)
          : 0.5;

      final articleGenre = _parseArticleGenre(decoded['articleGenre']);

      final externalPublish = decoded['externalPublish'] == true;

      String stringOrEmpty(dynamic v) => v is String ? v : '';
      String? nullableString(dynamic v) =>
          v is String && v.isNotEmpty ? v : null;
      int? nullableInt(dynamic v) => v is int ? v : null;

      List<String>? nullableStringList(dynamic v) {
        if (v is! List) return null;
        final out = <String>[];
        for (final e in v) {
          if (e is String && e.isNotEmpty) out.add(e);
        }
        return out.isEmpty ? null : out;
      }

      DateTime? nullableDateTime(dynamic v) {
        if (v is! String) return null;
        return DateTime.tryParse(v);
      }

      final savedAtRaw = decoded['savedAt'];
      final savedAt = savedAtRaw is String
          ? (DateTime.tryParse(savedAtRaw) ?? DateTime.now())
          : DateTime.now();

      return CreatePostDraft(
        userId: userId,
        step: step,
        selectedTrackId: nullableString(decoded['selectedTrackId']),
        selectedMediaType: mediaType,
        visibility: visibility,
        importance: importance,
        articleGenre: articleGenre,
        externalPublish: externalPublish,
        title: stringOrEmpty(decoded['title']),
        body: stringOrEmpty(decoded['body']),
        bodyFormat: nullableString(decoded['bodyFormat']),
        mediaUrl: nullableString(decoded['mediaUrl']),
        mediaUrls: nullableStringList(decoded['mediaUrls']),
        thumbnailUrl: nullableString(decoded['thumbnailUrl']),
        durationSeconds: nullableInt(decoded['durationSeconds']),
        eventAt: nullableDateTime(decoded['eventAt']),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static MediaType? _parseMediaType(dynamic raw) {
    if (raw is! String) return null;
    for (final m in MediaType.values) {
      if (m.name == raw) return m;
    }
    return null;
  }

  static ArticleGenre? _parseArticleGenre(dynamic raw) {
    if (raw is! String) return null;
    for (final g in ArticleGenre.values) {
      if (g.name == raw) return g;
    }
    return null;
  }
}
