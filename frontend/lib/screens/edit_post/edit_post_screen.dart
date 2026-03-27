import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/post.dart';
import '../../models/track.dart';
import '../../providers/timeline_provider.dart';
import '../../theme/gleisner_tokens.dart';

class EditPostScreen extends ConsumerStatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _mediaUrlController;
  late double _importance;
  late String _visibility;
  late String? _selectedTrackId;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title ?? '');
    _bodyController = TextEditingController(text: widget.post.body ?? '');
    _mediaUrlController = TextEditingController(
      text: widget.post.mediaUrl ?? '',
    );
    _importance = widget.post.importance;
    _visibility = widget.post.visibility;
    _selectedTrackId = widget.post.trackId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final mediaUrl = _mediaUrlController.text.trim();

    final updated = await ref
        .read(timelineProvider.notifier)
        .updatePost(
          id: widget.post.id,
          trackId: _selectedTrackId,
          title: title.isNotEmpty ? title : null,
          body: body.isNotEmpty ? body : null,
          mediaUrl: mediaUrl.isNotEmpty ? mediaUrl : null,
          importance: _importance,
          visibility: _visibility,
        );

    if (!mounted) return;

    if (updated != null) {
      context.pop();
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to update post. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final allTracks = ref.watch(
      timelineProvider.select((s) => s.artist?.tracks ?? <Track>[]),
    );
    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text(
          'Edit Post',
          style: TextStyle(color: colorTextPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: colorTextPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spaceXl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Track selector + MediaType indicator
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: spaceSm,
                      runSpacing: spaceSm,
                      children: allTracks.map((track) {
                        final isSelected = track.id == _selectedTrackId;
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: track.displayColor,
                            radius: 6,
                          ),
                          label: Text(track.name),
                          selected: isSelected,
                          selectedColor: track.displayColor.withValues(
                            alpha: 0.2,
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _selectedTrackId = track.id),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(post.mediaType.name),
                  visualDensity: VisualDensity.compact,
                ),
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

              // Content fields based on media type
              ..._buildContentFields(),

              // Visibility toggle
              const SizedBox(height: spaceLg),
              Row(
                children: [
                  Text(
                    'Visibility',
                    style: textLabel.copyWith(color: colorTextSecondary),
                  ),
                  const SizedBox(width: spaceLg),
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: _visibility == 'public',
                    onSelected: (_) => setState(() => _visibility = 'public'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: spaceSm),
                  ChoiceChip(
                    label: const Text('Draft'),
                    selected: _visibility == 'draft',
                    onSelected: (_) => setState(() => _visibility = 'draft'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // Importance slider
              const SizedBox(height: spaceLg),
              Text(
                'Importance',
                style: textLabel.copyWith(color: colorTextSecondary),
              ),
              Row(
                children: [
                  Text(
                    'quiet note',
                    style: textMicro.copyWith(color: colorTextMuted),
                  ),
                  Expanded(
                    child: Slider(
                      value: _importance,
                      onChanged: (v) => setState(() => _importance = v),
                      activeColor: colorAccentGold,
                    ),
                  ),
                  Text(
                    'hero moment',
                    style: textMicro.copyWith(color: colorTextMuted),
                  ),
                ],
              ),

              const SizedBox(height: spaceXl),

              // Save button
              FilledButton(
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
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentFields() {
    switch (widget.post.mediaType) {
      case MediaType.text:
        return _buildTextFields();
      case MediaType.image:
      case MediaType.video:
      case MediaType.audio:
        return _buildMediaFields();
      case MediaType.link:
        return _buildLinkFields();
    }
  }

  List<Widget> _buildTextFields() {
    return [
      TextFormField(
        controller: _titleController,
        maxLength: 100,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Title (optional)'),
      ),
      const SizedBox(height: spaceMd),
      TextFormField(
        controller: _bodyController,
        minLines: 6,
        maxLines: null,
        maxLength: 10000,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Content'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Content is required';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildMediaFields() {
    return [
      TextFormField(
        controller: _titleController,
        maxLength: 100,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Title (optional)'),
      ),
      const SizedBox(height: spaceMd),
      TextFormField(
        controller: _bodyController,
        maxLines: 3,
        maxLength: 500,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Caption (optional)'),
      ),
    ];
  }

  List<Widget> _buildLinkFields() {
    return [
      TextFormField(
        controller: _mediaUrlController,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration(
          'URL',
        ).copyWith(prefixIcon: const Icon(Icons.link, color: colorTextMuted)),
        keyboardType: TextInputType.url,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'URL is required';
          }
          final uri = Uri.tryParse(value.trim());
          if (uri == null || !['http', 'https'].contains(uri.scheme)) {
            return 'Enter a valid http(s) URL';
          }
          return null;
        },
      ),
      const SizedBox(height: spaceLg),
      TextFormField(
        controller: _bodyController,
        maxLines: 3,
        maxLength: 500,
        style: const TextStyle(color: colorTextPrimary),
        decoration: _inputDecoration('Caption (optional)'),
      ),
    ];
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
      fillColor: colorSurface1,
    );
  }
}
