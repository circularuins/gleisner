import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// Horizontal avatar rail showing Tuned In artists.
/// ADR 013: scrolls with timeline content (not sticky).
class AvatarRail extends StatelessWidget {
  final List<TunedInArtist> artists;
  final String? selfArtistUsername;
  final String? selfAvatarUrl;
  final bool selfIsPrivate;
  final String? selectedArtistUsername;
  final ValueChanged<String> onSelectArtist;
  final VoidCallback? onSelectSelf;

  const AvatarRail({
    super.key,
    required this.artists,
    this.selfArtistUsername,
    this.selfAvatarUrl,
    this.selfIsPrivate = false,
    this.selectedArtistUsername,
    required this.onSelectArtist,
    this.onSelectSelf,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out self from tuned-in list to prevent duplicate display
    final filteredArtists = selfArtistUsername != null
        ? artists.where((a) => a.artistUsername != selfArtistUsername).toList()
        : artists;

    if (filteredArtists.isEmpty && selfArtistUsername == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceXs,
        ),
        itemCount:
            (selfArtistUsername != null ? 1 : 0) + filteredArtists.length,
        itemBuilder: (context, index) {
          // Self avatar first
          if (selfArtistUsername != null && index == 0) {
            final isSelected = selectedArtistUsername == selfArtistUsername;
            return _AvatarItem(
              username: selfArtistUsername!,
              avatarUrl: selfAvatarUrl,
              displayName: context.l10n.you,
              isSelected: isSelected,
              isSelf: true,
              isPrivate: selfIsPrivate,
              onTap: onSelectSelf ?? () => onSelectArtist(selfArtistUsername!),
            );
          }

          final artistIndex = selfArtistUsername != null ? index - 1 : index;
          final artist = filteredArtists[artistIndex];
          final isSelected = selectedArtistUsername == artist.artistUsername;

          return _AvatarItem(
            username: artist.artistUsername,
            avatarUrl: artist.avatarUrl,
            displayName: artist.displayName ?? artist.artistUsername,
            isSelected: isSelected,
            isSelf: false,
            isPrivate: artist.isPrivate,
            onTap: () => onSelectArtist(artist.artistUsername),
          );
        },
      ),
    );
  }
}

class _AvatarItem extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final String displayName;
  final bool isSelected;
  final bool isSelf;
  final bool isPrivate;
  final VoidCallback onTap;

  const _AvatarItem({
    required this.username,
    this.avatarUrl,
    required this.displayName,
    required this.isSelected,
    required this.isSelf,
    this.isPrivate = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rng = DeterministicRng(username);
    final hue = rng.next() * 360;
    final avatarColor = HSLColor.fromAHSL(1, hue, 0.5, 0.3).toColor();
    final ringColor = HSLColor.fromAHSL(1, hue, 0.6, 0.5).toColor();

    const double avatarSize = 36;
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: spaceXs),
        child: SizedBox(
          width: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: ringColor, width: 2.5)
                            : hasImage
                            ? null
                            : Border.all(color: colorBorder, width: 1.5),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: ringColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipOval(
                        child: hasImage
                            ? Image.network(
                                avatarUrl!,
                                width: avatarSize,
                                height: avatarSize,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _InitialFallback(
                                  username: username,
                                  avatarColor: avatarColor,
                                ),
                              )
                            : _InitialFallback(
                                username: username,
                                avatarColor: avatarColor,
                              ),
                      ),
                    ),
                    if (isPrivate)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorSurface0,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorBorder, width: 1),
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 8,
                            color: colorTextMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: spaceXxs),
              Text(
                isSelf ? context.l10n.you : _truncate(displayName, 6),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? colorTextPrimary : colorTextMuted,
                  fontSize: 9,
                  fontWeight: isSelected ? weightSemibold : weightNormal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}

class _InitialFallback extends StatelessWidget {
  final String username;
  final Color avatarColor;

  const _InitialFallback({required this.username, required this.avatarColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: avatarColor,
      alignment: Alignment.center,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: const TextStyle(
          color: colorTextPrimary,
          fontSize: 14,
          fontWeight: weightBold,
        ),
      ),
    );
  }
}
