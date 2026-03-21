import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../utils/date_format.dart';
import 'seed_art_painter.dart';

/// Show the post detail bottom sheet.
void showPostDetailSheet(BuildContext context, Post post) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostDetailSheet(post: post),
  );
}

class _PostDetailSheet extends StatelessWidget {
  final Post post;

  const _PostDetailSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final trackColor = post.trackDisplayColor;
    final seedString = '${post.title ?? ''}${post.createdAt.toIso8601String()}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0c0c12),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF444460),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Media area — type-specific
              _buildMediaArea(context, post, trackColor, seedString),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.title != null)
                      Text(
                        post.title!,
                        style: const TextStyle(
                          color: Color(0xFFeeeeee),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (post.body != null)
                      Text(
                        post.body!,
                        style: const TextStyle(
                          color: Color(0xFF8888a0),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _buildMetaLine(),
                      style: const TextStyle(
                        color: Color(0xFF555570),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF1a1a28), height: 1),
                    const SizedBox(height: 16),
                    // Reactions placeholder
                    const Text(
                      'Reactions',
                      style: TextStyle(
                        color: Color(0xFF444460),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Coming soon',
                      style: TextStyle(color: Color(0xFF333350), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF1a1a28), height: 1),
                    const SizedBox(height: 16),
                    // Comments placeholder
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Color(0xFF444460),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Coming soon',
                      style: TextStyle(color: Color(0xFF333350), fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaArea(
    BuildContext context,
    Post post,
    Color trackColor,
    String seedString,
  ) {
    final width = MediaQuery.of(context).size.width;

    return switch (post.mediaType) {
      MediaType.text => _textMediaArea(post, trackColor),
      MediaType.image => _visualMediaArea(post, trackColor, seedString, width),
      MediaType.video => _videoMediaArea(post, trackColor, seedString, width),
      MediaType.audio => _audioMediaArea(post, trackColor),
      MediaType.link => _linkMediaArea(post, trackColor),
    };
  }

  // Text: gradient background with body excerpt
  Widget _textMediaArea(Post post, Color trackColor) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            trackColor.withValues(alpha: 0.1),
            const Color(0xFF0c0c12),
            trackColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _trackTag(post, trackColor),
          const Spacer(),
          if (post.body != null)
            Text(
              post.body!,
              style: const TextStyle(
                color: Color(0xFFccccdd),
                fontSize: 16,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // Image/Video shared: seed art + overlays
  Widget _visualMediaArea(
    Post post,
    Color trackColor,
    String seedString,
    double width,
  ) {
    return Stack(
      children: [
        SeedArtCanvas(
          width: width,
          height: 220,
          trackColor: trackColor,
          seed: seedString,
        ),
        _trackTag(post, trackColor, positioned: true),
        _typeBadge(post),
      ],
    );
  }

  Widget _videoMediaArea(
    Post post,
    Color trackColor,
    String seedString,
    double width,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SeedArtCanvas(
          width: width,
          height: 220,
          trackColor: trackColor,
          seed: seedString,
        ),
        // Play button
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        _trackTag(post, trackColor, positioned: true),
        _typeBadge(post),
        // Duration
        if (post.formattedDuration != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                post.formattedDuration!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Audio: wave + play button
  Widget _audioMediaArea(Post post, Color trackColor) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [trackColor.withValues(alpha: 0.08), const Color(0xFF0c0c12)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _trackTag(post, trackColor),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: trackColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: trackColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              if (post.formattedDuration != null)
                Text(
                  post.formattedDuration!,
                  style: TextStyle(
                    color: trackColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Link: icon + URL
  Widget _linkMediaArea(Post post, Color trackColor) {
    final domain = post.mediaUrl != null
        ? Uri.tryParse(post.mediaUrl!)?.host ?? ''
        : '';

    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [trackColor.withValues(alpha: 0.06), const Color(0xFF0c0c12)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _trackTag(post, trackColor),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.link_rounded, size: 20, color: trackColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.mediaUrl ?? '',
                  style: TextStyle(
                    color: trackColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (domain.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 28),
              child: Text(
                domain,
                style: TextStyle(
                  color: trackColor.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Shared: track tag
  Widget _trackTag(Post post, Color trackColor, {bool positioned = false}) {
    final tag = post.trackName != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              post.trackName!.toUpperCase(),
              style: TextStyle(
                color: trackColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (positioned) {
      return Positioned(top: 12, left: 12, child: tag);
    }
    return tag;
  }

  // Shared: media type badge
  Widget _typeBadge(Post post) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF151520),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1a1a28)),
        ),
        child: Text(
          post.mediaType.name.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8888a0),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _buildMetaLine() {
    final local = post.createdAt.toLocal();
    final date = formatRelativeDate(local);
    final parts = <String>[date, post.mediaType.name.toUpperCase()];
    return parts.join(' · ');
  }
}
