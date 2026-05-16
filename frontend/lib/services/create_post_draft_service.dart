import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/create_post_draft.dart';

/// Persistence layer for [CreatePostDraft]. Stores one draft per user under
/// the key `create_post_draft_<userId>` so a leftover draft from a previous
/// account cannot leak across accounts on the same device — even if the
/// logout path is bypassed (e.g. JWT expiry).
///
/// All exceptions are swallowed: a corrupted or unreadable draft must never
/// block the post composer from opening. Specifically, if
/// `SharedPreferences.getInstance()` itself throws — possible on Web when
/// localStorage is disabled (private/incognito with strict cookie blocking,
/// some embedded browsers) — every method below becomes a quiet no-op
/// instead of cascading failures up into the composer.
class CreatePostDraftService {
  static const String _keyPrefix = 'create_post_draft_';

  /// Eagerly-started, cached future. Initialization runs once per instance
  /// and the same `Future` is awaited by every save/load/clear call.
  /// Resolves to `null` when the underlying store is unavailable, which
  /// switches every operation into a no-op.
  final Future<SharedPreferences?> _prefs;

  CreatePostDraftService({Future<SharedPreferences> Function()? prefsFactory})
    : _prefs = _initialize(prefsFactory ?? SharedPreferences.getInstance);

  static Future<SharedPreferences?> _initialize(
    Future<SharedPreferences> Function() factory,
  ) async {
    try {
      return await factory();
    } catch (e) {
      // One log line on init failure — every subsequent save/load/clear
      // becomes a silent no-op so we don't spam logs for a known-broken
      // environment.
      debugPrint(
        '[CreatePostDraftService] SharedPreferences unavailable, '
        'draft autosave disabled: $e',
      );
      return null;
    }
  }

  String _keyFor(String userId) => '$_keyPrefix$userId';

  /// Save (overwrite) the draft for [draft.userId].
  Future<void> save(CreatePostDraft draft) async {
    final prefs = await _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_keyFor(draft.userId), draft.toJsonString());
    } catch (e) {
      debugPrint('[CreatePostDraftService] save failed: $e');
    }
  }

  /// Load the draft for [userId]. Returns null if no draft is stored, the
  /// payload is malformed, or the stored `userId` does not match.
  Future<CreatePostDraft?> load(String userId) async {
    final prefs = await _prefs;
    if (prefs == null) return null;
    try {
      final raw = prefs.getString(_keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      final draft = CreatePostDraft.tryDecode(raw, expectedUserId: userId);
      if (draft == null) {
        // Corrupted or mismatched payload — proactively clear it so we
        // don't keep trying to decode the same garbage on every open.
        await prefs.remove(_keyFor(userId));
        return null;
      }
      return draft;
    } catch (e) {
      debugPrint('[CreatePostDraftService] load failed: $e');
      return null;
    }
  }

  /// Clear the draft for [userId]. Called on submit success, explicit
  /// discard, and logout.
  Future<void> clear(String userId) async {
    final prefs = await _prefs;
    if (prefs == null) return;
    try {
      await prefs.remove(_keyFor(userId));
    } catch (e) {
      debugPrint('[CreatePostDraftService] clear failed: $e');
    }
  }
}
