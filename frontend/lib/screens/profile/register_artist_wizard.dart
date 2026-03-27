import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../graphql/client.dart';
import '../../graphql/mutations/artist.dart';
import '../../graphql/mutations/genre.dart';
import '../../graphql/mutations/track.dart';
import '../../graphql/queries/artist.dart';
import '../../models/genre.dart';
import '../../providers/my_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';

/// ADR 013: 4-step artist registration wizard.
/// Step 1: Intro — feature overview
/// Step 2: Artist Profile — username, display name, tagline, location, activeSince
/// Step 3: Track Setup — template selection + customization (ADR 012)
/// Step 4: Complete — mini preview + navigation
class RegisterArtistWizard extends ConsumerStatefulWidget {
  final ValueChanged<String> onRegistered;

  const RegisterArtistWizard({super.key, required this.onRegistered});

  @override
  ConsumerState<RegisterArtistWizard> createState() =>
      _RegisterArtistWizardState();
}

class _RegisterArtistWizardState extends ConsumerState<RegisterArtistWizard> {
  int _step = 0;
  bool _isSubmitting = false;
  String? _error;

  // Step 2: Artist Profile
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _locationController = TextEditingController();
  final _activeSinceController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();

  // Step 2: Genre selection
  List<Genre> _availableGenres = [];
  final List<Genre> _selectedGenres = [];

  // Step 3: Track Setup
  String? _selectedTemplate;
  List<_TrackDraft> _tracks = [];

  // Step 4: Result
  String? _registeredArtistUsername;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final client = ref.read(graphqlClientProvider);
    final result = await client.query(QueryOptions(document: gql(genresQuery)));
    if (!mounted || result.hasException) return;
    final list =
        (result.data?['genres'] as List?)
            ?.map((g) => Genre.fromJson(g as Map<String, dynamic>))
            .where((g) => g.isPromoted)
            .toList() ??
        [];
    setState(() => _availableGenres = list);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _taglineController.dispose();
    _locationController.dispose();
    _activeSinceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        leading: _step == 0 || _step == 3
            ? IconButton(
                icon: const Icon(Icons.close, color: colorInteractive),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: colorInteractive),
                onPressed: () => setState(() => _step--),
              ),
        title: Text(
          _stepTitle,
          style: const TextStyle(color: colorTextPrimary, fontSize: fontSizeLg),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: spaceMd),
            child: Center(
              child: Text(
                '${_step + 1}/4',
                style: const TextStyle(
                  color: colorTextMuted,
                  fontSize: fontSizeSm,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildStep(),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
    0 => 'Become an Artist',
    1 => 'Artist Profile',
    2 => 'Set Up Tracks',
    3 => 'Welcome!',
    _ => '',
  };

  Widget _buildStep() => switch (_step) {
    0 => _StepIntro(
      key: const ValueKey(0),
      onNext: () => setState(() => _step = 1),
    ),
    1 => _StepProfile(
      key: const ValueKey(1),
      formKey: _profileFormKey,
      usernameController: _usernameController,
      displayNameController: _displayNameController,
      taglineController: _taglineController,
      locationController: _locationController,
      activeSinceController: _activeSinceController,
      availableGenres: _availableGenres,
      selectedGenres: _selectedGenres,
      onGenreToggle: (genre) {
        setState(() {
          if (_selectedGenres.any((g) => g.id == genre.id)) {
            _selectedGenres.removeWhere((g) => g.id == genre.id);
          } else if (_selectedGenres.length < 5) {
            _selectedGenres.add(genre);
          }
        });
      },
      onCreateGenre: (name) async {
        final client = ref.read(graphqlClientProvider);
        final result = await client.mutate(
          MutationOptions(
            document: gql(createGenreMutation),
            variables: {'name': name},
          ),
        );
        if (!mounted || result.hasException) return;
        final data = result.data?['createGenre'] as Map<String, dynamic>?;
        if (data == null) return;
        final genre = Genre.fromJson(data);
        setState(() {
          // Add to available if not already there
          if (!_availableGenres.any((g) => g.id == genre.id)) {
            _availableGenres.add(genre);
          }
          // Auto-select if under limit
          if (_selectedGenres.length < 5 &&
              !_selectedGenres.any((g) => g.id == genre.id)) {
            _selectedGenres.add(genre);
          }
        });
      },
      error: _error,
      onNext: () {
        if (_profileFormKey.currentState!.validate()) {
          setState(() {
            _error = null;
            _step = 2;
          });
        }
      },
    ),
    2 => _StepTracks(
      key: const ValueKey(2),
      selectedTemplate: _selectedTemplate,
      tracks: _tracks,
      isSubmitting: _isSubmitting,
      error: _error,
      onTemplateSelected: (template, tracks) {
        setState(() {
          _selectedTemplate = template;
          _tracks = tracks;
        });
      },
      onTracksChanged: (tracks) => setState(() => _tracks = tracks),
      onSubmit: _handleRegister,
    ),
    3 => _StepComplete(
      key: const ValueKey(3),
      artistUsername: _registeredArtistUsername ?? '',
      displayName: _displayNameController.text.trim(),
      tracks: _tracks,
      onDone: () {
        Navigator.pop(context);
        widget.onRegistered(_registeredArtistUsername!);
      },
    ),
    _ => const SizedBox.shrink(),
  };

  Future<void> _handleRegister() async {
    if (_tracks.isEmpty) {
      setState(() => _error = 'Add at least one track.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final client = ref.read(graphqlClientProvider);

      // 1. Register artist
      final variables = <String, dynamic>{
        'artistUsername': _usernameController.text.trim(),
        'displayName': _displayNameController.text.trim(),
      };
      final tagline = _taglineController.text.trim();
      if (tagline.isNotEmpty) variables['tagline'] = tagline;
      final location = _locationController.text.trim();
      if (location.isNotEmpty) variables['location'] = location;
      final activeSince = int.tryParse(_activeSinceController.text.trim());
      if (activeSince != null) variables['activeSince'] = activeSince;

      final result = await client.mutate(
        MutationOptions(
          document: gql(registerArtistMutation),
          variables: variables,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        debugPrint('[RegisterArtist] error: ${result.exception}');
        setState(() {
          _isSubmitting = false;
          _error = 'Registration failed. Please try again.';
          _step = 1; // Go back to profile step
        });
        return;
      }

      final data = result.data?['registerArtist'] as Map<String, dynamic>?;
      if (data == null) {
        setState(() {
          _isSubmitting = false;
          _error = 'Unexpected response.';
        });
        return;
      }

      _registeredArtistUsername = data['artistUsername'] as String;

      // 2. Create tracks — check each result
      final failedTracks = <String>[];
      for (final track in _tracks) {
        final trackResult = await client.mutate(
          MutationOptions(
            document: gql(createTrackMutation),
            variables: {'name': track.name, 'color': track.color},
          ),
        );
        if (trackResult.hasException ||
            trackResult.data?['createTrack'] == null) {
          debugPrint('[RegisterArtist] track creation failed: ${track.name}');
          failedTracks.add(track.name);
        }
      }

      if (!mounted) return;

      // 3. Add genres (parallel)
      final genreResults = await Future.wait([
        for (var i = 0; i < _selectedGenres.length; i++)
          client.mutate(
            MutationOptions(
              document: gql(addArtistGenreMutation),
              variables: {'genreId': _selectedGenres[i].id, 'position': i},
            ),
          ),
      ]);
      final failedGenres = <String>[];
      for (var i = 0; i < genreResults.length; i++) {
        if (genreResults[i].hasException) {
          debugPrint(
            '[RegisterArtist] genre failed: ${_selectedGenres[i].name}',
          );
          failedGenres.add(_selectedGenres[i].name);
        }
      }

      if (!mounted) return;

      // 4. Refresh myArtistProvider so Profile screen updates
      await ref.read(myArtistProvider.notifier).load();

      if (!mounted) return;

      final errors = <String>[];
      if (failedTracks.isNotEmpty) {
        errors.add('Tracks: ${failedTracks.join(", ")}');
      }
      if (failedGenres.isNotEmpty) {
        errors.add('Genres: ${failedGenres.join(", ")}');
      }
      if (errors.isNotEmpty) {
        setState(() {
          _isSubmitting = false;
          _error =
              'Some items failed: ${errors.join("; ")}. '
              'You can update them later.';
          _step = 3; // Still proceed to Complete — artist is registered
        });
        return;
      }

      setState(() {
        _isSubmitting = false;
        _step = 3; // Complete
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RegisterArtist] error: $e');
      setState(() {
        _isSubmitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }
}

// ── Step 1: Intro ──

class _StepIntro extends StatelessWidget {
  final VoidCallback onNext;

  const _StepIntro({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your artist profile is separate from your personal account.',
            style: textBody.copyWith(color: colorTextSecondary),
          ),
          const SizedBox(height: spaceXl),
          _FeatureCard(
            icon: Icons.person,
            title: 'Artist Page',
            description:
                'A public creative identity with its own name, avatar, and cover image.',
          ),
          const SizedBox(height: spaceMd),
          _FeatureCard(
            icon: Icons.graphic_eq,
            title: 'Tracks',
            description:
                'Organize your posts into themed streams — like channels on a mixing board.',
          ),
          const SizedBox(height: spaceMd),
          _FeatureCard(
            icon: Icons.cell_tower,
            title: 'Broadcasting',
            description:
                'Fans Tune In to your timeline and receive your creative updates.',
          ),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: colorAccentGold,
              foregroundColor: colorSurface0,
              padding: const EdgeInsets.symmetric(vertical: spaceLg),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(spaceLg),
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorAccentGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: Icon(icon, color: colorAccentGold, size: 20),
          ),
          const SizedBox(width: spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: colorTextPrimary,
                    fontSize: fontSizeMd,
                    fontWeight: weightSemibold,
                  ),
                ),
                const SizedBox(height: spaceXxs),
                Text(
                  description,
                  style: const TextStyle(
                    color: colorTextMuted,
                    fontSize: fontSizeSm,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Artist Profile ──

class _StepProfile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController displayNameController;
  final TextEditingController taglineController;
  final TextEditingController locationController;
  final TextEditingController activeSinceController;
  final List<Genre> availableGenres;
  final List<Genre> selectedGenres;
  final ValueChanged<Genre> onGenreToggle;
  final ValueChanged<String> onCreateGenre;
  final String? error;
  final VoidCallback onNext;

  const _StepProfile({
    super.key,
    required this.formKey,
    required this.usernameController,
    required this.displayNameController,
    required this.taglineController,
    required this.locationController,
    required this.activeSinceController,
    required this.availableGenres,
    required this.selectedGenres,
    required this.onGenreToggle,
    required this.onCreateGenre,
    this.error,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: spaceXl,
        right: spaceXl,
        top: spaceXl,
        bottom: MediaQuery.of(context).viewInsets.bottom + spaceXl,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(spaceMd),
                decoration: BoxDecoration(
                  color: colorError.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
                child: Text(
                  error!,
                  style: textCaption.copyWith(color: colorError),
                ),
              ),
              const SizedBox(height: spaceLg),
            ],
            TextFormField(
              controller: usernameController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Artist Username *',
                hintText: 'e.g. myjazzjourney',
                border: OutlineInputBorder(),
                helperText: 'Letters, numbers, underscores. 2-30 chars.',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final trimmed = v.trim();
                if (trimmed.length < 2) return 'At least 2 characters';
                if (trimmed.length > 30) return 'Max 30 characters';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
                  return 'Letters, numbers, and underscores only';
                }
                return null;
              },
            ),
            const SizedBox(height: spaceLg),
            TextFormField(
              controller: displayNameController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Display Name *',
                hintText: 'e.g. Jazz Journey',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length > 50) return 'Max 50 characters';
                return null;
              },
            ),
            const SizedBox(height: spaceLg),
            TextFormField(
              controller: taglineController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Tagline',
                hintText: 'A short creative tagline (max 80 chars)',
                border: OutlineInputBorder(),
              ),
              maxLength: 80,
            ),
            const SizedBox(height: spaceMd),
            TextFormField(
              controller: locationController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Osaka, Japan',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: spaceMd),
            TextFormField(
              controller: activeSinceController,
              style: const TextStyle(color: colorTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Active Since (Year)',
                hintText: 'e.g. 2019',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // Optional
                final year = int.tryParse(v.trim());
                if (year == null) return 'Enter a valid year';
                if (year < 1900 || year > DateTime.now().year) {
                  return 'Must be between 1900 and ${DateTime.now().year}';
                }
                return null;
              },
            ),
            // Genre selection (ADR 013: up to 5)
            if (availableGenres.isNotEmpty) ...[
              const SizedBox(height: spaceXl),
              Text(
                'Genres (up to 5)',
                style: TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeMd,
                  fontWeight: weightSemibold,
                ),
              ),
              const SizedBox(height: spaceSm),
              Wrap(
                spacing: spaceSm,
                runSpacing: spaceSm,
                children: availableGenres.map((genre) {
                  final selected = selectedGenres.any((g) => g.id == genre.id);
                  return GestureDetector(
                    onTap: () => onGenreToggle(genre),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: spaceMd,
                        vertical: spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorAccentGold.withValues(alpha: 0.15)
                            : colorSurface2,
                        borderRadius: BorderRadius.circular(radiusFull),
                        border: Border.all(
                          color: selected ? colorAccentGold : colorBorder,
                        ),
                      ),
                      child: Text(
                        genre.name,
                        style: TextStyle(
                          color: selected
                              ? colorAccentGold
                              : colorTextSecondary,
                          fontSize: fontSizeSm,
                          fontWeight: selected ? weightSemibold : weightNormal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: spaceSm),
              GestureDetector(
                onTap: () async {
                  final controller = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: colorSurface1,
                      title: const Text(
                        'Create Genre',
                        style: TextStyle(color: colorTextPrimary),
                      ),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(color: colorTextPrimary),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Ambient Pop',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(ctx, controller.text.trim()),
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (name != null && name.isNotEmpty) {
                    onCreateGenre(name);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: colorInteractiveMuted),
                    const SizedBox(width: spaceXs),
                    Text(
                      'Create custom genre',
                      style: TextStyle(
                        color: colorInteractiveMuted,
                        fontSize: fontSizeSm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: spaceXl),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: colorAccentGold,
                foregroundColor: colorSurface0,
                padding: const EdgeInsets.symmetric(vertical: spaceLg),
              ),
              child: const Text('Next: Set Up Tracks'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Track Setup (ADR 012) ──

class _TrackDraft {
  String name;
  String color;

  _TrackDraft({required this.name, required this.color});
}

const _templates = {
  'Musician': [
    _TemplateTrack('Play', '#f97316'),
    _TemplateTrack('Compose', '#a78bfa'),
    _TemplateTrack('Life', '#22d3ee'),
  ],
  'Visual Artist': [
    _TemplateTrack('Works', '#e11d48'),
    _TemplateTrack('Process', '#7c3aed'),
    _TemplateTrack('Thoughts', '#0ea5e9'),
  ],
  'Writer': [
    _TemplateTrack('Writing', '#f59e0b'),
    _TemplateTrack('Notes', '#6366f1'),
    _TemplateTrack('Life', '#10b981'),
  ],
  'Filmmaker': [
    _TemplateTrack('Films', '#dc2626'),
    _TemplateTrack('BTS', '#ea580c'),
    _TemplateTrack('Stills', '#8b5cf6'),
  ],
  'Custom': <_TemplateTrack>[],
};

class _TemplateTrack {
  final String name;
  final String color;
  const _TemplateTrack(this.name, this.color);
}

class _StepTracks extends StatelessWidget {
  final String? selectedTemplate;
  final List<_TrackDraft> tracks;
  final bool isSubmitting;
  final String? error;
  final void Function(String template, List<_TrackDraft> tracks)
  onTemplateSelected;
  final ValueChanged<List<_TrackDraft>> onTracksChanged;
  final VoidCallback onSubmit;

  const _StepTracks({
    super.key,
    required this.selectedTemplate,
    required this.tracks,
    required this.isSubmitting,
    this.error,
    required this.onTemplateSelected,
    required this.onTracksChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Explainer
          Container(
            padding: const EdgeInsets.all(spaceLg),
            decoration: BoxDecoration(
              color: colorSurface1,
              borderRadius: BorderRadius.circular(radiusLg),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What are Tracks?',
                  style: TextStyle(
                    color: colorTextPrimary,
                    fontSize: fontSizeMd,
                    fontWeight: weightSemibold,
                  ),
                ),
                const SizedBox(height: spaceSm),
                Text(
                  'Tracks are themed channels within your Artist Page. '
                  'Fans can follow individual Tracks to only see what interests them.\n\n'
                  'Example: A musician might have Play, Compose, and Life tracks.',
                  style: textCaption.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: spaceXl),

          // Template selector
          const Text(
            'Choose a template',
            style: TextStyle(
              color: colorTextPrimary,
              fontSize: fontSizeMd,
              fontWeight: weightSemibold,
            ),
          ),
          const SizedBox(height: spaceMd),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in _templates.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: spaceSm),
                    child: _TemplateChip(
                      label: entry.key,
                      isSelected: selectedTemplate == entry.key,
                      onTap: () {
                        final drafts = entry.value
                            .map(
                              (t) => _TrackDraft(name: t.name, color: t.color),
                            )
                            .toList();
                        onTemplateSelected(entry.key, drafts);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: spaceXl),

          // Track list
          if (tracks.isNotEmpty) ...[
            const Text(
              'Your tracks',
              style: TextStyle(
                color: colorTextPrimary,
                fontSize: fontSizeMd,
                fontWeight: weightSemibold,
              ),
            ),
            const SizedBox(height: spaceMd),
            for (int i = 0; i < tracks.length; i++)
              _TrackChip(
                track: tracks[i],
                onRemove: () {
                  final updated = List<_TrackDraft>.from(tracks)..removeAt(i);
                  onTracksChanged(updated);
                },
                onRename: (newName) {
                  final updated = List<_TrackDraft>.from(tracks);
                  updated[i] = _TrackDraft(
                    name: newName,
                    color: tracks[i].color,
                  );
                  onTracksChanged(updated);
                },
              ),
            const SizedBox(height: spaceMd),
          ],

          // Add custom track
          if (tracks.length < 10)
            OutlinedButton.icon(
              onPressed: () {
                final colorIndex = tracks.length % trackColorPresets.length;
                final updated = List<_TrackDraft>.from(tracks)
                  ..add(
                    _TrackDraft(
                      name: 'Track ${tracks.length + 1}',
                      color: trackColorPresets[colorIndex],
                    ),
                  );
                onTracksChanged(updated);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Track'),
            ),

          if (error != null) ...[
            const SizedBox(height: spaceLg),
            Text(error!, style: textCaption.copyWith(color: colorError)),
          ],

          const SizedBox(height: spaceXl),

          // Submit
          FilledButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: colorAccentGold,
              foregroundColor: colorSurface0,
              padding: const EdgeInsets.symmetric(vertical: spaceLg),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorSurface0,
                    ),
                  )
                : const Text('Create Artist Profile'),
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorAccentGold.withValues(alpha: 0.15)
              : colorSurface2,
          borderRadius: BorderRadius.circular(radiusFull),
          border: Border.all(color: isSelected ? colorAccentGold : colorBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorAccentGold : colorTextSecondary,
            fontSize: fontSizeSm,
            fontWeight: isSelected ? weightSemibold : weightNormal,
          ),
        ),
      ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  final _TrackDraft track;
  final VoidCallback onRemove;
  final ValueChanged<String> onRename;

  const _TrackChip({
    required this.track,
    required this.onRemove,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(track.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: spaceSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: spaceMd),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final controller = TextEditingController(text: track.name);
                  try {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colorSurface1,
                        title: const Text(
                          'Rename Track',
                          style: TextStyle(color: colorTextPrimary),
                        ),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: colorTextPrimary),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (result != null && result.isNotEmpty) {
                      onRename(result);
                    }
                  } finally {
                    controller.dispose();
                  }
                },
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        track.name,
                        style: TextStyle(
                          color: color,
                          fontSize: fontSizeMd,
                          fontWeight: weightMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: spaceXs),
                    Icon(
                      Icons.edit,
                      size: 12,
                      color: color.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 16,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ── Step 4: Complete ──

class _StepComplete extends StatelessWidget {
  final String artistUsername;
  final String displayName;
  final List<_TrackDraft> tracks;
  final VoidCallback onDone;

  const _StepComplete({
    super.key,
    required this.artistUsername,
    required this.displayName,
    required this.tracks,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: colorAccentGold, size: 64),
          const SizedBox(height: spaceXl),
          Text(
            'Your Artist Page is ready!',
            style: textTitle.copyWith(fontSize: fontSizeTitle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: spaceMd),
          Text(
            '@$artistUsername',
            style: textCaption.copyWith(fontSize: fontSizeMd),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: spaceXl),

          // Mini preview
          Container(
            padding: const EdgeInsets.all(spaceLg),
            decoration: BoxDecoration(
              color: colorSurface1,
              borderRadius: BorderRadius.circular(radiusLg),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: colorTextPrimary,
                    fontSize: fontSizeLg,
                    fontWeight: weightBold,
                  ),
                ),
                const SizedBox(height: spaceMd),
                const Text(
                  'TRACKS',
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
                  children: tracks.map((t) {
                    final color = _TrackChip._parseColor(t.color);
                    return Chip(
                      label: Text(
                        t.name,
                        style: TextStyle(color: color, fontSize: fontSizeSm),
                      ),
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const Spacer(),

          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: colorAccentGold,
              foregroundColor: colorSurface0,
              padding: const EdgeInsets.symmetric(vertical: spaceLg),
            ),
            child: const Text('View Your Timeline'),
          ),
        ],
      ),
    );
  }
}
