import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../providers/artist_page_provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/edit_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';

const _linkCategories = [
  'music',
  'social',
  'video',
  'website',
  'store',
  'other',
];

class EditArtistLinksSheet extends ConsumerStatefulWidget {
  final Artist artist;

  const EditArtistLinksSheet({super.key, required this.artist});

  @override
  ConsumerState<EditArtistLinksSheet> createState() =>
      _EditArtistLinksSheetState();
}

class _EditArtistLinksSheetState extends ConsumerState<EditArtistLinksSheet> {
  late List<ArtistLink> _links;
  bool _showAddForm = false;
  bool _isSubmitting = false;
  String? _error;

  // Add form controllers
  final _platformController = TextEditingController();
  final _urlController = TextEditingController();
  String _selectedCategory = 'music';
  final _addFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _links = List.from(widget.artist.links);
  }

  @override
  void dispose() {
    _platformController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addLink() async {
    if (!_addFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final link = await ref
        .read(editArtistProvider.notifier)
        .createLink(
          linkCategory: _selectedCategory,
          platform: _platformController.text.trim(),
          url: _urlController.text.trim(),
          position: _links.length,
        );

    if (!mounted) return;

    if (link != null) {
      setState(() {
        _links.add(link);
        _showAddForm = false;
        _isSubmitting = false;
        _platformController.clear();
        _urlController.clear();
        _selectedCategory = 'music';
      });
      ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
    } else {
      setState(() {
        _isSubmitting = false;
        _error = context.l10n.failedAddLink;
      });
    }
  }

  Future<void> _deleteLink(ArtistLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorSurface1,
        title: Text(
          context.l10n.deleteConfirmation,
          style: const TextStyle(color: colorTextPrimary),
        ),
        content: Text(
          '${context.l10n.remove} ${link.platform}?',
          style: const TextStyle(color: colorTextSecondary),
        ),
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

    final ok = await ref.read(editArtistProvider.notifier).deleteLink(link.id);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _links.removeWhere((l) => l.id == link.id);
      });
      ref
          .read(artistPageProvider.notifier)
          .loadArtist(widget.artist.artistUsername);
    }
  }

  @override
  Widget build(BuildContext context) {
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

              Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.manageLinks, style: textTitle),
                  ),
                  if (!_showAddForm)
                    IconButton(
                      icon: const Icon(Icons.add, color: colorAccentGold),
                      onPressed: () => setState(() => _showAddForm = true),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
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

              // Existing links
              if (_links.isEmpty && !_showAddForm)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: spaceXl),
                  child: Center(
                    child: Text(
                      context.l10n.noLinksYet,
                      style: textCaption.copyWith(color: colorTextMuted),
                    ),
                  ),
                ),

              ..._links.map(
                (link) =>
                    _LinkRow(link: link, onDelete: () => _deleteLink(link)),
              ),

              // Add form
              if (_showAddForm) ...[
                const SizedBox(height: spaceLg),
                const Divider(color: colorBorder),
                const SizedBox(height: spaceLg),
                _AddLinkForm(
                  formKey: _addFormKey,
                  platformController: _platformController,
                  urlController: _urlController,
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (c) =>
                      setState(() => _selectedCategory = c),
                  isSubmitting: _isSubmitting,
                  onSave: _addLink,
                  onCancel: () => setState(() => _showAddForm = false),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  final ArtistLink link;
  final VoidCallback onDelete;

  const _LinkRow({required this.link, required this.onDelete});

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
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: spaceSm,
                vertical: spaceXxs,
              ),
              decoration: BoxDecoration(
                color: colorSurface2,
                borderRadius: BorderRadius.circular(radiusSm),
              ),
              child: Text(
                link.linkCategory.toUpperCase(),
                style: const TextStyle(
                  color: colorTextMuted,
                  fontSize: fontSizeXs,
                  fontWeight: weightSemibold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.platform,
                    style: const TextStyle(
                      color: colorTextPrimary,
                      fontSize: fontSizeSm,
                      fontWeight: weightMedium,
                    ),
                  ),
                  Text(
                    link.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: colorTextMuted,
                      fontSize: fontSizeXs,
                    ),
                  ),
                ],
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

class _AddLinkForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController platformController;
  final TextEditingController urlController;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final bool isSubmitting;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _AddLinkForm({
    required this.formKey,
    required this.platformController,
    required this.urlController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.isSubmitting,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.addLink,
            style: textHeading.copyWith(color: colorTextPrimary),
          ),
          const SizedBox(height: spaceMd),

          // Category chips
          Wrap(
            spacing: spaceSm,
            runSpacing: spaceSm,
            children: _linkCategories.map((cat) {
              final isSelected = cat == selectedCategory;
              return GestureDetector(
                onTap: () => onCategoryChanged(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: spaceMd,
                    vertical: spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorAccentGold.withValues(alpha: 0.15)
                        : colorSurface0,
                    borderRadius: BorderRadius.circular(radiusFull),
                    border: Border.all(
                      color: isSelected ? colorAccentGold : colorBorder,
                    ),
                  ),
                  child: Text(
                    _localizedCategory(context, cat),
                    style: TextStyle(
                      color: isSelected ? colorAccentGold : colorTextSecondary,
                      fontSize: fontSizeSm,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: spaceLg),

          // Platform name
          TextFormField(
            controller: platformController,
            maxLength: 50,
            style: const TextStyle(color: colorTextPrimary),
            decoration: _inputDecoration(context.l10n.platform),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.platformNameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: spaceLg),

          // URL
          TextFormField(
            controller: urlController,
            style: const TextStyle(color: colorTextPrimary),
            decoration: _inputDecoration(context.l10n.url),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'URL is required';
              }
              final uri = Uri.tryParse(value.trim());
              if (uri == null || !['http', 'https'].contains(uri.scheme)) {
                return context.l10n.invalidUrl;
              }
              return null;
            },
          ),
          const SizedBox(height: spaceXl),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSubmitting ? null : onCancel,
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
                  onPressed: isSubmitting ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorAccentGold,
                    foregroundColor: colorSurface0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.add),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _localizedCategory(BuildContext context, String cat) {
    return switch (cat) {
      'music' => context.l10n.linkCategoryMusic,
      'social' => context.l10n.linkCategorySocial,
      'video' => context.l10n.linkCategoryVideo,
      'website' => context.l10n.linkCategoryWebsite,
      'store' => context.l10n.linkCategoryStore,
      'other' => context.l10n.linkCategoryOther,
      _ => cat,
    };
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
