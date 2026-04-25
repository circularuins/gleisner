import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';

import '../../models/artist.dart';
import '../../models/genre.dart';
import '../../providers/discover_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';
import '../../widgets/media/avatar_image.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _initialized = false;
  bool _tuneInsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider.notifier).trackPageView('/discover');
      if (!_initialized && context.mounted) {
        _initialized = true;
        ref.read(discoverProvider.notifier).loadInitial();
        _tryLoadTuneIns();
      }
    });
    // If auth is still loading (e.g. JWT user landing on /discover directly),
    // wait for auth to resolve before loading tune-ins.
    ref.listenManual(authProvider, (prev, next) {
      // Reset on logout so a subsequent login reloads tune-ins.
      if (next.status == AuthStatus.unauthenticated) {
        _tuneInsLoaded = false;
      }
      if (!_tuneInsLoaded && next.status == AuthStatus.authenticated) {
        _tryLoadTuneIns();
      }
    });
  }

  void _tryLoadTuneIns() {
    if (_tuneInsLoaded) return;
    final authStatus = ref.read(authProvider).status;
    if (authStatus == AuthStatus.authenticated) {
      _tuneInsLoaded = true;
      ref.read(tuneInProvider.notifier).loadMyTuneIns();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(discoverProvider.notifier).search(query);
    });
  }

  void _onArtistTap(String username) {
    final authStatus = ref.read(authProvider).status;
    if (authStatus == AuthStatus.authenticated) {
      context.push('/artist/$username');
    } else {
      context.push('/@$username');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: colorSurface0,
      body: RefreshIndicator(
        color: colorAccentGold,
        backgroundColor: colorSurface1,
        onRefresh: () => ref.read(discoverProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // App bar with search
            SliverAppBar(
              backgroundColor: colorSurface0,
              floating: true,
              snap: true,
              title: Text(
                context.l10n.discover,
                style: const TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeTitle,
                  fontWeight: weightBold,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    spaceLg,
                    0,
                    spaceLg,
                    spaceSm,
                  ),
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            ),

            // Genre chips
            if (state.genres.isNotEmpty)
              SliverToBoxAdapter(
                child: _GenreChipRow(
                  genres: state.genres,
                  selected: state.selectedGenre,
                  onSelect: (g) {
                    ref.read(discoverProvider.notifier).selectGenre(g);
                  },
                ),
              ),

            // Loading indicator
            if (state.isLoading && state.artists.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: colorAccentGold),
                ),
              )
            // Error
            else if (state.error != null && state.artists.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: colorTextMuted,
                        size: 40,
                      ),
                      const SizedBox(height: spaceMd),
                      Text(
                        state.error!,
                        style: TextStyle(color: colorTextMuted),
                      ),
                      const SizedBox(height: spaceLg),
                      TextButton(
                        onPressed: () =>
                            ref.read(discoverProvider.notifier).refresh(),
                        child: Text(
                          context.l10n.retry,
                          style: const TextStyle(color: colorAccentGold),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // Empty state
            else if (!state.isLoading && state.artists.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off,
                        color: colorInteractiveMuted,
                        size: 48,
                      ),
                      const SizedBox(height: spaceLg),
                      Text(
                        context.l10n.noArtistsFound,
                        style: const TextStyle(
                          color: colorTextMuted,
                          fontSize: fontSizeLg,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // Artist grid (responsive columns: 2 mobile / 3 tablet / 4 desktop)
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = responsiveGridColumns(
                    constraints.crossAxisExtent,
                  );
                  return SliverPadding(
                    padding: const EdgeInsets.all(spaceLg),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spaceMd,
                        crossAxisSpacing: spaceMd,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final artist = state.artists[index];
                        return _ArtistCard(
                          artist: artist,
                          onTap: () => _onArtistTap(artist.artistUsername),
                        );
                      }, childCount: state.artists.length),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Search Bar ──

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: colorTextPrimary, fontSize: fontSizeMd),
      decoration: InputDecoration(
        hintText: context.l10n.searchArtists,
        hintStyle: const TextStyle(color: colorTextMuted),
        prefixIcon: const Icon(
          Icons.search,
          color: colorInteractiveMuted,
          size: 20,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close,
                  color: colorInteractiveMuted,
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: colorSurface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ── Genre Chip Row ──

class _GenreChipRow extends StatelessWidget {
  final List<Genre> genres;
  final Genre? selected;
  final ValueChanged<Genre> onSelect;

  const _GenreChipRow({
    required this.genres,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceXs,
        ),
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: spaceSm),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = selected?.id == genre.id;
          return GestureDetector(
            onTap: () => onSelect(genre),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: spaceMd,
                vertical: spaceXs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorAccentGold.withValues(alpha: 0.2)
                    : colorSurface2,
                borderRadius: BorderRadius.circular(radiusFull),
                border: Border.all(
                  color: isSelected ? colorAccentGold : colorBorder,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  genre.name,
                  style: TextStyle(
                    color: isSelected ? colorAccentGold : colorTextSecondary,
                    fontSize: fontSizeSm,
                    fontWeight: isSelected ? weightSemibold : weightNormal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Artist Card ──

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final VoidCallback onTap;

  const _ArtistCard({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: colorBorder, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover / generative art area
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  artist.coverImageUrl != null
                      ? Image.network(
                          artist.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => CustomPaint(
                            painter: _ArtistCoverPainter(
                              seed: artist.artistUsername,
                            ),
                          ),
                        )
                      : CustomPaint(
                          painter: _ArtistCoverPainter(
                            seed: artist.artistUsername,
                          ),
                        ),
                  // Gradient overlay for text readability
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorSurface1.withValues(alpha: 0),
                            colorSurface1,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Avatar
                  Positioned(
                    left: spaceSm,
                    bottom: spaceXs,
                    child: AvatarImage(
                      imageUrl: artist.avatarUrl,
                      seed: artist.artistUsername,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            // Info area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(spaceSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.displayName ?? artist.artistUsername,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: colorTextPrimary,
                        fontSize: fontSizeMd,
                        fontWeight: weightSemibold,
                      ),
                    ),
                    const SizedBox(height: spaceXxs),
                    if (artist.tagline != null) ...[
                      Text(
                        artist.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: colorTextMuted,
                          fontSize: fontSizeXs,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    // Genre chips + tune in count
                    Row(
                      children: [
                        if (artist.genres.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: spaceXs,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorSurface2,
                              borderRadius: BorderRadius.circular(radiusSm),
                            ),
                            child: Text(
                              artist.genres.first.genre.name,
                              style: const TextStyle(
                                color: colorTextMuted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        const Spacer(),
                        const Icon(
                          Icons.headphones,
                          size: 11,
                          color: colorInteractiveMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatCount(artist.tunedInCount),
                          style: const TextStyle(
                            color: colorInteractiveMuted,
                            fontSize: fontSizeXs,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}

// ── Generative Cover Art for Artist Cards ──

class _ArtistCoverPainter extends CustomPainter {
  final String seed;

  _ArtistCoverPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);

    // Background gradient
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

    // Abstract shapes
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final x = rng.next() * size.width;
      final y = rng.next() * size.height;
      final r = 10 + rng.next() * 30;
      final hue = (hue1 + rng.next() * 120) % 360;
      paint.color = HSLColor.fromAHSL(0.15, hue, 0.5, 0.4).toColor();
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ArtistCoverPainter old) => old.seed != seed;
}
