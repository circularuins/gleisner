import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/guardian_provider.dart';
import '../../theme/gleisner_tokens.dart';

class CreateChildSheet extends ConsumerStatefulWidget {
  const CreateChildSheet({super.key});

  @override
  ConsumerState<CreateChildSheet> createState() => _CreateChildSheetState();
}

class _CreateChildSheetState extends ConsumerState<CreateChildSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  int _birthYear = DateTime.now().year - 5;
  int _birthMonth = 1;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
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
            padding: const EdgeInsets.all(spaceXl),
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: spaceXl),
              Text(context.l10n.addChildAccount, style: textTitle),
              const SizedBox(height: spaceMd),
              Container(
                padding: const EdgeInsets.all(spaceMd),
                decoration: BoxDecoration(
                  color: colorSurface2,
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.aboutChildAccounts,
                      style: textLabel.copyWith(color: colorTextSecondary),
                    ),
                    const SizedBox(height: spaceSm),
                    Text(
                      context.l10n.childAccountDescription,
                      style: textCaption.copyWith(
                        color: colorTextMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: spaceXl),

              // Username
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.username,
                  hintText: context.l10n.usernameFormat,
                  labelStyle: const TextStyle(color: colorTextMuted),
                  hintStyle: const TextStyle(color: colorInteractiveMuted),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorBorder),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorAccentGold),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorError),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorError),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                ),
                style: const TextStyle(color: colorTextPrimary),
                validator: (v) {
                  if (v == null || v.length < 2) {
                    return context.l10n.usernameFormat;
                  }
                  if (v.length > 30) return context.l10n.usernameFormat;
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                    return context.l10n.usernameFormat;
                  }
                  return null;
                },
              ),
              const SizedBox(height: spaceLg),

              // Display Name
              TextFormField(
                controller: _displayNameCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.displayName,
                  labelStyle: const TextStyle(color: colorTextMuted),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorBorder),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorAccentGold),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                ),
                style: const TextStyle(color: colorTextPrimary),
                validator: (v) {
                  if (v != null && v.length > 50) {
                    return context.l10n.maxCharacters(50);
                  }
                  return null;
                },
              ),
              const SizedBox(height: spaceLg),

              // Birth Year/Month
              Text(
                context.l10n.birthYearMonth,
                style: textLabel.copyWith(color: colorTextMuted),
              ),
              const SizedBox(height: spaceSm),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _birthYear,
                      decoration: InputDecoration(
                        labelText: context.l10n.year,
                        labelStyle: const TextStyle(color: colorTextMuted),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: colorBorder),
                          borderRadius: BorderRadius.circular(radiusMd),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: colorAccentGold),
                          borderRadius: BorderRadius.circular(radiusMd),
                        ),
                      ),
                      dropdownColor: colorSurface2,
                      style: const TextStyle(color: colorTextPrimary),
                      items: List.generate(DateTime.now().year - 1900 + 1, (i) {
                        final year = DateTime.now().year - i;
                        return DropdownMenuItem(
                          value: year,
                          child: Text('$year'),
                        );
                      }),
                      onChanged: (v) => setState(() => _birthYear = v!),
                    ),
                  ),
                  const SizedBox(width: spaceMd),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _birthMonth,
                      decoration: InputDecoration(
                        labelText: context.l10n.month,
                        labelStyle: const TextStyle(color: colorTextMuted),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: colorBorder),
                          borderRadius: BorderRadius.circular(radiusMd),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: colorAccentGold),
                          borderRadius: BorderRadius.circular(radiusMd),
                        ),
                      ),
                      dropdownColor: colorSurface2,
                      style: const TextStyle(color: colorTextPrimary),
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'.padLeft(2, '0')),
                        ),
                      ),
                      onChanged: (v) => setState(() => _birthMonth = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spaceXl),

              // Guardian password confirmation
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.password,
                  hintText: context.l10n.enterPasswordToConfirm,
                  labelStyle: const TextStyle(color: colorTextMuted),
                  hintStyle: const TextStyle(color: colorInteractiveMuted),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorBorder),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorAccentGold),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorError),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: colorError),
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                ),
                style: const TextStyle(color: colorTextPrimary),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return context.l10n.passwordRequired;
                  return null;
                },
              ),
              const SizedBox(height: spaceXl),

              // Error
              if (_error != null) ...[
                Text(_error!, style: textCaption.copyWith(color: colorError)),
                const SizedBox(height: spaceMd),
              ],

              // Submit
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colorAccentGold,
                  foregroundColor: colorSurface0,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.createAccount),
              ),

              const SizedBox(height: spaceMd),
              Text(
                context.l10n.childAccountPrivateNote,
                style: textCaption.copyWith(
                  color: colorTextMuted,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final birthYearMonth =
        '$_birthYear-${_birthMonth.toString().padLeft(2, '0')}';

    final success = await ref
        .read(guardianProvider.notifier)
        .createChild(
          username: _usernameCtrl.text.trim(),
          displayName: _displayNameCtrl.text.trim().isEmpty
              ? null
              : _displayNameCtrl.text.trim(),
          birthYearMonth: birthYearMonth,
          guardianPassword: _passwordCtrl.text,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      final error = ref.read(guardianProvider).error;
      setState(() {
        _submitting = false;
        _error = error ?? 'Something went wrong. Please try again.';
      });
    }
  }
}
