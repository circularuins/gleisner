import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';

const _categories = [
  ('award', 'Award', Icons.emoji_events),
  ('release', 'Release', Icons.album),
  ('event', 'Event', Icons.event),
  ('affiliation', 'Affiliation', Icons.groups),
  ('education', 'Education', Icons.school),
  ('other', 'Other', Icons.star_outline),
];

IconData _categoryIcon(String category) {
  for (final (key, _, icon) in _categories) {
    if (key == category) return icon;
  }
  return Icons.star_outline;
}

class EditMilestonesSheet extends ConsumerStatefulWidget {
  final List<ArtistMilestone> milestones;
  final String artistUsername;

  const EditMilestonesSheet({
    super.key,
    required this.milestones,
    required this.artistUsername,
  });

  @override
  ConsumerState<EditMilestonesSheet> createState() =>
      _EditMilestonesSheetState();
}

class _EditMilestonesSheetState extends ConsumerState<EditMilestonesSheet> {
  late List<ArtistMilestone> _milestones;
  bool _showAddForm = false;
  bool _isSubmitting = false;
  String? _error;

  // Add form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'other';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _milestones = [...widget.milestones];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addMilestone() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final date =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final description = _descriptionController.text.trim();

    final milestone = await ref
        .read(editArtistProvider.notifier)
        .createMilestone(
          category: _selectedCategory,
          title: title,
          description: description.isNotEmpty ? description : null,
          date: date,
        );

    if (!mounted) return;

    if (milestone != null) {
      setState(() {
        _milestones = [milestone, ..._milestones];
        _milestones.sort((a, b) => b.date.compareTo(a.date));
        _showAddForm = false;
        _isSubmitting = false;
        _titleController.clear();
        _descriptionController.clear();
        _selectedCategory = 'other';
        _selectedDate = DateTime.now();
      });
      ref.read(artistPageProvider.notifier).loadArtist(widget.artistUsername);
    } else {
      setState(() {
        _error = 'Failed to add milestone';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteMilestone(ArtistMilestone milestone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSurface1,
        title:
            const Text('Delete?', style: TextStyle(color: colorTextPrimary)),
        content: Text(
          'Remove "${milestone.title}"?',
          style: const TextStyle(color: colorTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok =
        await ref.read(editArtistProvider.notifier).deleteMilestone(milestone.id);
    if (ok && mounted) {
      setState(() {
        _milestones = _milestones.where((m) => m.id != milestone.id).toList();
      });
      ref.read(artistPageProvider.notifier).loadArtist(widget.artistUsername);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: colorSurface1,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: spaceSm),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorTextMuted.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(radiusFull),
                ),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: spaceLg),
              child: Row(
                children: [
                  const Text(
                    'Career',
                    style: TextStyle(
                      color: colorTextPrimary,
                      fontSize: fontSizeLg,
                      fontWeight: weightBold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showAddForm ? Icons.close : Icons.add,
                      color: colorInteractive,
                    ),
                    onPressed: () =>
                        setState(() => _showAddForm = !_showAddForm),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceLg),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: fontSizeSm),
                ),
              ),
            // Add form
            if (_showAddForm)
              Padding(
                padding: const EdgeInsets.all(spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category chips
                    Wrap(
                      spacing: spaceXs,
                      children: _categories.map((c) {
                        final (key, label, icon) = c;
                        final selected = _selectedCategory == key;
                        return ChoiceChip(
                          label: Text(label),
                          avatar: Icon(icon, size: 16),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = key),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: spaceMd),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Grammy Award, First Album Release',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 255,
                    ),
                    const SizedBox(height: spaceSm),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: spaceMd),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: spaceMd),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _addMilestone,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add'),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: colorBorder),
            // Milestones list
            Expanded(
              child: _milestones.isEmpty
                  ? const Center(
                      child: Text(
                        'No career milestones yet',
                        style: TextStyle(color: colorTextMuted),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(spaceLg),
                      itemCount: _milestones.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: spaceMd),
                      itemBuilder: (context, index) {
                        final m = _milestones[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _categoryIcon(m.category),
                              size: 20,
                              color: colorAccentGold,
                            ),
                            const SizedBox(width: spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    style: const TextStyle(
                                      color: colorTextPrimary,
                                      fontWeight: weightMedium,
                                    ),
                                  ),
                                  const SizedBox(height: spaceXxs),
                                  Text(
                                    m.date.substring(0, 7), // YYYY-MM
                                    style: const TextStyle(
                                      color: colorTextMuted,
                                      fontSize: fontSizeXs,
                                    ),
                                  ),
                                  if (m.description != null) ...[
                                    const SizedBox(height: spaceXxs),
                                    Text(
                                      m.description!,
                                      style: const TextStyle(
                                        color: colorTextSecondary,
                                        fontSize: fontSizeSm,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: colorTextMuted),
                              onPressed: () => _deleteMilestone(m),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
