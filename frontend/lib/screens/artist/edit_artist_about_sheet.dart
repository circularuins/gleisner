import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';

class EditArtistAboutSheet extends ConsumerStatefulWidget {
  final Artist artist;

  const EditArtistAboutSheet({super.key, required this.artist});

  @override
  ConsumerState<EditArtistAboutSheet> createState() =>
      _EditArtistAboutSheetState();
}

class _EditArtistAboutSheetState extends ConsumerState<EditArtistAboutSheet> {
  late final TextEditingController _taglineController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _activeSinceController;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _taglineController = TextEditingController(
      text: widget.artist.tagline ?? '',
    );
    _bioController = TextEditingController(text: widget.artist.bio ?? '');
    _locationController = TextEditingController(
      text: widget.artist.location ?? '',
    );
    _activeSinceController = TextEditingController(
      text: widget.artist.activeSince?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _taglineController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _activeSinceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final tagline = _taglineController.text.trim();
    final bio = _bioController.text.trim();
    final location = _locationController.text.trim();
    final activeSinceText = _activeSinceController.text.trim();
    final activeSince = activeSinceText.isNotEmpty
        ? int.tryParse(activeSinceText)
        : null;

    final ok = await ref
        .read(editArtistProvider.notifier)
        .updateArtist(
          tagline: tagline.isNotEmpty ? tagline : null,
          bio: bio.isNotEmpty ? bio : null,
          location: location.isNotEmpty ? location : null,
          activeSince: activeSince,
        );

    if (!mounted) return;

    if (ok) {
      // Reload the artist page data
      ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
      Navigator.pop(context);
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to update. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: colorSurface1,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusSheet),
            ),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                spaceXl,
                spaceLg,
                spaceXl,
                spaceXl + MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                // Handle bar
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

                Text('Edit About', style: textTitle),
                const SizedBox(height: spaceXl),

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

                // Tagline
                TextFormField(
                  controller: _taglineController,
                  maxLength: 80,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: _inputDecoration('Tagline'),
                ),
                const SizedBox(height: spaceLg),

                // Bio
                TextFormField(
                  controller: _bioController,
                  maxLength: 1000,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: _inputDecoration('Bio'),
                ),
                const SizedBox(height: spaceLg),

                // Location
                TextFormField(
                  controller: _locationController,
                  maxLength: 100,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: _inputDecoration('Location'),
                ),
                const SizedBox(height: spaceLg),

                // Active Since
                TextFormField(
                  controller: _activeSinceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: _inputDecoration('Active Since (year)'),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final year = int.tryParse(value.trim());
                      if (year == null ||
                          year < 1900 ||
                          year > DateTime.now().year) {
                        return 'Enter a valid year (1900-${DateTime.now().year})';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: spaceXl),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorAccentGold,
                      foregroundColor: colorSurface0,
                      padding: const EdgeInsets.symmetric(vertical: spaceMd),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: colorTextMuted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: colorBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: colorAccentGold),
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
    );
  }
}
