import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../graphql/client.dart';
import '../../graphql/queries/artist.dart';
import '../../models/artist.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/pending_artist_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// Simplified Artist Page (ADR 013).
/// Discover → Tap artist card → This screen → [Tune In] → Timeline tab.
/// Placeholder until the full section-based Artist Page is built.
class ArtistPageScreen extends ConsumerStatefulWidget {
  final String username;

  const ArtistPageScreen({super.key, required this.username});

  @override
  ConsumerState<ArtistPageScreen> createState() => _ArtistPageScreenState();
}

class _ArtistPageScreenState extends ConsumerState<ArtistPageScreen> {
  Artist? _artist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtist();
  }

  Future<void> _loadArtist() async {
    final client = ref.read(graphqlClientProvider);
    final result = await client.query(
      QueryOptions(
        document: gql(artistQuery),
        variables: {'username': widget.username},
      ),
    );

    if (!mounted) return;

    final data = result.data?['artist'];
    setState(() {
      _artist =
          data != null ? Artist.fromJson(data as Map<String, dynamic>) : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tuneIn = ref.watch(tuneInProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated =
        authState.status == AuthStatus.authenticated;
    final isTunedIn =
        _artist != null && tuneIn.isTunedIn(_artist!.id);
    // Don't show Tune In for own artist page
    final myArtist = ref.watch(myArtistProvider);
    final isSelf = _artist != null &&
        myArtist != null &&
        _artist!.id == myArtist.id;

    return Scaffold(
      backgroundColor: colorSurface0,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: colorAccentGold))
          : _artist == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Artist not found',
                        style: TextStyle(color: colorTextMuted, fontSize: fontSizeLg),
                      ),
                      const SizedBox(height: spaceLg),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Go back'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Cover + back button
                    SliverAppBar(
                      expandedHeight: 180,
                      pinned: true,
                      backgroundColor: colorSurface0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: colorTextPrimary),
                        onPressed: () => context.pop(),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: CustomPaint(
                          painter: _CoverPainter(seed: _artist!.artistUsername),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(spaceXl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar + name row
                            Row(
                              children: [
                                _GenerativeAvatar(
                                  seed: _artist!.artistUsername,
                                  size: 64,
                                ),
                                const SizedBox(width: spaceLg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _artist!.displayName ??
                                            _artist!.artistUsername,
                                        style: const TextStyle(
                                          color: colorTextPrimary,
                                          fontSize: fontSizeTitle,
                                          fontWeight: weightBold,
                                        ),
                                      ),
                                      Text(
                                        '@${_artist!.artistUsername}',
                                        style: const TextStyle(
                                          color: colorTextMuted,
                                          fontSize: fontSizeMd,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: spaceLg),

                            // Tune In button + count (not shown on own page)
                            if (isAuthenticated && !isSelf)
                              Row(
                                children: [
                                  Expanded(
                                    child: _TuneInButton(
                                      isTunedIn: isTunedIn,
                                      onTap: () async {
                                        final tunedIn = await ref
                                            .read(tuneInProvider.notifier)
                                            .toggleTuneIn(_artist!.id);
                                        if (!context.mounted) return;
                                        if (tunedIn) {
                                          // Set pending artist and navigate to Timeline
                                          ref.read(pendingArtistProvider.notifier).set(
                                              _artist!.artistUsername);
                                          context.go('/timeline');
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),

                            if (!isAuthenticated)
                              Row(
                                children: [
                                  const Icon(Icons.headphones,
                                      size: 14, color: colorTextMuted),
                                  const SizedBox(width: spaceXs),
                                  Text(
                                    '${_artist!.tunedInCount} Tuned In',
                                    style: const TextStyle(
                                      color: colorTextMuted,
                                      fontSize: fontSizeSm,
                                    ),
                                  ),
                                ],
                              ),

                            // Tagline
                            if (_artist!.tagline != null) ...[
                              const SizedBox(height: spaceLg),
                              Text(
                                _artist!.tagline!,
                                style: const TextStyle(
                                  color: colorTextSecondary,
                                  fontSize: fontSizeLg,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                ),
                              ),
                            ],

                            // Bio
                            if (_artist!.bio != null) ...[
                              const SizedBox(height: spaceMd),
                              Text(
                                _artist!.bio!,
                                style: const TextStyle(
                                  color: colorTextSecondary,
                                  fontSize: fontSizeMd,
                                  height: 1.6,
                                ),
                              ),
                            ],

                            // Genres
                            if (_artist!.genres.isNotEmpty) ...[
                              const SizedBox(height: spaceXl),
                              Wrap(
                                spacing: spaceSm,
                                runSpacing: spaceSm,
                                children: _artist!.genres.map((ag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: spaceMd,
                                      vertical: spaceXs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorSurface2,
                                      borderRadius:
                                          BorderRadius.circular(radiusFull),
                                      border:
                                          Border.all(color: colorBorder),
                                    ),
                                    child: Text(
                                      ag.genre.name,
                                      style: const TextStyle(
                                        color: colorTextSecondary,
                                        fontSize: fontSizeSm,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            // Tracks
                            if (_artist!.tracks.isNotEmpty) ...[
                              const SizedBox(height: spaceXl),
                              const Text(
                                'TRACKS',
                                style: TextStyle(
                                  color: colorTextMuted,
                                  fontSize: fontSizeXs,
                                  fontWeight: weightSemibold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: spaceXxs),
                              const Text(
                                "This artist's content streams",
                                style: TextStyle(
                                  color: colorTextMuted,
                                  fontSize: fontSizeXs,
                                ),
                              ),
                              const SizedBox(height: spaceMd),
                              Wrap(
                                spacing: spaceSm,
                                runSpacing: spaceSm,
                                children: _artist!.tracks.map((track) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: spaceMd,
                                      vertical: spaceXs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: track.displayColor
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(radiusFull),
                                      border: Border.all(
                                        color: track.displayColor
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: track.displayColor,
                                          ),
                                        ),
                                        const SizedBox(width: spaceXs),
                                        Text(
                                          track.name,
                                          style: TextStyle(
                                            color: track.displayColor,
                                            fontSize: fontSizeSm,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            // Public timeline link
                            const SizedBox(height: spaceXl),
                            const Divider(color: colorBorder),
                            const SizedBox(height: spaceMd),
                            TextButton.icon(
                              onPressed: () =>
                                  context.push('/@${_artist!.artistUsername}'),
                              icon: const Icon(Icons.grid_view, size: 16),
                              label: const Text('View full timeline'),
                              style: TextButton.styleFrom(
                                foregroundColor: colorInteractive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Tune In Button ──

class _TuneInButton extends StatelessWidget {
  final bool isTunedIn;
  final VoidCallback onTap;

  const _TuneInButton({required this.isTunedIn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: spaceMd),
        decoration: BoxDecoration(
          color: isTunedIn
              ? colorAccentGold.withValues(alpha: 0.15)
              : colorAccentGold,
          borderRadius: BorderRadius.circular(radiusFull),
          border: isTunedIn
              ? Border.all(color: colorAccentGold.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTunedIn ? Icons.check : Icons.headphones,
              size: 16,
              color: isTunedIn ? colorAccentGold : colorSurface0,
            ),
            const SizedBox(width: spaceSm),
            Text(
              isTunedIn ? 'Tuned In' : 'Tune In',
              style: TextStyle(
                color: isTunedIn ? colorAccentGold : colorSurface0,
                fontSize: fontSizeMd,
                fontWeight: weightSemibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generative Cover ──

class _CoverPainter extends CustomPainter {
  final String seed;

  _CoverPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final hue1 = rng.next() * 360;
    final hue2 = hue1 + 30 + rng.next() * 60;
    final color1 = HSLColor.fromAHSL(1, hue1, 0.4, 0.15).toColor();
    final color2 = HSLColor.fromAHSL(1, hue2 % 360, 0.5, 0.12).toColor();

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final x = rng.next() * size.width;
      final y = rng.next() * size.height;
      final r = 15 + rng.next() * 40;
      final hue = (hue1 + rng.next() * 120) % 360;
      paint.color = HSLColor.fromAHSL(0.12, hue, 0.5, 0.4).toColor();
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed;
}

// ── Generative Avatar ──

class _GenerativeAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const _GenerativeAvatar({required this.seed, required this.size});

  @override
  Widget build(BuildContext context) {
    final rng = DeterministicRng(seed);
    final hue = rng.next() * 360;
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.3).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: colorSurface0, width: 3),
      ),
      child: Center(
        child: Text(
          seed.isNotEmpty ? seed[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorTextPrimary,
            fontSize: size * 0.35,
            fontWeight: weightBold,
          ),
        ),
      ),
    );
  }
}
