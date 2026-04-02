import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../widgets/common/auth_header.dart';
import '../../widgets/common/error_banner.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final String? inviteCode;

  const SignupScreen({super.key, this.inviteCode});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  late final TextEditingController _inviteCodeController;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  int _birthYear = DateTime.now().year - 25;
  int _birthMonth = 1;

  @override
  void initState() {
    super.initState();
    _inviteCodeController = TextEditingController(
      text: widget.inviteCode ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsProvider.notifier)
          .trackPageView('/signup', metadata: {'funnel': 'signup_start'});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final displayName = _displayNameController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();
    final birthYearMonth =
        '$_birthYear-${_birthMonth.toString().padLeft(2, '0')}';
    await ref
        .read(authProvider.notifier)
        .signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
          birthYearMonth: birthYearMonth,
          displayName: displayName.isNotEmpty ? displayName : null,
          inviteCode: inviteCode.isNotEmpty ? inviteCode : null,
        );

    if (mounted) setState(() => _isSubmitting = false);
    // Navigation handled by router redirect: /signup → /onboarding
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return AuthLayout(
      // TODO(featured-artist): Replace with featured/demo artist from API
      onTryIt: () => context.go('/@seeduser'),
      onAboutTap: () => context.push('/about'),
      form: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(spaceXl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(subtitle: 'Create your account'),
                const SizedBox(height: spaceXxl),
                if (authState.error != null) ...[
                  ErrorBanner(message: authState.error!),
                  const SizedBox(height: spaceLg),
                ],
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'How you want to be known',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: spaceLg),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: validateUsername,
                ),
                const SizedBox(height: spaceLg),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: spaceLg),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: spaceLg),
                TextFormField(
                  controller: _passwordConfirmController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: spaceLg),
                Text(
                  'Birth Year & Month',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorTextMuted),
                ),
                const SizedBox(height: spaceSm),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: _birthYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(DateTime.now().year - 1900 + 1, (
                          i,
                        ) {
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
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                        ),
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
                const SizedBox(height: spaceLg),
                TextFormField(
                  controller: _inviteCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
                    hintText: 'Enter your invite code',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 20,
                  validator: validateInviteCode,
                ),
                const SizedBox(height: spaceXl),
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleSignup,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: spaceLg),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
