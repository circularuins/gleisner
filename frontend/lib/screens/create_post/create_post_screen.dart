import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/post.dart';
import '../../models/track.dart' show Track, parseHexColor;
import '../../providers/create_post_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/constellation_layout.dart';
import '../../widgets/common/connection_type_picker.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/related_post_picker.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/timeline/seed_art_painter.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await ref
        .read(createPostProvider.notifier)
        .submit(
          title: _titleController.text.isNotEmpty
              ? _titleController.text
              : null,
          body: _bodyController.text.isEmpty ? null : _bodyController.text,
          mediaUrl: _mediaUrlController.text.isEmpty
              ? null
              : _mediaUrlController.text,
        );

    if (result != null && mounted) {
      final (postedTrack, post) = result;
      final notifier = ref.read(timelineProvider.notifier);
      notifier.ensureTrackSelected(postedTrack.id);
      notifier.addPost(post);
      if (mounted) context.go('/timeline');
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
              ref.read(createPostProvider.notifier).goBack();
            } else {
              ref.read(createPostProvider.notifier).reset();
              context.go('/timeline');
            }
          },
        ),
        title: const Text('New Post'),
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
              mediaUrlController: _mediaUrlController,
              onSubmit: _submit,
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
            Text('Select a track', style: theme.textTheme.headlineSmall),
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
                    label: const Text(
                      '+ New Track',
                      style: TextStyle(fontSize: 16),
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
                  'Maximum $_maxTracks tracks',
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
            setDialogState(() => errorText = 'Track name is required');
            return;
          }
          if (tracks.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
            setDialogState(() => errorText = 'Track "$name" already exists');
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
                errorText = error ?? 'Failed to create track';
              });
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Track'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Track name',
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
                        'Color: auto-assigned',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isCreating ? null : () => submit(setDialogState),
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
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

  static const _mediaTypeOptions = [
    (MediaType.text, Icons.article, 'Text'),
    (MediaType.image, Icons.image, 'Image'),
    (MediaType.video, Icons.videocam, 'Video'),
    (MediaType.audio, Icons.audiotrack, 'Audio'),
    (MediaType.link, Icons.link, 'Link'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Content type', style: theme.textTheme.headlineSmall),
            const SizedBox(height: spaceXxl),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _mediaTypeOptions.map((option) {
                final (type, icon, label) = option;
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
                      Text(label, style: theme.textTheme.labelMedium),
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
  final TextEditingController mediaUrlController;
  final VoidCallback onSubmit;

  const _FormStep({
    required this.formKey,
    required this.titleController,
    required this.bodyController,
    required this.mediaUrlController,
    required this.onSubmit,
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
            // Track + MediaType indicator
            Row(
              children: [
                if (state.selectedTrack != null)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: state.selectedTrack!.displayColor,
                      radius: 6,
                    ),
                    label: Text(state.selectedTrack!.name),
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: spaceSm),
                Chip(
                  label: Text(mediaType.name),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: spaceLg),

            // Media-type-specific fields
            ..._buildContentFields(mediaType, theme),

            // Importance slider + node preview
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Importance', style: theme.textTheme.titleSmall),
                Row(
                  children: [
                    Text(
                      'quiet note',
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
                      'hero moment',
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

            // Visibility toggle
            Row(
              children: [
                Text('Visibility', style: theme.textTheme.titleSmall),
                const SizedBox(width: spaceLg),
                ChoiceChip(
                  label: const Text('Public'),
                  selected: state.visibility == 'public',
                  onSelected: (_) => ref
                      .read(createPostProvider.notifier)
                      .setVisibility('public'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: spaceSm),
                ChoiceChip(
                  label: const Text('Draft'),
                  selected: state.visibility == 'draft',
                  onSelected: (_) => ref
                      .read(createPostProvider.notifier)
                      .setVisibility('draft'),
                  visualDensity: VisualDensity.compact,
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
            FilledButton(
              onPressed: state.isSubmitting ? null : onSubmit,
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
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

  List<Widget> _buildContentFields(MediaType mediaType, ThemeData theme) {
    switch (mediaType) {
      case MediaType.text:
        return _buildTextFields(theme);
      case MediaType.image:
      case MediaType.video:
      case MediaType.audio:
        return _buildMediaFields(mediaType, theme);
      case MediaType.link:
        return _buildLinkFields(theme);
    }
  }

  // text: body (main) + title (optional, small)
  List<Widget> _buildTextFields(ThemeData theme) {
    return [
      TextFormField(
        controller: titleController,
        decoration: InputDecoration(
          labelText: 'Title (optional)',
          border: const OutlineInputBorder(),
          labelStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
        ),
        maxLength: 100,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: spaceMd),
      TextFormField(
        controller: bodyController,
        decoration: const InputDecoration(
          hintText: 'Write something...',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        minLines: 8,
        maxLines: null,
        maxLength: 10000,
        autofocus: true,
        style: theme.textTheme.bodyLarge,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Text is required';
          }
          return null;
        },
      ),
      const SizedBox(height: spaceLg),
    ];
  }

  // image/video/audio: caption + upload placeholder
  List<Widget> _buildMediaFields(MediaType mediaType, ThemeData theme) {
    final (icon, label) = switch (mediaType) {
      MediaType.image => (Icons.photo_library, 'Image'),
      MediaType.video => (Icons.videocam, 'Video'),
      MediaType.audio => (Icons.audiotrack, 'Audio'),
      _ => (Icons.attach_file, 'Media'),
    };

    return [
      // Title (optional)
      TextFormField(
        controller: titleController,
        decoration: InputDecoration(
          labelText: 'Title (optional)',
          border: const OutlineInputBorder(),
          labelStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
        ),
        maxLength: 100,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: spaceMd),
      // Upload placeholder
      Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(80),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
            const SizedBox(height: spaceSm),
            Text(
              '$label upload coming soon',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: spaceLg),
      // Caption
      TextFormField(
        controller: bodyController,
        decoration: const InputDecoration(
          labelText: 'Caption (optional)',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: 3,
        maxLength: 500,
      ),
      const SizedBox(height: spaceLg),
    ];
  }

  // link: URL (required) + caption
  List<Widget> _buildLinkFields(ThemeData theme) {
    return [
      TextFormField(
        controller: mediaUrlController,
        decoration: const InputDecoration(
          labelText: 'URL',
          border: OutlineInputBorder(),
          hintText: 'https://',
          prefixIcon: Icon(Icons.link),
        ),
        keyboardType: TextInputType.url,
        autofocus: true,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'URL is required';
          }
          final uri = Uri.tryParse(value);
          if (uri == null || !['http', 'https'].contains(uri.scheme)) {
            return 'Enter a valid http(s) URL';
          }
          return null;
        },
      ),
      const SizedBox(height: spaceLg),
      TextFormField(
        controller: bodyController,
        decoration: const InputDecoration(
          labelText: 'Caption (optional)',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: 3,
        maxLength: 500,
      ),
      const SizedBox(height: spaceLg),
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
        Text('Connections', style: theme.textTheme.titleSmall),
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
                '${c.connectionType.label} · ${post.trackName ?? ''}',
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
                  ? 'Link to existing post'
                  : 'Add another connection',
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
