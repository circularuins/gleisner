import 'package:flutter/material.dart';

import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// Horizontal avatar rail showing Tuned In artists.
/// ADR 013: scrolls with timeline content (not sticky).
class AvatarRail extends StatelessWidget {
  final List<TunedInArtist> artists;
  final String? selfArtistUsername;
  final String? selectedArtistUsername;
  final ValueChanged<String> onSelectArtist;
  final VoidCallback? onSelectSelf;

  const AvatarRail({
    super.key,
    required this.artists,
    this.selfArtistUsername,
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
              displayName: 'You',
              isSelected: isSelected,
              isSelf: true,
              onTap: onSelectSelf ?? () => onSelectArtist(selfArtistUsername!),
            );
          }

          final artistIndex = selfArtistUsername != null ? index - 1 : index;
          final artist = filteredArtists[artistIndex];
          final isSelected = selectedArtistUsername == artist.artistUsername;

          return _AvatarItem(
            username: artist.artistUsername,
            displayName: artist.displayName ?? artist.artistUsername,
            isSelected: isSelected,
            isSelf: false,
            onTap: () => onSelectArtist(artist.artistUsername),
          );
        },
      ),
    );
  }
}

class _AvatarItem extends StatelessWidget {
  final String username;
  final String displayName;
  final bool isSelected;
  final bool isSelf;
  final VoidCallback onTap;

  const _AvatarItem({
    required this.username,
    required this.displayName,
    required this.isSelected,
    required this.isSelf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rng = DeterministicRng(username);
    final hue = rng.next() * 360;
    final avatarColor = HSLColor.fromAHSL(1, hue, 0.5, 0.3).toColor();
    final ringColor = HSLColor.fromAHSL(1, hue, 0.6, 0.5).toColor();

    // Fixed size — selection indicated by ring color only (no size change = no overflow)
    const double avatarSize = 36;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: spaceXs),
        child: SizedBox(
          width: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor,
                  border: Border.all(
                    color: isSelected ? ringColor : colorBorder,
                    width: isSelected ? 2.5 : 1.5,
                  ),
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
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: colorTextPrimary,
                      fontSize: 14,
                      fontWeight: weightBold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: spaceXxs),
              Text(
                isSelf ? 'You' : _truncate(displayName, 6),
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
