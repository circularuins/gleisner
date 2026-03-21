import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/post.dart';
import '../../models/track.dart' show Track, parseHexColor;
import '../../providers/create_post_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/constellation_layout.dart';
import '../../widgets/common/error_banner.dart';
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

    final postedTrack = await ref
        .read(createPostProvider.notifier)
        .submit(
          title: _titleController.text.isEmpty ? null : _titleController.text,
          body: _bodyController.text.isEmpty ? null : _bodyController.text,
          mediaUrl: _mediaUrlController.text.isEmpty
              ? null
              : _mediaUrlController.text,
        );

    if (postedTrack != null && mounted) {
      // selectTrack ensures the track is in selectedTrackIds,
      // then refresh fetches latest posts for all selected tracks.
      final notifier = ref.read(timelineProvider.notifier);
      notifier.ensureTrackSelected(postedTrack.id);
      await notifier.refresh();
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
const _trackColorPresets = [
  '#f97316', // orange
  '#a78bfa', // purple
  '#22d3ee', // cyan
  '#84cc16', // lime
  '#ef4444', // red
  '#fbbf24', // amber
  '#ec4899', // pink
  '#14b8a6', // teal
  '#8b5cf6', // violet
  '#f43f5e', // rose
];

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
            const SizedBox(height: 24),
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
                  const SizedBox(height: 8),
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
                      const SizedBox(width: 8),
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
            const SizedBox(height: 32),
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
                      const SizedBox(height: 6),
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

// Step 2 — Form & submit
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
    final showMediaUrl = mediaType != MediaType.text;
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
                const SizedBox(width: 8),
                Chip(
                  label: Text(mediaType.name),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
              validator: (value) {
                if (value != null && value.length > 100) {
                  return '100 characters max';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Body
            TextFormField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              maxLength: 10000,
              validator: (value) {
                if (mediaType == MediaType.text &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Body is required for text posts';
                }
                if (value != null && value.length > 10000) {
                  return '10,000 characters max';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Media URL
            if (showMediaUrl) ...[
              TextFormField(
                controller: mediaUrlController,
                decoration: InputDecoration(
                  labelText: '${mediaType.name} URL',
                  border: const OutlineInputBorder(),
                  hintText: 'https://',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    if (mediaType != MediaType.text) {
                      return '${mediaType.name} URL is required';
                    }
                    return null;
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !['http', 'https'].contains(uri.scheme)) {
                    return 'Enter a valid http(s) URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

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
                const SizedBox(height: 8),
                _ImportancePreview(
                  importance: state.importance,
                  trackColor:
                      state.selectedTrack?.displayColor ??
                      theme.colorScheme.primary,
                  title: titleController.text,
                  trackName: state.selectedTrack?.name ?? '',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error
            if (state.error != null) ...[
              ErrorBanner(message: state.error!),
              const SizedBox(height: 16),
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
}

/// Live preview of node size as importance slider changes.
class _ImportancePreview extends StatelessWidget {
  final double importance;
  final Color trackColor;
  final String title;
  final String trackName;

  const _ImportancePreview({
    required this.importance,
    required this.trackColor,
    required this.title,
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
          color: const Color(0xFF0c0c12),
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
                        color: Color(0xFFeeeeee),
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
