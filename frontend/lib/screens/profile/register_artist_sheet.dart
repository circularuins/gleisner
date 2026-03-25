import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../graphql/client.dart';
import '../../graphql/mutations/artist.dart';
import '../../theme/gleisner_tokens.dart';

class RegisterArtistSheet extends ConsumerStatefulWidget {
  /// Called with the registered artistUsername on success.
  final ValueChanged<String> onRegistered;

  const RegisterArtistSheet({super.key, required this.onRegistered});

  @override
  ConsumerState<RegisterArtistSheet> createState() =>
      _RegisterArtistSheetState();
}

class _RegisterArtistSheetState extends ConsumerState<RegisterArtistSheet> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final client = ref.read(graphqlClientProvider);
      final result = await client.mutate(
        MutationOptions(
          document: gql(registerArtistMutation),
          variables: {
            'artistUsername': _usernameController.text.trim(),
            'displayName': _displayNameController.text.trim(),
          },
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        setState(() {
          _isSubmitting = false;
          _error =
              result.exception?.graphqlErrors.firstOrNull?.message ??
              'Registration failed';
        });
        return;
      }

      final data = result.data?['registerArtist'] as Map<String, dynamic>?;
      if (data == null) {
        setState(() {
          _isSubmitting = false;
          _error = 'Unexpected response';
        });
        return;
      }

      final artistUsername = data['artistUsername'] as String;
      Navigator.pop(context);
      widget.onRegistered(artistUsername);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RegisterArtist] Unexpected error: $e');
      setState(() {
        _isSubmitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: spaceXl,
        right: spaceXl,
        top: spaceXl,
        bottom: MediaQuery.of(context).viewInsets.bottom + spaceXl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Become an Artist', style: textTitle),
            const SizedBox(height: spaceSm),
            Text(
              'Start sharing your creative journey',
              style: textBody.copyWith(color: colorTextSecondary),
            ),
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
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Artist Username',
                hintText: 'e.g. myjazzjourney',
                border: OutlineInputBorder(),
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
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g. Jazz Journey',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length > 50) return 'Max 50 characters';
                return null;
              },
            ),
            const SizedBox(height: spaceXl),
            FilledButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
