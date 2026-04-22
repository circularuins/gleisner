import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_upload_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/media/avatar_image.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  final String? initialDisplayName;
  final String? initialBio;
  final String? initialAvatarUrl;
  final String initialProfileVisibility;
  final bool isChildAccount;
  final String username;

  const EditProfileSheet({
    super.key,
    this.initialDisplayName,
    this.initialBio,
    this.initialAvatarUrl,
    this.initialProfileVisibility = 'public',
    this.isChildAccount = false,
    this.username = '',
  });

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late String _profileVisibility;
  String? _avatarUrl;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialDisplayName ?? '',
    );
    _bioController = TextEditingController(text: widget.initialBio ?? '');
    _avatarUrl = widget.initialAvatarUrl;
    _profileVisibility = widget.initialProfileVisibility;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final l10n = context.l10n;
    final url = await ref
        .read(mediaUploadProvider.notifier)
        .pickAndUploadImage(
          category: UploadCategory.avatars,
          l10n: l10n,
          maxWidth: 512,
          maxHeight: 512,
        );
    if (url != null && mounted) {
      setState(() => _avatarUrl = url);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();

    final ok = await ref
        .read(authProvider.notifier)
        .updateProfile(
          displayName: displayName.isEmpty ? null : displayName,
          bio: bio.isEmpty ? null : bio,
          avatarUrl: _avatarUrl,
          profileVisibility: widget.isChildAccount ? null : _profileVisibility,
        );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to update profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(mediaUploadProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
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

                Text(context.l10n.editProfile, style: textTitle),
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

                // Avatar picker
                Center(
                  child: Column(
                    children: [
                      AvatarImage(
                        imageUrl: _avatarUrl,
                        seed: widget.username,
                        size: 80,
                        onTap: uploadState.isUploading ? null : _pickAvatar,
                      ),
                      const SizedBox(height: spaceSm),
                      if (uploadState.isUploading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          context.l10n.tapToChange,
                          style: textCaption.copyWith(color: colorTextMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: spaceLg),

                // Display Name
                TextFormField(
                  controller: _displayNameController,
                  maxLength: 50,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: _inputDecoration(context.l10n.displayName),
                ),
                const SizedBox(height: spaceLg),

                // Bio
                TextFormField(
                  controller: _bioController,
                  maxLength: 1000,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(color: colorTextPrimary),
                  decoration: _inputDecoration(context.l10n.bio),
                ),
                const SizedBox(height: spaceLg),

                // Profile visibility (disabled for child accounts)
                if (widget.isChildAccount) ...[
                  Row(
                    children: [
                      Text(
                        context.l10n.profileVisibility,
                        style: textLabel.copyWith(color: colorTextMuted),
                      ),
                      const SizedBox(width: spaceLg),
                      Text(
                        context.l10n.privateLocked,
                        style: textCaption.copyWith(
                          color: colorTextMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Text(
                        context.l10n.profileVisibility,
                        style: textLabel.copyWith(color: colorTextSecondary),
                      ),
                      const SizedBox(width: spaceLg),
                      ChoiceChip(
                        label: Text(context.l10n.public),
                        selected: _profileVisibility == 'public',
                        onSelected: (_) =>
                            setState(() => _profileVisibility = 'public'),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: spaceSm),
                      ChoiceChip(
                        label: Text(context.l10n.private),
                        selected: _profileVisibility == 'private',
                        onSelected: (_) =>
                            setState(() => _profileVisibility = 'private'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
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
                        : Text(context.l10n.save),
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
