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
    final seedString =
        '${post.title ?? ''}${post.createdAt.toIso8601String()}';

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
              // Media area (seed art)
              Stack(
                children: [
                  SeedArtCanvas(
                    width: MediaQuery.of(context).size.width,
                    height: 220,
                    trackColor: trackColor,
                    seed: seedString,
                  ),
                  // Track tag (top-left)
                  if (post.trackName != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                      ),
                    ),
                  // Media type badge (top-right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151520),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF1a1a28),
                        ),
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
                  ),
                ],
              ),
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
                      style: TextStyle(
                        color: Color(0xFF333350),
                        fontSize: 12,
                      ),
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
                      style: TextStyle(
                        color: Color(0xFF333350),
                        fontSize: 12,
                      ),
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

  String _buildMetaLine() {
    final local = post.createdAt.toLocal();
    final date = formatRelativeDate(local);
    final parts = <String>[date, post.mediaType.name.toUpperCase()];
    return parts.join(' · ');
  }
}
