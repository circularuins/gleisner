import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../providers/artist_page_provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/edit_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/milestone_category.dart';

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
        title: Text(
          context.l10n.deleteConfirmation,
          style: const TextStyle(color: colorTextPrimary),
        ),
        content: Text(
          '${context.l10n.remove} "${milestone.title}"?',
          style: const TextStyle(color: colorTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await ref
        .read(editArtistProvider.notifier)
        .deleteMilestone(milestone.id);
    if (ok && mounted) {
      setState(() {
        _milestones = _milestones.where((m) => m.id != milestone.id).toList();
      });
      ref.read(artistPageProvider.notifier).loadArtist(widget.artistUsername);
    }
  }

  Future<void> _editMilestone(ArtistMilestone milestone) async {
    final titleCtl = TextEditingController(text: milestone.title);
    final descCtl = TextEditingController(text: milestone.description ?? '');
    var editCategory = milestone.category;
    var editDate = DateTime.tryParse(milestone.date) ?? DateTime.now();

    final updated = await showDialog<ArtistMilestone>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colorSurface1,
          title: Text(
            context.l10n.editMilestone,
            style: const TextStyle(color: colorTextPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: spaceXs,
                  children: milestoneCategoryKeys.map((key) {
                    return ChoiceChip(
                      label: Text(milestoneCategoryName(context, key)),
                      avatar: Icon(milestoneCategoryIcon(key), size: 16),
                      selected: editCategory == key,
                      onSelected: (_) =>
                          setDialogState(() => editCategory = key),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: spaceMd),
                TextField(
                  controller: titleCtl,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.title,
                    border: const OutlineInputBorder(),
                  ),
                  maxLength: 255,
                ),
                const SizedBox(height: spaceSm),
                TextField(
                  controller: descCtl,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.descriptionOptional,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: spaceMd),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: editDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => editDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    '${editDate.year}/${editDate.month.toString().padLeft(2, '0')}/${editDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                final title = titleCtl.text.trim();
                if (title.isEmpty) return;
                final date =
                    '${editDate.year}-${editDate.month.toString().padLeft(2, '0')}-${editDate.day.toString().padLeft(2, '0')}';
                final desc = descCtl.text.trim();
                final result = await ref
                    .read(editArtistProvider.notifier)
                    .updateMilestone(
                      id: milestone.id,
                      category: editCategory,
                      title: title,
                      description: desc.isNotEmpty ? desc : null,
                      date: date,
                    );
                if (result != null && ctx.mounted) {
                  Navigator.pop(ctx, result);
                }
              },
              child: Text(
                context.l10n.save,
                style: const TextStyle(color: colorAccentGold),
              ),
            ),
          ],
        ),
      ),
    );

    titleCtl.dispose();
    descCtl.dispose();

    if (updated != null && mounted) {
      setState(() {
        _milestones =
            _milestones.map((m) => m.id == updated.id ? updated : m).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: spaceLg),
              child: Row(
                children: [
                  Text(
                    context.l10n.milestones,
                    style: const TextStyle(
                      color: colorTextPrimary,
                      fontSize: fontSizeLg,
                      fontWeight: weightBold,
                    ),
                  ),
                  const SizedBox(width: spaceSm),
                  Text(
                    context.l10n.milestonesCountOf(_milestones.length),
                    style: const TextStyle(
                      color: colorTextMuted,
                      fontSize: fontSizeSm,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showAddForm ? Icons.close : Icons.add,
                      color: _milestones.length >= 200
                          ? colorTextMuted
                          : colorInteractive,
                    ),
                    onPressed: _milestones.length >= 200
                        ? null
                        : () => setState(() => _showAddForm = !_showAddForm),
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
                    color: Colors.red,
                    fontSize: fontSizeSm,
                  ),
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
                      children: milestoneCategoryKeys.map((key) {
                        final selected = _selectedCategory == key;
                        return ChoiceChip(
                          label: Text(milestoneCategoryName(context, key)),
                          avatar: Icon(milestoneCategoryIcon(key), size: 16),
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
                      decoration: InputDecoration(
                        labelText: context.l10n.title,
                        border: const OutlineInputBorder(),
                      ),
                      maxLength: 255,
                    ),
                    const SizedBox(height: spaceSm),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: colorTextPrimary),
                      decoration: InputDecoration(
                        labelText: context.l10n.descriptionOptional,
                        border: const OutlineInputBorder(),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.l10n.add),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: colorBorder),
            // Milestones list
            Expanded(
              child: _milestones.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.milestones,
                        style: const TextStyle(color: colorTextMuted),
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
                        return GestureDetector(
                          onTap: () => _editMilestone(m),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                milestoneCategoryIcon(m.category),
                                size: 20,
                                color: colorAccentGold,
                              ),
                              const SizedBox(width: spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      m.date.substring(0, 7),
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
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: colorInteractive,
                                ),
                                onPressed: () => _editMilestone(m),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: colorTextMuted,
                                ),
                                onPressed: () => _deleteMilestone(m),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
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
