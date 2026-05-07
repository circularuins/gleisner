import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../models/track.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/common/track_color_picker.dart';

class EditArtistTracksSheet extends ConsumerStatefulWidget {
  final Artist artist;

  /// Defense-in-depth flag: even though the sheet is only opened from
  /// `artist_page_screen` when `isSelf == true`, mutation UI (Add,
  /// edit, delete) is also gated on this so future call sites that
  /// forget the outer check cannot accidentally surface the buttons.
  /// The backend ownership check in `updateTrack` / `deleteTrack` is
  /// the final defense, but rendering disabled buttons would still
  /// expose a confusing UX. See PR #346 review S2.
  final bool isOwner;

  const EditArtistTracksSheet({
    super.key,
    required this.artist,
    this.isOwner = false,
  });

  @override
  ConsumerState<EditArtistTracksSheet> createState() =>
      _EditArtistTracksSheetState();
}

class _EditArtistTracksSheetState extends ConsumerState<EditArtistTracksSheet> {
  late List<Track> _tracks;
  bool _showAddForm = false;
  bool _isSubmitting = false;
  String? _error;
  String _selectedColor = trackColorPresets[0];
  final _nameController = TextEditingController();
  final _addFormKey = GlobalKey<FormState>();
  late final FocusNode _nameFocusNode;

  /// True while a focus-driven scroll-to-bottom is in flight. Set when an
  /// animateTo is queued, cleared inside `whenComplete` once the animation
  /// finishes (or via the early-out paths). Guards against concurrent
  /// animateTo calls when focus events fire repeatedly during the keyboard
  /// slide-in animation, and prevents reuse of a stale post-frame callback
  /// after dispose.
  bool _focusScrollPending = false;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _tracks = List.from(widget.artist.tracks);
    _nameFocusNode = FocusNode()
      // Keep the input visible above the soft keyboard. Inside a
      // DraggableScrollableSheet, Flutter's default focus auto-scroll is
      // unreliable: the initial scroll-to-bottom runs before the keyboard
      // appears, so the form ends up hidden behind the IME on the first
      // focus. Re-running animateTo on focus uses the post-keyboard
      // maxScrollExtent and reveals the field.
      ..addListener(_handleNameFocusChanged);
  }

  @override
  void dispose() {
    _nameFocusNode
      ..removeListener(_handleNameFocusChanged)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameFocusChanged() {
    if (!_nameFocusNode.hasFocus || !_showAddForm) return;
    // Guard against re-entrancy: focus events can fire several times in
    // quick succession while the soft keyboard animates in, and we only
    // need a single animateTo per burst. Without this, multiple concurrent
    // animateTo calls compete inside the DraggableScrollableSheet.
    if (_focusScrollPending) return;
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    _focusScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        // Widget was disposed before the post-frame callback ran. Reset the
        // flag in case the State is somehow reused; mounted is false after
        // dispose so any further focus events would early-out anyway.
        _focusScrollPending = false;
        return;
      }
      if (!controller.hasClients) {
        _focusScrollPending = false;
        return;
      }
      controller
          .animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            // Release the guard only after animateTo settles, so a focus
            // event arriving mid-animation does not schedule a second one.
            // Skip the reset if we were disposed during the animation.
            if (mounted) _focusScrollPending = false;
          });
    });
  }

  Future<void> _addTrack() async {
    if (!_addFormKey.currentState!.validate()) return;
    if (_tracks.length >= 10) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final color = _selectedColor;

    final track = await ref
        .read(editArtistProvider.notifier)
        .createTrack(name, color);
    if (!mounted) return;

    if (track != null) {
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

  Future<void> _editTrack(Track track) async {
    final updated = await showDialog<Track>(
      context: context,
      builder: (dialogContext) {
        final nameController = TextEditingController(text: track.name);
        // All dialog-local state lives inside the StatefulBuilder scope so
        // setDialogState rebuilds reach every value (PR #346 review F3).
        var selectedColor = track.color;
        var isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> save() async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                setDialogState(() => errorText = ctx.l10n.trackNameRequired);
                return;
              }
              // Reject duplicate names against the current local list,
              // skipping the row being edited (otherwise renaming to the
              // same name would always fail).
              if (_tracks.any(
                (t) =>
                    t.id != track.id &&
                    t.name.toLowerCase() == newName.toLowerCase(),
              )) {
                setDialogState(
                  () => errorText = ctx.l10n.trackNameAlreadyExists,
                );
                return;
              }

              final nameChanged = newName != track.name;
              final colorChanged = selectedColor != track.color;
              if (!nameChanged && !colorChanged) {
                Navigator.pop(dialogContext);
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorText = null;
              });

              final result = await ref
                  .read(editArtistProvider.notifier)
                  .updateTrack(
                    id: track.id,
                    name: nameChanged ? newName : null,
                    color: colorChanged ? selectedColor : null,
                  );

              if (!dialogContext.mounted) return;
              if (result != null) {
                Navigator.pop(dialogContext, result);
              } else {
                setDialogState(() {
                  isSubmitting = false;
                  errorText = ctx.l10n.failedUpdateTrackRetry;
                });
              }
            }

            return AlertDialog(
              backgroundColor: colorSurface1,
              scrollable: true,
              insetPadding: const EdgeInsets.all(spaceLg),
              title: Text(
                ctx.l10n.editTrack,
                style: const TextStyle(color: colorTextPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 30,
                    style: const TextStyle(color: colorTextPrimary),
                    decoration: InputDecoration(
                      labelText: ctx.l10n.trackName,
                      labelStyle: const TextStyle(color: colorTextMuted),
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    enabled: !isSubmitting,
                    onSubmitted: isSubmitting ? null : (_) => save(),
                  ),
                  const SizedBox(height: spaceMd),
                  TrackColorPicker(
                    selectedHex: selectedColor,
                    onChanged: (hex) =>
                        setDialogState(() => selectedColor = hex),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(ctx.l10n.cancel),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : save,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(ctx.l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == null || !mounted) return;
    setState(() {
      final idx = _tracks.indexWhere((t) => t.id == updated.id);
      if (idx != -1) _tracks = [..._tracks]..[idx] = updated;
    });
    // Refresh the artist page so the updated color/name shows up in the
    // timeline + node renderings, mirroring _deleteTrack's reload step.
    await ref
        .read(artistPageProvider.notifier)
        .loadArtist(widget.artist.artistUsername);
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
            padding: EdgeInsets.fromLTRB(spaceXl, spaceLg, spaceXl, spaceXl),
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
                  if (widget.isOwner && !_showAddForm && _tracks.length < 10)
                    IconButton(
                      icon: const Icon(Icons.add, color: colorAccentGold),
                      onPressed: () {
                        setState(() {
                          _showAddForm = true;
                          // Seed the picker with the next auto-color so users
                          // who don't care about color get the same rotation
                          // they had before, while still being able to override.
                          _selectedColor =
                              trackColorPresets[_tracks.length %
                                  trackColorPresets.length];
                        });
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
                  onDelete: widget.isOwner ? () => _deleteTrack(track) : null,
                  onEdit: widget.isOwner ? () => _editTrack(track) : null,
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
                        focusNode: _nameFocusNode,
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
                      TrackColorPicker(
                        selectedHex: _selectedColor,
                        onChanged: (hex) =>
                            setState(() => _selectedColor = hex),
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
  // Both callbacks are nullable so the row can render in read-only
  // contexts (PR #346 review F2 — keep StatelessWidget + delegate
  // dialog management to the parent State, mirroring _TrackChip in
  // register_artist_wizard.dart). The parent already gates these on
  // EditArtistTracksSheet.isOwner; null hides the corresponding icon.
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _TrackRow({required this.track, this.onDelete, this.onEdit});

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
            if (onEdit != null)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colorAccentGold,
                ),
                tooltip: context.l10n.editTrack,
                onPressed: onEdit,
              ),
            if (onDelete != null)
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
