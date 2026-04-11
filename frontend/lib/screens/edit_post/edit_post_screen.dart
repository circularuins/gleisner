import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/post.dart';
import '../../models/track.dart';
import '../../providers/media_upload_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/common/event_at_picker.dart';
import '../../widgets/editor/rich_text_editor.dart';
import '../../widgets/editor/text_body_counter.dart';
import '../../utils/constellation_layout.dart';
import '../../utils/ime_safe_focus.dart';
import '../../widgets/timeline/seed_art_painter.dart';

class EditPostScreen extends ConsumerStatefulWidget {
  final Post post;

  /// Optional tracks override. When provided, these are used instead of
  /// the timeline provider's tracks (e.g., when editing unassigned posts
  /// from the Profile screen where timeline may hold another artist's data).
  final List<Track>? tracks;

  /// Called after a successful save. Use to update external state
  /// (e.g., removing the post from the unassigned posts list).
  final void Function(Post updatedPost)? onSaved;

  const EditPostScreen({
    super.key,
    required this.post,
    this.tracks,
    this.onSaved,
  });

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _mediaUrlController;
  late final QuillController _quillController;
  late double _importance;
  late String _visibility;
  late String? _selectedTrackId;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;
  String? _thumbnailUrl;
  int? _durationSeconds;
  DateTime? _eventAt;
  ArticleGenre? _articleGenre;
  late bool _externalPublish;
  // IME-safe FocusNodes — block Tab during composition
  late final FocusNode _titleFocusNode;
  late final FocusNode _bodyFocusNode;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title ?? '');
    _bodyController = TextEditingController(text: widget.post.body ?? '');
    _mediaUrlController = TextEditingController(
      text: widget.post.mediaUrl ?? '',
    );
    // Initialize Quill controller from existing content
    if (widget.post.bodyFormat == BodyFormat.delta &&
        widget.post.bodyDelta != null) {
      _quillController = QuillController(
        document: Document.fromJson(widget.post.bodyDelta!),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else if (widget.post.mediaType == MediaType.article &&
        widget.post.body != null) {
      // Convert plain text to Delta for editing
      _quillController = QuillController(
        document: Document()..insert(0, widget.post.body!),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = QuillController.basic();
    }
    _titleFocusNode = createImeSafeFocusNode(_titleController);
    _bodyFocusNode = createImeSafeFocusNode(_bodyController);
    _urlFocusNode = createImeSafeFocusNode(_mediaUrlController);
    _importance = widget.post.importance;
    _visibility = widget.post.visibility;
    _selectedTrackId = widget.post.trackId;
    _thumbnailUrl = widget.post.thumbnailUrl;
    _durationSeconds = widget.post.duration;
    _eventAt = widget.post.eventAt;
    _articleGenre = widget.post.articleGenre;
    _externalPublish = widget.post.externalPublish;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    _quillController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent clearing media file for media types (not thought/article/link)
    if (widget.post.mediaType != MediaType.article &&
        widget.post.mediaType != MediaType.thought &&
        _mediaUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media file is required for this post type'),
          backgroundColor: colorError,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final title = _titleController.text.trim();
    final mediaUrl = _mediaUrlController.text.trim();

    // Article: use Quill Delta; Thought + others: use plain body
    String body;
    String? bodyFormat;
    if (widget.post.mediaType == MediaType.article) {
      final delta = _quillController.document.toDelta().toJson();
      body = jsonEncode(delta);
      bodyFormat = 'delta';
    } else {
      body = _bodyController.text.trim();
    }

    // Timeline posts use the timeline notifier (with optimistic updates).
    // Unassigned posts use the dedicated notifier.
    final inTimeline = ref
        .read(timelineProvider)
        .posts
        .any((p) => p.id == widget.post.id);

    // Send all text fields including empty strings.
    // Empty string = clear the field (backend stores null).
    // This allows users to remove title/body after initial save.
    Post? updated;
    if (inTimeline) {
      updated = await ref
          .read(timelineProvider.notifier)
          .updatePost(
            id: widget.post.id,
            trackId: _selectedTrackId,
            title: title,
            body: body,
            bodyFormat: bodyFormat,
            mediaUrl: mediaUrl.isNotEmpty ? mediaUrl : null,
            thumbnailUrl: _thumbnailUrl,
            clearThumbnail:
                _thumbnailUrl == null && widget.post.thumbnailUrl != null,
            duration: _durationSeconds,
            clearDuration:
                _durationSeconds == null && widget.post.duration != null,
            eventAt: _eventAt?.toIso8601String(),
            clearEventAt: _eventAt == null && widget.post.eventAt != null,
            importance: _importance,
            visibility: _visibility,
            articleGenre: _articleGenre?.name,
            clearArticleGenre:
                _articleGenre == null && widget.post.articleGenre != null,
            externalPublish: _externalPublish,
          );
    } else {
      updated = await ref
          .read(unassignedPostsProvider.notifier)
          .updatePost(
            id: widget.post.id,
            trackId: _selectedTrackId,
            title: title,
            body: body,
            bodyFormat: bodyFormat,
            mediaUrl: mediaUrl.isNotEmpty ? mediaUrl : null,
            thumbnailUrl: _thumbnailUrl,
            clearThumbnail:
                _thumbnailUrl == null && widget.post.thumbnailUrl != null,
            duration: _durationSeconds,
            clearDuration:
                _durationSeconds == null && widget.post.duration != null,
            eventAt: _eventAt?.toIso8601String(),
            clearEventAt: _eventAt == null && widget.post.eventAt != null,
            importance: _importance,
            visibility: _visibility,
            articleGenre: _articleGenre?.name,
            clearArticleGenre:
                _articleGenre == null && widget.post.articleGenre != null,
            externalPublish: _externalPublish,
          );
    }

    if (!mounted) return;

    if (updated != null) {
      widget.onSaved?.call(updated);
      context.pop();
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to update post. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final List<Track> allTracks =
        widget.tracks ??
        ref.watch(
          timelineProvider.select((s) => s.artist?.tracks ?? <Track>[]),
        );
    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text(
          'Edit Post',
          style: TextStyle(color: colorTextPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: colorTextPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spaceXl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Track selector + MediaType indicator
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: spaceSm,
                      runSpacing: spaceSm,
                      children: allTracks.map((track) {
                        final isSelected = track.id == _selectedTrackId;
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: track.displayColor,
                            radius: 6,
                          ),
                          label: Text(track.name),
                          selected: isSelected,
                          selectedColor: track.displayColor.withValues(
                            alpha: 0.2,
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _selectedTrackId = track.id),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(post.mediaType.name),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: spaceLg),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(spaceMd),
                  decoration: BoxDecoration(
                    color: colorError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  child: Text(
                    _error!,
                    style: textCaption.copyWith(color: colorError),
                  ),
                ),
                const SizedBox(height: spaceLg),
              ],

              // Visibility toggle (first — matches create_post order)
              Row(
                children: [
                  Text(
                    'Visibility',
                    style: textLabel.copyWith(color: colorTextSecondary),
                  ),
                  const SizedBox(width: spaceLg),
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: _visibility == 'public',
                    onSelected: (_) => setState(() => _visibility = 'public'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: spaceSm),
                  ChoiceChip(
                    label: const Text('Draft'),
                    selected: _visibility == 'draft',
                    onSelected: (_) => setState(() => _visibility = 'draft'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: spaceLg),

              // Content fields based on media type
              ..._buildContentFields(),

              // Event date
              const SizedBox(height: spaceLg),
              EventAtPicker(
                eventAt: _eventAt,
                onChanged: (dt) => setState(() => _eventAt = dt),
              ),

              // Importance slider
              const SizedBox(height: spaceLg),
              Text(
                'Importance',
                style: textLabel.copyWith(color: colorTextSecondary),
              ),
              Row(
                children: [
                  Text(
                    'quiet note',
                    style: textMicro.copyWith(color: colorTextMuted),
                  ),
                  Expanded(
                    child: Slider(
                      value: _importance,
                      onChanged: (v) => setState(() => _importance = v),
                      activeColor: colorAccentGold,
                    ),
                  ),
                  Text(
                    'hero moment',
                    style: textMicro.copyWith(color: colorTextMuted),
                  ),
                ],
              ),

              const SizedBox(height: spaceSm),
              _ImportancePreview(
                importance: _importance,
                mediaType: widget.post.mediaType,
                trackColor:
                    allTracks
                        .where((t) => t.id == _selectedTrackId)
                        .firstOrNull
                        ?.displayColor ??
                    colorAccentGold,
              ),
              const SizedBox(height: spaceXl),

              // Save button
              FilledButton(
                onPressed:
                    _isSubmitting || ref.watch(mediaUploadProvider).isUploading
                    ? null
                    : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colorAccentGold,
                  foregroundColor: colorSurface0,
                  padding: const EdgeInsets.symmetric(vertical: spaceMd),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentFields() {
    switch (widget.post.mediaType) {
      case MediaType.thought:
        return _buildThoughtFields();
      case MediaType.article:
        return _buildTextFields();
      case MediaType.image:
      case MediaType.video:
      case MediaType.audio:
        return _buildMediaFields();
      case MediaType.link:
        return _buildLinkFields();
    }
  }

  List<Widget> _buildThoughtFields() {
    return [
      Container(
        decoration: BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: colorBorder),
        ),
        child: TextField(
          controller: _bodyController,
          maxLines: 6,
          maxLength: 280,
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeMd,
            height: 1.5,
          ),
          decoration: const InputDecoration(
            hintText: "What's on your mind?",
            hintStyle: TextStyle(color: colorInteractiveMuted),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(spaceLg),
            counterStyle: TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeXs,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildTextFields() {
    return [
      Container(
        decoration: const BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusMd)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spaceLg),
        child: TextFormField(
          controller: _titleController,
          maxLength: 100,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeLg,
            fontWeight: weightMedium,
          ),
          decoration: InputDecoration(
            hintText: 'Title',
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
        ),
      ),
      const Divider(color: colorBorder, height: 1),
      SizedBox(
        height: 400,
        child: RichTextEditor(
          controller: _quillController,
          placeholder: "What's on your mind?",
          toolbarCollapsed: true,
        ),
      ),
      TextBodyCounter(controller: _quillController),
      const SizedBox(height: spaceMd),
      // Article genre picker
      _buildArticleGenrePicker(),
      const SizedBox(height: spaceMd),
      // External publish toggle
      _buildExternalPublishToggle(),
    ];
  }

  Widget _buildArticleGenrePicker() {
    const genreLabels = {
      ArticleGenre.fiction: 'Fiction',
      ArticleGenre.poetry: 'Poetry',
      ArticleGenre.essay: 'Essay',
      ArticleGenre.technical: 'Technical',
      ArticleGenre.opinion: 'Opinion',
      ArticleGenre.diary: 'Diary',
      ArticleGenre.review: 'Review',
      ArticleGenre.travel: 'Travel',
      ArticleGenre.other: 'Other',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genre',
          style: TextStyle(
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
            final isSelected = genre == _articleGenre;
            return ChoiceChip(
              label: Text(
                genreLabels[genre] ?? genre.name,
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
                setState(() => _articleGenre = on ? genre : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExternalPublishToggle() {
    if (_visibility != 'public') return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Publish externally',
                style: TextStyle(
                  color: colorTextSecondary,
                  fontSize: fontSizeSm,
                  fontWeight: weightMedium,
                ),
              ),
              SizedBox(height: spaceXxs),
              Text(
                'Make available on the public article site',
                style: TextStyle(color: colorTextMuted, fontSize: fontSizeXs),
              ),
            ],
          ),
        ),
        Switch(
          value: _externalPublish,
          activeColor: colorAccentGold,
          onChanged: (v) => setState(() => _externalPublish = v),
        ),
      ],
    );
  }

  List<Widget> _buildMediaFields() {
    final uploadState = ref.watch(mediaUploadProvider);
    final hasMedia = _mediaUrlController.text.isNotEmpty;
    final mediaType = widget.post.mediaType;
    final isImage = mediaType == MediaType.image;
    final isVideoOrAudio =
        mediaType == MediaType.video || mediaType == MediaType.audio;

    final emptyIcon = switch (mediaType) {
      MediaType.image => Icons.add_photo_alternate_outlined,
      MediaType.video => Icons.videocam_outlined,
      MediaType.audio => Icons.audiotrack_outlined,
      _ => Icons.attach_file,
    };

    return [
      // Media preview / upload area (first — matches create_post order)
      if (isImage || isVideoOrAudio)
        GestureDetector(
          onTap: uploadState.isUploading ? null : _replaceMedia,
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
              ? _buildMediaPreview(mediaType)
              : Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: colorSurface2,
                    borderRadius: BorderRadius.circular(radiusLg),
                  ),
                  child: Center(
                    child: Icon(
                      emptyIcon,
                      size: 48,
                      color: colorTextMuted.withValues(alpha: 0.4),
                    ),
                  ),
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
          controller: _titleController,
          focusNode: _titleFocusNode,
          maxLength: 100,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeLg,
            fontWeight: weightMedium,
          ),
          decoration: InputDecoration(
            hintText: 'Title',
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
          controller: _bodyController,
          focusNode: _bodyFocusNode,
          maxLines: 4,
          minLines: 2,
          maxLength: 500,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: const TextStyle(
            color: colorTextSecondary,
            fontSize: fontSizeMd,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: 'Write a caption...',
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

  Widget _buildMediaPreview(MediaType mediaType) {
    // Audio: dedicated preview card
    if (mediaType == MediaType.audio) {
      return _buildAudioPreview();
    }

    final isImage = mediaType == MediaType.image;
    final showThumbnail =
        isImage ||
        (mediaType == MediaType.video &&
            _thumbnailUrl != null &&
            _thumbnailUrl!.isNotEmpty);
    final displayUrl = isImage
        ? _mediaUrlController.text
        : (_thumbnailUrl ?? '');

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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                SizedBox(width: spaceXs),
                Text(
                  'Replace',
                  style: TextStyle(color: Colors.white70, fontSize: fontSizeXs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPreview() {
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
                child: const Icon(
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
                    const Text(
                      'Audio uploaded',
                      style: TextStyle(
                        color: colorTextPrimary,
                        fontSize: fontSizeSm,
                        fontWeight: weightMedium,
                      ),
                    ),
                    if (_durationSeconds != null) ...[
                      const SizedBox(height: spaceXs),
                      Text(
                        _formatDuration(_durationSeconds!),
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                SizedBox(width: spaceXs),
                Text(
                  'Replace',
                  style: TextStyle(color: Colors.white70, fontSize: fontSizeXs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _replaceMedia() async {
    final result = await ref
        .read(mediaUploadProvider.notifier)
        .pickByMediaType(widget.post.mediaType);
    if (result != null && mounted) {
      setState(() {
        _mediaUrlController.text = result.mediaUrl;
        _thumbnailUrl = result.thumbnailUrl;
        // Use new duration if extracted, otherwise keep existing value.
        // This prevents extraction failure from clearing a valid duration.
        if (result.durationSeconds != null) {
          _durationSeconds = result.durationSeconds;
        }
      });
    }
  }

  List<Widget> _buildLinkFields() {
    return [
      FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          children: [
            // URL field
            Container(
              decoration: BoxDecoration(
                color: colorSurface1,
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              padding: const EdgeInsets.symmetric(horizontal: spaceMd),
              child: TextFormField(
                controller: _mediaUrlController,
                focusNode: _urlFocusNode,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeMd,
                  fontFamily: monoFontFamily,
                ),
                decoration: InputDecoration(
                  hintText: 'https://',
                  hintStyle: TextStyle(
                    color: colorTextMuted.withValues(alpha: 0.4),
                    fontSize: fontSizeMd,
                    fontFamily: monoFontFamily,
                  ),
                  icon: const Icon(
                    Icons.link_rounded,
                    color: colorTextMuted,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: spaceMd),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'URL is required';
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !['http', 'https'].contains(uri.scheme)) {
                    return 'Enter a valid http(s) URL';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: spaceSm),
            // Title
            Container(
              decoration: BoxDecoration(
                color: colorSurface1,
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              padding: const EdgeInsets.symmetric(horizontal: spaceMd),
              child: TextFormField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                style: const TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeLg,
                  fontWeight: weightMedium,
                ),
                decoration: InputDecoration(
                  hintText: 'Title (auto-filled from link if empty)',
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
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                textInputAction: TextInputAction.done,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                style: const TextStyle(
                  color: colorTextSecondary,
                  fontSize: fontSizeMd,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
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
              ),
            ),
          ],
        ),
      ),
    ];
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: colorTextMuted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: colorBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: colorAccentGold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: colorError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: colorError),
      ),
      filled: true,
      fillColor: colorSurface1,
    );
  }
}

class _ImportancePreview extends StatelessWidget {
  final double importance;
  final MediaType mediaType;
  final Color trackColor;

  const _ImportancePreview({
    required this.importance,
    required this.mediaType,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final sz = ConstellationLayout.nodeSize(importance);
    final mediaH = sz > 110 ? sz * 0.7 : sz * 0.85;
    final w = sz > 110 ? sz * 1.25 : sz;
    final glowOpacity = 0.15 + importance * 0.25;
    final glowBlur = 8.0 + importance * 16;

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
        child: SeedArtCanvas(
          width: w,
          height: mediaH,
          trackColor: trackColor,
          seed: 'preview',
          mediaType: mediaType,
        ),
      ),
    );
  }
}
