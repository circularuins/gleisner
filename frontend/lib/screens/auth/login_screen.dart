import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/featured_artist_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../widgets/common/auth_header.dart';
import '../../widgets/common/error_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider.notifier).trackPageView('/login');
      ref.read(featuredArtistProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await ref
        .read(authProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final featuredUsername = ref.watch(featuredArtistProvider);

    return AuthLayout(
      onTryIt: featuredUsername != null
          ? () => context.go('/@$featuredUsername')
          : null,
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
                const AuthHeader(subtitle: 'Sign in to your account'),
                const SizedBox(height: spaceXxl),
                if (authState.error != null) ...[
                  ErrorBanner(message: authState.error!),
                  const SizedBox(height: spaceLg),
                ],
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
                  validator: (v) => validateRequired(v, 'Password'),
                ),
                const SizedBox(height: spaceXl),
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleLogin,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: spaceLg),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
