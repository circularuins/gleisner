import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../graphql/client.dart';
import '../../graphql/queries/artist.dart';
import '../../models/artist.dart';
import '../../models/genre.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';

class EditArtistGenresSheet extends ConsumerStatefulWidget {
  final Artist artist;

  const EditArtistGenresSheet({super.key, required this.artist});

  @override
  ConsumerState<EditArtistGenresSheet> createState() =>
      _EditArtistGenresSheetState();
}

class _EditArtistGenresSheetState extends ConsumerState<EditArtistGenresSheet> {
  late List<ArtistGenre> _currentGenres;
  List<Genre> _availableGenres = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentGenres = List.from(widget.artist.genres);
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final client = ref.read(graphqlClientProvider);
    final result = await client.query(QueryOptions(document: gql(genresQuery)));
    if (!mounted) return;

    if (result.data != null) {
      final list = (result.data!['genres'] as List<dynamic>)
          .map((g) => Genre.fromJson(g as Map<String, dynamic>))
          .toList();
      setState(() {
        _availableGenres = list;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addGenre(Genre genre) async {
    if (_currentGenres.length >= 5) return;
    final ok = await ref
        .read(editArtistProvider.notifier)
        .addGenre(genre.id, position: _currentGenres.length);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _currentGenres.add(
          ArtistGenre(position: _currentGenres.length, genre: genre),
        );
      });
      ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
    }
  }

  Future<void> _removeGenre(Genre genre) async {
    final ok = await ref
        .read(editArtistProvider.notifier)
        .removeGenre(genre.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _currentGenres.removeWhere((ag) => ag.genre.id == genre.id);
      });
      ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = _currentGenres.map((ag) => ag.genre.id).toSet();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: colorSurface1,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusSheet),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              spaceXl,
              spaceLg,
              spaceXl,
              spaceXl + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorTextMuted.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: spaceLg),

              Row(
                children: [
                  Expanded(child: Text('Edit Genres', style: textTitle)),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: spaceXs),
              Text(
                '${_currentGenres.length}/5 selected',
                style: textCaption.copyWith(color: colorTextMuted),
              ),
              const SizedBox(height: spaceLg),

              // Current genres
              if (_currentGenres.isNotEmpty) ...[
                Text(
                  'CURRENT',
                  style: TextStyle(
                    color: colorTextMuted,
                    fontSize: fontSizeXs,
                    fontWeight: weightSemibold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: spaceSm),
                Wrap(
                  spacing: spaceSm,
                  runSpacing: spaceSm,
                  children: _currentGenres.map((ag) {
                    return InputChip(
                      label: Text(ag.genre.name),
                      labelStyle: const TextStyle(
                        color: colorAccentGold,
                        fontSize: fontSizeSm,
                      ),
                      backgroundColor: colorAccentGold.withValues(alpha: 0.15),
                      side: BorderSide(
                        color: colorAccentGold.withValues(alpha: 0.4),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      deleteIconColor: colorAccentGold,
                      onDeleted: () => _removeGenre(ag.genre),
                    );
                  }).toList(),
                ),
                const SizedBox(height: spaceXl),
              ],

              // Available genres
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: colorAccentGold),
                )
              else ...[
                const Text(
                  'AVAILABLE',
                  style: TextStyle(
                    color: colorTextMuted,
                    fontSize: fontSizeXs,
                    fontWeight: weightSemibold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: spaceSm),
                Wrap(
                  spacing: spaceSm,
                  runSpacing: spaceSm,
                  children: _availableGenres
                      .where((g) => !selectedIds.contains(g.id))
                      .map((genre) {
                        return ActionChip(
                          label: Text(genre.name),
                          labelStyle: const TextStyle(
                            color: colorTextSecondary,
                            fontSize: fontSizeSm,
                          ),
                          backgroundColor: colorSurface2,
                          side: const BorderSide(color: colorBorder),
                          onPressed: _currentGenres.length >= 5
                              ? null
                              : () => _addGenre(genre),
                        );
                      })
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
