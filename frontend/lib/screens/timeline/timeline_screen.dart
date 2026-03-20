import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../graphql/client.dart';
import '../../models/track.dart';
import '../../providers/auth_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../widgets/timeline/post_card.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  void _loadData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      ref.read(timelineProvider.notifier).loadArtist(user.username);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gleisner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              ref.invalidate(graphqlClientProvider);
            },
          ),
        ],
      ),
      floatingActionButton: timeline.artist != null
          ? FloatingActionButton(
              onPressed: () => context.go('/create-post'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          if (timeline.artist != null && timeline.artist!.tracks.isNotEmpty)
            _TrackSelector(
              tracks: timeline.artist!.tracks,
              selectedTrack: timeline.selectedTrack,
              onSelected: (track) =>
                  ref.read(timelineProvider.notifier).selectTrack(track),
            ),
          if (timeline.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                timeline.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          Expanded(
            child: timeline.isLoading && timeline.posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : timeline.posts.isEmpty
                ? Center(
                    child: Text(
                      timeline.artist == null
                          ? 'Register as an artist to get started'
                          : 'No posts yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(timelineProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: timeline.posts.length,
                      itemBuilder: (context, index) {
                        final post = timeline.posts[index];
                        return PostCard(
                          post: post,
                          trackColor:
                              timeline.selectedTrack?.displayColor ??
                              theme.colorScheme.primary,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrackSelector extends StatelessWidget {
  final List<Track> tracks;
  final Track? selectedTrack;
  final ValueChanged<Track> onSelected;

  const _TrackSelector({
    required this.tracks,
    required this.selectedTrack,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isSelected = track.id == selectedTrack?.id;

          return FilterChip(
            label: Text(track.name),
            selected: isSelected,
            onSelected: (_) => onSelected(track),
            selectedColor: track.displayColor.withAlpha(51),
            checkmarkColor: track.displayColor,
            side: BorderSide(
              color: isSelected
                  ? track.displayColor
                  : Theme.of(context).colorScheme.outline,
            ),
          );
        },
      ),
    );
  }
}
