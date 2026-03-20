import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/post.dart';
import '../../models/track.dart';
import '../../providers/create_post_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../widgets/common/error_banner.dart';

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

    final success = await ref
        .read(createPostProvider.notifier)
        .submit(
          title: _titleController.text.isEmpty ? null : _titleController.text,
          body: _bodyController.text.isEmpty ? null : _bodyController.text,
          mediaUrl: _mediaUrlController.text.isEmpty
              ? null
              : _mediaUrlController.text,
        );

    if (success && mounted) {
      final postedTrack = ref.read(createPostProvider).selectedTrack;
      ref.read(createPostProvider.notifier).reset();
      // Switch timeline to the track we just posted to, then refresh
      if (postedTrack != null) {
        await ref.read(timelineProvider.notifier).selectTrack(postedTrack);
      } else {
        await ref.read(timelineProvider.notifier).refresh();
      }
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

// Step 0 — Track selection
class _TrackStep extends ConsumerWidget {
  final List<Track> tracks;

  const _TrackStep({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No tracks available',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select a track', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tracks.map((track) {
              return ActionChip(
                label: Text(track.name),
                avatar: CircleAvatar(
                  backgroundColor: track.displayColor,
                  radius: 8,
                ),
                side: BorderSide(color: track.displayColor),
                onPressed: () =>
                    ref.read(createPostProvider.notifier).selectTrack(track),
              );
            }).toList(),
          ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content type', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _mediaTypeOptions.map((option) {
              final (type, icon, label) = option;
              return SizedBox(
                width: 80,
                child: Column(
                  children: [
                    IconButton.filledTonal(
                      iconSize: 32,
                      onPressed: () => ref
                          .read(createPostProvider.notifier)
                          .selectMediaType(type),
                      icon: Icon(icon),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: theme.textTheme.labelSmall),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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
                  if (value != null && value.isNotEmpty) {
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasScheme) {
                      return 'Enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Importance slider
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
