import 'dart:convert';

import 'package:flutter/material.dart';
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
import '../../utils/constellation_layout.dart';
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
  DateTime? _eventAt;

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
    } else if (widget.post.mediaType == MediaType.text &&
        widget.post.body != null) {
      // Convert plain text to Delta for editing
      _quillController = QuillController(
        document: Document()..insert(0, widget.post.body!),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = QuillController.basic();
    }
    _importance = widget.post.importance;
    _visibility = widget.post.visibility;
    _selectedTrackId = widget.post.trackId;
    _thumbnailUrl = widget.post.thumbnailUrl;
    _eventAt = widget.post.eventAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent clearing media file for non-text types
    if (widget.post.mediaType != MediaType.text &&
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

    // For text type, use Quill Delta; for others, use plain body
    String body;
    String? bodyFormat;
    if (widget.post.mediaType == MediaType.text) {
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
            eventAt: _eventAt?.toIso8601String(),
            clearEventAt: _eventAt == null && widget.post.eventAt != null,
            importance: _importance,
            visibility: _visibility,
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
            eventAt: _eventAt?.toIso8601String(),
            clearEventAt: _eventAt == null && widget.post.eventAt != null,
            importance: _importance,
            visibility: _visibility,
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
                onPressed: _isSubmitting ? null : _save,
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
      case MediaType.text:
        return _buildTextFields();
      case MediaType.image:
      case MediaType.video:
      case MediaType.audio:
        return _buildMediaFields();
      case MediaType.link:
        return _buildLinkFields();
    }
  }

  List<Widget> _buildTextFields() {
    return [
      TextFormField(
        controller: _titleController,
        maxLength: 100,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Title (optional)'),
      ),
      const SizedBox(height: spaceMd),
      SizedBox(
        height: 300,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorBorder),
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radiusSm),
            child: RichTextEditor(
              controller: _quillController,
              placeholder: 'Content',
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildMediaFields() {
    final uploadState = ref.watch(mediaUploadProvider);
    final hasMedia = _mediaUrlController.text.isNotEmpty;
    final mediaType = widget.post.mediaType;
    final isImage = mediaType == MediaType.image;
    final isVideoOrAudio =
        mediaType == MediaType.video || mediaType == MediaType.audio;

    return [
      // Media preview / upload area (first — matches create_post order)
      if (isImage || isVideoOrAudio)
        GestureDetector(
          onTap: uploadState.isUploading ? null : _replaceMedia,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasMedia ? colorAccentGold.withAlpha(128) : colorBorder,
              ),
              borderRadius: BorderRadius.circular(radiusMd),
              color: colorSurface0,
            ),
            child: uploadState.isUploading
                ? const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasMedia
                ? Column(
                    children: [
                      if (isImage ||
                          (mediaType == MediaType.video &&
                              _thumbnailUrl != null &&
                              _thumbnailUrl!.isNotEmpty))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            isImage ? _mediaUrlController.text : _thumbnailUrl!,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: colorTextMuted,
                            ),
                          ),
                        )
                      else
                        Icon(
                          mediaType == MediaType.video
                              ? Icons.videocam
                              : Icons.audiotrack,
                          size: 40,
                          color: colorAccentGold,
                        ),
                      const SizedBox(height: spaceSm),
                      Text(
                        'Tap to replace',
                        style: textCaption.copyWith(color: colorTextMuted),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(
                        isImage
                            ? Icons.photo_library
                            : mediaType == MediaType.video
                            ? Icons.videocam
                            : Icons.audiotrack,
                        size: 40,
                        color: colorTextMuted,
                      ),
                      const SizedBox(height: spaceSm),
                      Text(
                        'Tap to upload',
                        style: textCaption.copyWith(color: colorTextMuted),
                      ),
                    ],
                  ),
          ),
        ),
      if (uploadState.error != null) ...[
        const SizedBox(height: spaceSm),
        Text(
          uploadState.error!,
          style: textCaption.copyWith(color: colorError),
        ),
      ],
      const SizedBox(height: spaceLg),
      // Title
      TextFormField(
        controller: _titleController,
        maxLength: 100,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Title (optional)'),
      ),
      const SizedBox(height: spaceMd),
      // Caption
      TextFormField(
        controller: _bodyController,
        maxLines: 3,
        maxLength: 500,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Caption (optional)'),
      ),
    ];
  }

  Future<void> _replaceMedia() async {
    final result = await ref
        .read(mediaUploadProvider.notifier)
        .pickByMediaType(widget.post.mediaType);
    if (result != null && mounted) {
      setState(() {
        _mediaUrlController.text = result.mediaUrl;
        _thumbnailUrl = result.thumbnailUrl;
      });
    }
  }

  List<Widget> _buildLinkFields() {
    return [
      TextFormField(
        controller: _mediaUrlController,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration(
          'URL',
        ).copyWith(prefixIcon: const Icon(Icons.link, color: colorTextMuted)),
        keyboardType: TextInputType.url,
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
      const SizedBox(height: spaceLg),
      TextFormField(
        controller: _bodyController,
        maxLines: 3,
        maxLength: 500,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Caption (optional)'),
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
