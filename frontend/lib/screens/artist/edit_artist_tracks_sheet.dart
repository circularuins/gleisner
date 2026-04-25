import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../models/track.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';

class EditArtistTracksSheet extends ConsumerStatefulWidget {
  final Artist artist;

  const EditArtistTracksSheet({super.key, required this.artist});

  @override
  ConsumerState<EditArtistTracksSheet> createState() =>
      _EditArtistTracksSheetState();
}

class _EditArtistTracksSheetState extends ConsumerState<EditArtistTracksSheet> {
  late List<Track> _tracks;
  bool _showAddForm = false;
  bool _isSubmitting = false;
  String? _error;
  final _nameController = TextEditingController();
  final _addFormKey = GlobalKey<FormState>();
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _tracks = List.from(widget.artist.tracks);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addTrack() async {
    if (!_addFormKey.currentState!.validate()) return;
    if (_tracks.length >= 10) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final color = trackColorPresets[_tracks.length % trackColorPresets.length];

    final ok = await ref
        .read(editArtistProvider.notifier)
        .createTrack(name, color);
    if (!mounted) return;

    if (ok) {
      // Reload to get the new track with server-assigned id
      await ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
      if (!mounted) return;
      final updated = ref.read(artistPageProvider.select((s) => s.artist));
      setState(() {
        _showAddForm = false;
        _isSubmitting = false;
        _nameController.clear();
        if (updated != null) {
          _tracks = List.from(updated.tracks);
        }
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _error = context.l10n.failedCreateTrackRetry;
      });
    }
  }

  Future<void> _deleteTrack(Track track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorSurface1,
        title: Text(
          context.l10n.deleteTrackConfirm(track.name),
          style: const TextStyle(color: colorTextPrimary),
        ),
        content: null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorError),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(editArtistProvider.notifier)
        .deleteTrack(track.id);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _tracks.removeWhere((t) => t.id == track.id);
      });
      await ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
      // Deleted track's posts become unassigned — refresh the count
      ref.read(unassignedPostsProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        _scrollController = scrollController;
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
                  Expanded(
                    child: Text(context.l10n.manageTracks, style: textTitle),
                  ),
                  if (!_showAddForm && _tracks.length < 10)
                    IconButton(
                      icon: const Icon(Icons.add, color: colorAccentGold),
                      onPressed: () {
                        setState(() => _showAddForm = true);
                        // Scroll to bottom after the form is rendered
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollController?.animateTo(
                            _scrollController!.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: spaceXs),
              Text(
                context.l10n.tracksCount(_tracks.length),
                style: textCaption.copyWith(color: colorTextMuted),
              ),
              const SizedBox(height: spaceLg),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(spaceMd),
                  decoration: BoxDecoration(
                    color: colorError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  child: Text(
                    _error!,
                    style: textCaption.copyWith(color: colorError),
                  ),
                ),
                const SizedBox(height: spaceLg),
              ],

              // Existing tracks
              ..._tracks.map(
                (track) => _TrackRow(
                  track: track,
                  onDelete: () => _deleteTrack(track),
                ),
              ),

              if (_tracks.isEmpty && !_showAddForm)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: spaceXl),
                  child: Center(
                    child: Text(
                      context.l10n.noTracksYet,
                      style: textCaption.copyWith(color: colorTextMuted),
                    ),
                  ),
                ),

              // Add form
              if (_showAddForm) ...[
                const SizedBox(height: spaceLg),
                const Divider(color: colorBorder),
                const SizedBox(height: spaceLg),
                Form(
                  key: _addFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.newTrack,
                        style: textHeading.copyWith(color: colorTextPrimary),
                      ),
                      const SizedBox(height: spaceMd),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 30,
                        style: const TextStyle(color: colorTextPrimary),
                        decoration: InputDecoration(
                          labelText: context.l10n.trackName,
                          labelStyle: const TextStyle(color: colorTextMuted),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radiusMd),
                            borderSide: const BorderSide(color: colorBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radiusMd),
                            borderSide: const BorderSide(
                              color: colorAccentGold,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radiusMd),
                            borderSide: const BorderSide(color: colorError),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radiusMd),
                            borderSide: const BorderSide(color: colorError),
                          ),
                          filled: true,
                          fillColor: colorSurface0,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.l10n.trackNameRequired;
                          }
                          if (_tracks.any(
                            (t) =>
                                t.name.toLowerCase() ==
                                value.trim().toLowerCase(),
                          )) {
                            return context.l10n.trackNameAlreadyExists;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: spaceLg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(() => _showAddForm = false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorTextSecondary,
                                side: const BorderSide(color: colorBorder),
                              ),
                              child: Text(context.l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: spaceMd),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _addTrack,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorAccentGold,
                                foregroundColor: colorSurface0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(context.l10n.add),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TrackRow extends StatelessWidget {
  final Track track;
  final VoidCallback onDelete;

  const _TrackRow({required this.track, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spaceSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceSm,
        ),
        decoration: BoxDecoration(
          color: colorSurface0,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: colorBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: track.displayColor,
              ),
            ),
            const SizedBox(width: spaceMd),
            Expanded(
              child: Text(
                track.name,
                style: const TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeMd,
                  fontWeight: weightMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: colorError,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
