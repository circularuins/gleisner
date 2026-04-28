import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/post.dart';
import '../../models/track.dart' show Track, parseHexColor;
import '../../providers/create_post_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/constellation_layout.dart';
import '../../utils/ime_safe_focus.dart';
import '../../widgets/common/connection_type_picker.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/event_at_picker.dart';
import '../../widgets/common/related_post_picker.dart';
import '../../widgets/editor/rich_text_editor.dart';
import '../../widgets/editor/text_body_counter.dart';
import '../../theme/gleisner_tokens.dart';
import '../../providers/media_upload_provider.dart';
import '../../utils/media_limits.dart' show maxImagesPerPost, uploadHintFor;
import '../../widgets/common/image_grid_widgets.dart';
import '../../widgets/media/link_form_fields.dart';
import '../../widgets/media/upload_placeholder.dart';
import '../../widgets/timeline/seed_art_painter.dart';
import '../../l10n/l10n.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  /// Optional callback invoked after successful post creation (e.g. from Dialog).
  /// When null, defaults to `context.go('/timeline')`.
  final VoidCallback? onSuccess;

  const CreatePostScreen({super.key, this.onSuccess});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  final _quillController = QuillController.basic();
  // FocusNodes that block Tab during IME composition to prevent
  // Flutter Web assertion "Range end N is out of text of length 0".
  late final _urlFocusNode = createImeSafeFocusNode(_mediaUrlController);
  late final _linkTitleFocusNode = createImeSafeFocusNode(_titleController);
  late final _linkCaptionFocusNode = createImeSafeFocusNode(_bodyController);
  String? _thumbnailUrl;
  int? _durationSeconds;
  DateTime? _eventAt;
  final _formKey = GlobalKey<FormState>();
  int _pickMediaGeneration = 0;
  // Multi-image support for image type posts
  List<String> _mediaUrls = [];

  @override
  void dispose() {
    _pickMediaGeneration++; // invalidate any in-flight upload
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    _quillController.dispose();
    _urlFocusNode.dispose();
    _linkTitleFocusNode.dispose();
    _linkCaptionFocusNode.dispose();
    // Provider reset is handled in _submit() success path.
    // autoDispose cleans up when no watchers remain.
    super.dispose();
  }

  Future<void> _pickMedia(MediaType mediaType) async {
    final generation = ++_pickMediaGeneration;
    if (mediaType == MediaType.image) {
      await _pickMultipleImages(generation);
      return;
    }
    final l10n = context.l10n;
    final result = await ref
        .read(mediaUploadProvider.notifier)
        .pickByMediaType(mediaType, l10n: l10n);
    // Discard result if user navigated away or switched media type
    if (result != null && mounted && generation == _pickMediaGeneration) {
      setState(() {
        _mediaUrlController.text = result.mediaUrl;
        _thumbnailUrl = result.thumbnailUrl;
        _durationSeconds = result.durationSeconds;
      });
    }
  }

  Future<void> _pickMultipleImages(int generation) async {
    final remaining = maxImagesPerPost - _mediaUrls.length;
    if (remaining <= 0) return;
    final l10n = context.l10n;
    final urls = await ref
        .read(mediaUploadProvider.notifier)
        .pickAndUploadMultipleImages(
          category: UploadCategory.media,
          l10n: l10n,
          maxCount: remaining,
        );
    if (urls != null && mounted && generation == _pickMediaGeneration) {
      setState(() {
        _mediaUrls = [..._mediaUrls, ...urls];
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (ref.read(mediaUploadProvider).isUploading) return;

    // Require media file for media types (not thought/article/link)
    final mediaType = ref.read(createPostProvider).selectedMediaType;
    if (mediaType == MediaType.image && _mediaUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.uploadImageBeforePosting),
          backgroundColor: colorError,
        ),
      );
      return;
    }
    if (mediaType != null &&
        mediaType != MediaType.image &&
        mediaType != MediaType.article &&
        mediaType != MediaType.thought &&
        _mediaUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.uploadFileBeforePosting),
          backgroundColor: colorError,
        ),
      );
      return;
    }

    // Article: use Quill Delta; Thought + others: use plain body
    final isArticle =
        ref.read(createPostProvider).selectedMediaType == MediaType.article;
    String? bodyValue;
    String? bodyFormat;
    if (isArticle) {
      final delta = _quillController.document.toDelta().toJson();
      bodyValue = jsonEncode(delta);
      bodyFormat = 'delta';
      // Validate non-empty
      if (_quillController.document.isEmpty()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.textRequired),
            backgroundColor: colorError,
          ),
        );
        return;
      }
    } else {
      bodyValue = _bodyController.text.isEmpty ? null : _bodyController.text;
    }

    final result = await ref
        .read(createPostProvider.notifier)
        .submit(
          title: _titleController.text.isNotEmpty
              ? _titleController.text
              : null,
          body: bodyValue,
          bodyFormat: bodyFormat,
          mediaUrl: mediaType == MediaType.image
              ? null
              : (_mediaUrlController.text.isEmpty
                    ? null
                    : _mediaUrlController.text),
          mediaUrls: mediaType == MediaType.image && _mediaUrls.isNotEmpty
              ? _mediaUrls
              : null,
          thumbnailUrl: _thumbnailUrl,
          duration: _durationSeconds,
          eventAt: _eventAt,
        );

    if (result != null && mounted) {
      final (postedTrack, post) = result;
      final notifier = ref.read(timelineProvider.notifier);
      notifier.ensureTrackSelected(postedTrack.id);
      notifier.addPost(post);
      // Reset provider state before navigating away.
      // dispose() also calls reset(), but autoDispose + ref.read in dispose
      // can race — explicit reset here ensures clean state for next visit.
      ref.read(createPostProvider.notifier).reset();
      if (mounted) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          context.go('/timeline');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostProvider);
    final timeline = ref.watch(timelineProvider);
    final tracks = timeline.artist?.tracks ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (state.step > 0) {
              // Clear form inputs when going back from form step
              if (state.step == 2) {
                _pickMediaGeneration++; // invalidate any in-flight upload
                _titleController.clear();
                _bodyController.clear();
                _mediaUrlController.clear();
                _quillController.clear();
                _thumbnailUrl = null;
                _durationSeconds = null;
                _eventAt = null;
                _mediaUrls = [];
                ref.read(createPostProvider.notifier).clearFormState();
              }
              ref.read(createPostProvider.notifier).goBack();
            } else {
              context.go('/timeline');
            }
          },
        ),
        title: Text(context.l10n.newPost),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (state.step + 1) / 3,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (state.step) {
            0 => _TrackStep(tracks: tracks),
            1 => const _MediaTypeStep(),
            _ => _FormStep(
              formKey: _formKey,
              titleController: _titleController,
              bodyController: _bodyController,
              quillController: _quillController,
              mediaUrlController: _mediaUrlController,
              thumbnailUrl: _thumbnailUrl,
              durationSeconds: _durationSeconds,
              urlFocusNode: _urlFocusNode,
              linkTitleFocusNode: _linkTitleFocusNode,
              linkCaptionFocusNode: _linkCaptionFocusNode,
              eventAt: _eventAt,
              onEventAtChanged: (dt) => setState(() => _eventAt = dt),
              onSubmit: _submit,
              onPickMedia: _pickMedia,
              mediaUrls: _mediaUrls,
              onMediaUrlsChanged: (urls) => setState(() => _mediaUrls = urls),
            ),
          },
        ),
      ),
    );
  }
}

// Preset colors for auto-assignment (avoids duplicates with existing tracks)
const _trackColorPresets = trackColorPresets;

const _maxTracks = 10;

// Step 0 — Track selection
class _TrackStep extends ConsumerWidget {
  final List<Track> tracks;

  const _TrackStep({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canAddTrack = tracks.length < _maxTracks;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.selectTrack,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: spaceXl),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ...tracks.map((track) {
                  return ActionChip(
                    label: Text(
                      track.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                    avatar: CircleAvatar(
                      backgroundColor: track.displayColor,
                      radius: 10,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: BorderSide(color: track.displayColor),
                    onPressed: () => ref
                        .read(createPostProvider.notifier)
                        .selectTrack(track),
                  );
                }),
                if (canAddTrack)
                  ActionChip(
                    label: Text(
                      '+ ${context.l10n.newTrack}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    onPressed: () => _showCreateTrackDialog(context, ref),
                  ),
              ],
            ),
            if (!canAddTrack)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.l10n.maxTracks(_maxTracks),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateTrackDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final existingColors = tracks.map((t) => t.color.toLowerCase()).toSet();
    final autoColor = _trackColorPresets.firstWhere(
      (c) => !existingColors.contains(c),
      orElse: () =>
          _trackColorPresets[tracks.length % _trackColorPresets.length],
    );
    final notifier = ref.read(timelineProvider.notifier);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isCreating = false;
        String? errorText;

        Future<void> submit(StateSetter setDialogState) async {
          final name = controller.text.trim();
          if (name.isEmpty) {
            setDialogState(
              () => errorText = l10n.fieldRequired(l10n.trackName),
            );
            return;
          }
          if (tracks.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
            setDialogState(() => errorText = l10n.trackAlreadyExists(name));
            return;
          }

          setDialogState(() {
            isCreating = true;
            errorText = null;
          });

          final (track, error) = await notifier.createTrack(name, autoColor);
          if (track != null) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } else {
            if (dialogContext.mounted) {
              setDialogState(() {
                isCreating = false;
                errorText = error ?? l10n.failedCreateTrack;
              });
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.newTrack),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: l10n.trackName,
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onSubmitted: isCreating
                        ? null
                        : (_) => submit(setDialogState),
                  ),
                  const SizedBox(height: spaceSm),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: parseHexColor(autoColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: spaceSm),
                      Text(
                        l10n.colorAutoAssigned,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: isCreating ? null : () => submit(setDialogState),
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.create),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Step 1 — MediaType selection
class _MediaTypeStep extends ConsumerWidget {
  const _MediaTypeStep();

  static const _mediaTypeIcons = [
    (MediaType.thought, Icons.chat_bubble_outline),
    (MediaType.article, Icons.description_outlined),
    (MediaType.image, Icons.image),
    (MediaType.video, Icons.videocam),
    (MediaType.audio, Icons.audiotrack),
    (MediaType.link, Icons.link),
  ];

  static String _mediaTypeName(BuildContext context, MediaType type) {
    final l10n = context.l10n;
    return switch (type) {
      MediaType.thought => l10n.mediaTypeThought,
      MediaType.article => l10n.mediaTypeArticle,
      MediaType.image => l10n.mediaTypeImage,
      MediaType.video => l10n.mediaTypeVideo,
      MediaType.audio => l10n.mediaTypeAudio,
      MediaType.link => l10n.mediaTypeLink,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.contentType,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: spaceXxl),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _mediaTypeIcons.map((option) {
                final (type, icon) = option;
                return SizedBox(
                  width: 88,
                  child: Column(
                    children: [
                      IconButton.filledTonal(
                        iconSize: 40,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(64, 64),
                        ),
                        onPressed: () => ref
                            .read(createPostProvider.notifier)
                            .selectMediaType(type),
                        icon: Icon(icon),
                      ),
                      const SizedBox(height: spaceXs),
                      Text(
                        _mediaTypeName(context, type),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// Step 2 — Form & submit (media-type-specific layout)
class _FormStep extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final QuillController quillController;
  final TextEditingController mediaUrlController;
  final String? thumbnailUrl;
  final int? durationSeconds;
  // Focus nodes are always supplied by the only call site (the create
  // screen state's `late final _urlFocusNode` etc.), so non-nullable types
  // are strictly correct and let callers drop the `!` at the use site.
  final FocusNode urlFocusNode;
  final FocusNode linkTitleFocusNode;
  final FocusNode linkCaptionFocusNode;
  final DateTime? eventAt;
  final ValueChanged<DateTime?> onEventAtChanged;
  final VoidCallback onSubmit;
  final Future<void> Function(MediaType) onPickMedia;
  final List<String> mediaUrls;
  final ValueChanged<List<String>> onMediaUrlsChanged;

  const _FormStep({
    required this.formKey,
    required this.titleController,
    required this.bodyController,
    required this.quillController,
    required this.mediaUrlController,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.urlFocusNode,
    required this.linkTitleFocusNode,
    required this.linkCaptionFocusNode,
    this.eventAt,
    required this.onEventAtChanged,
    required this.onSubmit,
    required this.mediaUrls,
    required this.onMediaUrlsChanged,
    required this.onPickMedia,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createPostProvider);
    final mediaType = state.selectedMediaType!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Track + MediaType + Visibility — compact header row
            Row(
              children: [
                if (state.selectedTrack != null)
                  _TagPill(
                    color: state.selectedTrack!.displayColor,
                    label: state.selectedTrack!.name,
                  ),
                const SizedBox(width: spaceSm),
                _TagPill(
                  icon: _mediaTypeIcon(mediaType),
                  label: mediaType.name,
                ),
                const Spacer(),
                // Visibility toggle
                GestureDetector(
                  onTap: () {
                    final next = state.visibility == 'public'
                        ? 'draft'
                        : 'public';
                    ref.read(createPostProvider.notifier).setVisibility(next);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: spaceSm,
                      vertical: spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: state.visibility == 'public'
                          ? colorAccentGold.withValues(alpha: opacitySubtle)
                          : colorSurface2,
                      borderRadius: BorderRadius.circular(radiusFull),
                      border: Border.all(
                        color: state.visibility == 'public'
                            ? colorAccentGold.withValues(alpha: opacityBorder)
                            : colorBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.visibility == 'public'
                              ? Icons.public
                              : Icons.edit_note,
                          size: 14,
                          color: state.visibility == 'public'
                              ? colorAccentGold
                              : colorTextMuted,
                        ),
                        const SizedBox(width: spaceXs),
                        Text(
                          state.visibility == 'public'
                              ? context.l10n.public
                              : context.l10n.draft,
                          style: TextStyle(
                            fontSize: fontSizeSm,
                            color: state.visibility == 'public'
                                ? colorAccentGold
                                : colorTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: spaceMd),

            // Media-type-specific fields
            ..._buildContentFields(context, mediaType, theme, ref),

            // Event date (when did this happen?)
            EventAtPicker(eventAt: eventAt, onChanged: onEventAtChanged),
            const SizedBox(height: spaceLg),

            // Related posts (connections)
            _ConnectionsSection(
              connections: state.selectedConnections,
              allPosts: ref.watch(timelineProvider).posts,
              onRemove: (postId) => ref
                  .read(createPostProvider.notifier)
                  .removeConnection(postId),
              onAddRequested: () => _showAddConnection(context, ref),
            ),
            const SizedBox(height: spaceXl),

            // Importance slider + node preview
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.importance,
                  style: theme.textTheme.titleSmall,
                ),
                Row(
                  children: [
                    Text(
                      context.l10n.quietNote,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: state.importance,
                        onChanged: (v) => ref
                            .read(createPostProvider.notifier)
                            .setImportance(v),
                      ),
                    ),
                    Text(
                      context.l10n.heroMoment,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: spaceSm),
                _ImportancePreview(
                  importance: state.importance,
                  mediaType: mediaType,
                  trackColor:
                      state.selectedTrack?.displayColor ??
                      theme.colorScheme.primary,
                  title: titleController.text,
                  body: bodyController.text,
                  trackName: state.selectedTrack?.name ?? '',
                ),
              ],
            ),
            const SizedBox(height: spaceXl),

            // Error
            if (state.error != null) ...[
              ErrorBanner(message: state.error!),
              const SizedBox(height: spaceLg),
            ],

            // Submit
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed:
                    state.isSubmitting ||
                        ref.watch(mediaUploadProvider).isUploading
                    ? null
                    : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: colorAccentGold,
                  foregroundColor: colorSurface0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                ),
                child: state.isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorSurface0,
                        ),
                      )
                    : Text(
                        context.l10n.post,
                        style: const TextStyle(
                          fontWeight: weightSemibold,
                          fontSize: fontSizeMd,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddConnection(BuildContext context, WidgetRef ref) async {
    // Step 1: Pick type
    final type = await showConnectionTypePicker(context);
    if (type == null || !context.mounted) return;

    // Step 2: Pick target post
    final posts = ref.read(timelineProvider).posts;
    final existing = ref.read(createPostProvider).selectedConnections;
    Post? selected;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RelatedPostPicker(
        posts: posts,
        excludePostIds: existing.map((c) => c.post.id).toSet(),
        onSelected: (post) {
          selected = post;
        },
      ),
    );
    if (selected != null && context.mounted) {
      ref.read(createPostProvider.notifier).addConnection(selected!, type);
    }
  }

  List<Widget> _buildContentFields(
    BuildContext context,
    MediaType mediaType,
    ThemeData theme,
    WidgetRef ref,
  ) {
    switch (mediaType) {
      case MediaType.thought:
        return _buildThoughtFields(context, theme);
      case MediaType.article:
        return _buildTextFields(context, theme, ref);
      case MediaType.image:
      case MediaType.video:
      case MediaType.audio:
        return _buildMediaFields(context, mediaType, theme, ref);
      case MediaType.link:
        return _buildLinkFields(context, theme);
    }
  }

  // thought: plain text body only, 280 char limit, no title
  List<Widget> _buildThoughtFields(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    return [
      Container(
        decoration: BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: colorBorder),
        ),
        child: TextField(
          controller: bodyController,
          maxLines: 6,
          maxLength: 280,
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeMd,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: l10n.whatsOnYourMind,
            hintStyle: const TextStyle(color: colorInteractiveMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(spaceLg),
            counterStyle: const TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeXs,
            ),
          ),
        ),
      ),
    ];
  }

  // article: title (optional) + rich text editor
  List<Widget> _buildTextFields(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final l10n = context.l10n;
    return [
      Container(
        decoration: const BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusMd)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spaceLg),
        child: TextFormField(
          controller: titleController,
          maxLength: 100,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: l10n.title,
            hintStyle: const TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeLg,
              fontWeight: weightMedium,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: spaceMd),
            counterStyle: TextStyle(
              fontSize: fontSizeXs,
              color: colorTextMuted.withValues(alpha: 0.5),
            ),
          ),
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeLg,
            fontWeight: weightMedium,
          ),
        ),
      ),
      const Divider(color: colorBorder, height: 1, indent: 0),
      // Rich text editor for the body
      SizedBox(
        height: 400,
        child: RichTextEditor(
          controller: quillController,
          placeholder: l10n.whatsOnYourMind,
          autofocus: true,
          toolbarCollapsed: true,
        ),
      ),
      // Character count for text body
      TextBodyCounter(controller: quillController),
      const SizedBox(height: spaceMd),
      // Article genre picker
      const _ArticleGenrePicker(),
      const SizedBox(height: spaceMd),
      // External publish toggle (only when visibility is public)
      const _ExternalPublishToggle(),
      const SizedBox(height: spaceLg),
    ];
  }

  // image/video/audio: upload area (hero) + title + caption
  List<Widget> _buildMediaFields(
    BuildContext context,
    MediaType mediaType,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final (icon, _) = switch (mediaType) {
      MediaType.image => (
        Icons.add_photo_alternate_outlined,
        context.l10n.mediaTypeImage,
      ),
      MediaType.video => (Icons.videocam_outlined, context.l10n.mediaTypeVideo),
      MediaType.audio => (
        Icons.audiotrack_outlined,
        context.l10n.mediaTypeAudio,
      ),
      MediaType.thought ||
      MediaType.article ||
      MediaType.link => (Icons.attach_file, context.l10n.mediaTypeMedia),
    };

    final uploadState = ref.watch(mediaUploadProvider);
    final hasMedia = mediaType == MediaType.image
        ? mediaUrls.isNotEmpty
        : mediaUrlController.text.isNotEmpty;

    return [
      // Upload area — the hero of the form
      GestureDetector(
        onTap: uploadState.isUploading ? null : () => onPickMedia(mediaType),
        child: uploadState.isUploading
            ? Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colorSurface2,
                  borderRadius: BorderRadius.circular(radiusLg),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorTextMuted,
                    ),
                  ),
                ),
              )
            : hasMedia
            ? _buildMediaPreview(context, mediaType)
            : UploadPlaceholderContent(
                icon: icon,
                hint: uploadHintFor(mediaType, context.l10n),
              ),
      ),
      if (uploadState.error != null) ...[
        const SizedBox(height: spaceSm),
        Text(
          uploadState.error!,
          style: const TextStyle(color: colorError, fontSize: fontSizeSm),
        ),
      ],
      const SizedBox(height: spaceMd),
      // Title
      Container(
        decoration: BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spaceMd),
        child: TextFormField(
          controller: titleController,
          focusNode: linkTitleFocusNode,
          maxLength: 100,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: context.l10n.title,
            hintStyle: const TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeLg,
              fontWeight: weightMedium,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: spaceMd),
            counterStyle: TextStyle(
              fontSize: fontSizeXs,
              color: colorTextMuted.withValues(alpha: 0.5),
            ),
          ),
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeLg,
            fontWeight: weightMedium,
          ),
        ),
      ),
      const SizedBox(height: spaceSm),
      // Caption
      Container(
        decoration: BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spaceMd),
        child: TextFormField(
          controller: bodyController,
          focusNode: linkCaptionFocusNode,
          maxLines: 4,
          minLines: 2,
          maxLength: 500,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: context.l10n.writeCaption,
            hintStyle: const TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeMd,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: spaceSm),
            counterStyle: TextStyle(
              fontSize: fontSizeXs,
              color: colorTextMuted.withValues(alpha: 0.5),
            ),
          ),
          style: const TextStyle(
            color: colorTextSecondary,
            fontSize: fontSizeMd,
            height: 1.5,
          ),
        ),
      ),
      const SizedBox(height: spaceMd),
    ];
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildMediaPreview(BuildContext context, MediaType mediaType) {
    // Audio: dedicated preview card
    if (mediaType == MediaType.audio) {
      return _buildAudioPreview(context);
    }

    // Image: multi-image grid
    if (mediaType == MediaType.image) {
      return _buildImageGrid();
    }

    final showThumbnail =
        mediaType == MediaType.video &&
        thumbnailUrl != null &&
        thumbnailUrl!.isNotEmpty;
    final displayUrl = thumbnailUrl ?? '';

    return Stack(
      children: [
        if (showThumbnail)
          ClipRRect(
            borderRadius: BorderRadius.circular(radiusLg),
            child: Image.network(
              displayUrl,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: colorSurface2,
                    borderRadius: BorderRadius.circular(radiusLg),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                height: 240,
                decoration: BoxDecoration(
                  color: colorSurface2,
                  borderRadius: BorderRadius.circular(radiusLg),
                ),
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: colorTextMuted,
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: colorSurface2,
              borderRadius: BorderRadius.circular(radiusLg),
            ),
            child: const Center(
              child: Icon(
                Icons.videocam_outlined,
                size: 48,
                color: colorAccentGold,
              ),
            ),
          ),
        // Replace badge
        Positioned(
          top: spaceSm,
          right: spaceSm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: spaceSm,
              vertical: spaceXs,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                const SizedBox(width: spaceXs),
                Text(
                  context.l10n.replace,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: fontSizeXs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrls.isNotEmpty)
          Wrap(
            spacing: spaceSm,
            runSpacing: spaceSm,
            children: [
              for (int i = 0; i < mediaUrls.length; i++)
                ImageTile(
                  url: mediaUrls[i],
                  onRemove: () {
                    onMediaUrlsChanged([
                      ...mediaUrls.sublist(0, i),
                      ...mediaUrls.sublist(i + 1),
                    ]);
                  },
                ),
              if (mediaUrls.length < maxImagesPerPost)
                AddImageTile(onTap: () => onPickMedia(MediaType.image)),
            ],
          )
        else
          AddImageTile(onTap: () => onPickMedia(MediaType.image)),
        if (mediaUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: spaceXs),
            child: Text(
              '${mediaUrls.length}/$maxImagesPerPost',
              style: const TextStyle(
                color: colorTextMuted,
                fontSize: fontSizeXs,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioPreview(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: colorSurface2,
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          padding: const EdgeInsets.all(spaceMd),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorAccentGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.audiotrack_rounded,
                  color: colorAccentGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: spaceMd),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.audioUploaded,
                      style: const TextStyle(
                        color: colorTextPrimary,
                        fontSize: fontSizeSm,
                        fontWeight: weightMedium,
                      ),
                    ),
                    if (durationSeconds != null) ...[
                      const SizedBox(height: spaceXs),
                      Text(
                        _formatDuration(durationSeconds!),
                        style: TextStyle(
                          color: colorTextMuted.withValues(alpha: 0.6),
                          fontSize: fontSizeXs,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // Replace badge
        Positioned(
          top: spaceSm,
          right: spaceSm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: spaceSm,
              vertical: spaceXs,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                const SizedBox(width: spaceXs),
                Text(
                  context.l10n.replace,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: fontSizeXs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // link: URL (required) + title + caption
  List<Widget> _buildLinkFields(BuildContext context, ThemeData theme) {
    // Focus nodes are non-nullable on `_FormStep` since the create screen
    // is the only caller and always wires them — `LinkFormFields` requires
    // IME-safe nodes as a hard contract.
    return [
      LinkFormFields(
        urlController: mediaUrlController,
        titleController: titleController,
        captionController: bodyController,
        urlFocusNode: urlFocusNode,
        titleFocusNode: linkTitleFocusNode,
        captionFocusNode: linkCaptionFocusNode,
        autofocusUrl: true,
      ),
    ];
  }
}

/// Live preview of node size as importance slider changes.
class _ImportancePreview extends StatelessWidget {
  final double importance;
  final MediaType mediaType;
  final Color trackColor;
  final String title;
  final String body;
  final String trackName;

  const _ImportancePreview({
    required this.importance,
    required this.mediaType,
    required this.trackColor,
    required this.title,
    required this.body,
    required this.trackName,
  });

  @override
  Widget build(BuildContext context) {
    final sz = ConstellationLayout.nodeSize(importance);
    final mediaH = sz > 110 ? sz * 0.7 : sz * 0.85;
    final w = sz > 110 ? sz * 1.25 : sz;
    final glowOpacity = 0.15 + importance * 0.25;
    final glowBlur = 8.0 + importance * 16;

    final seed = '${title}preview';

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: trackColor.withValues(alpha: glowOpacity),
              blurRadius: glowBlur,
              spreadRadius: 4.0 + importance * 12,
            ),
          ],
          border: Border.all(color: trackColor.withValues(alpha: 0.3)),
          color: colorSurface1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeedArtCanvas(
              width: w,
              height: mediaH,
              trackColor: trackColor,
              seed: seed,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trackName.toUpperCase(),
                    style: TextStyle(
                      color: trackColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        color: colorTextPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays selected connections and a button to add more (max 5).
class _ConnectionsSection extends StatelessWidget {
  final List<PendingConnection> connections;
  final List<Post> allPosts;
  final void Function(String postId) onRemove;
  final VoidCallback onAddRequested;

  const _ConnectionsSection({
    required this.connections,
    required this.allPosts,
    required this.onRemove,
    required this.onAddRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (allPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.connections, style: theme.textTheme.titleSmall),
        const SizedBox(height: spaceSm),
        ...connections.map((c) {
          final post = c.post;
          return Card(
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.connectionType.icon,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  if (post.trackColor != null) ...[
                    const SizedBox(width: spaceSm),
                    Container(
                      width: 4,
                      height: 32,
                      decoration: BoxDecoration(
                        color: parseHexColor(post.trackColor),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
              title: Text(
                post.title ??
                    post.body?.substring(0, post.body!.length.clamp(0, 40)) ??
                    post.mediaType.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${c.connectionType.label(context)} · ${post.trackName ?? ''}',
                style: theme.textTheme.labelSmall,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onRemove(post.id),
              ),
              dense: true,
            ),
          );
        }),
        if (connections.length < 5)
          OutlinedButton.icon(
            onPressed: onAddRequested,
            icon: const Icon(Icons.link, size: 18),
            label: Text(
              connections.isEmpty
                  ? context.l10n.linkToExistingPost
                  : context.l10n.addAnotherConnection,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withAlpha(180),
              side: BorderSide(color: theme.colorScheme.outline.withAlpha(80)),
            ),
          ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  final Color? color;
  final IconData? icon;
  final String label;

  const _TagPill({this.color, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: spaceSm,
        vertical: spaceXs,
      ),
      decoration: BoxDecoration(
        color: colorSurface2,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: spaceXs),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: spaceXs),
              child: Icon(icon, size: 14, color: colorTextMuted),
            ),
          Text(
            label,
            style: const TextStyle(
              fontSize: fontSizeSm,
              color: colorTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _mediaTypeIcon(MediaType type) {
  return switch (type) {
    MediaType.thought => Icons.chat_bubble_outline,
    MediaType.article => Icons.text_fields,
    MediaType.image => Icons.image_outlined,
    MediaType.video => Icons.videocam_outlined,
    MediaType.audio => Icons.headphones_outlined,
    MediaType.link => Icons.link,
  };
}

/// Genre picker for article posts.
class _ArticleGenrePicker extends ConsumerWidget {
  const _ArticleGenrePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      createPostProvider.select((s) => s.articleGenre),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.genre,
          style: const TextStyle(
            color: colorTextMuted,
            fontSize: fontSizeSm,
            fontWeight: weightSemibold,
          ),
        ),
        const SizedBox(height: spaceXs),
        Wrap(
          spacing: spaceSm,
          runSpacing: spaceXs,
          children: ArticleGenre.values.map((genre) {
            final isSelected = genre == selected;
            return ChoiceChip(
              label: Text(
                genre.label,
                style: TextStyle(
                  fontSize: fontSizeSm,
                  color: isSelected ? colorSurface0 : colorTextSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: colorAccentGold,
              backgroundColor: colorSurface1,
              side: BorderSide(
                color: isSelected ? colorAccentGold : colorBorder,
              ),
              onSelected: (on) {
                ref
                    .read(createPostProvider.notifier)
                    .setArticleGenre(on ? genre : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// External publish toggle for article posts (only when visibility is public).
class _ExternalPublishToggle extends ConsumerWidget {
  const _ExternalPublishToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(
      createPostProvider.select((s) => s.visibility),
    );
    final externalPublish = ref.watch(
      createPostProvider.select((s) => s.externalPublish),
    );

    if (visibility != 'public') return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.publishExternally,
                style: const TextStyle(
                  color: colorTextSecondary,
                  fontSize: fontSizeSm,
                  fontWeight: weightMedium,
                ),
              ),
              const SizedBox(height: spaceXxs),
              Text(
                context.l10n.publishExternallyDescription,
                style: TextStyle(color: colorTextMuted, fontSize: fontSizeXs),
              ),
            ],
          ),
        ),
        Switch(
          value: externalPublish,
          activeThumbColor: colorAccentGold,
          onChanged: (v) =>
              ref.read(createPostProvider.notifier).setExternalPublish(v),
        ),
      ],
    );
  }
}
