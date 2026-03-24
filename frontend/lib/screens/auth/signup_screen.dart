import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/gleisner_hero.dart';
import '../../widgets/common/auth_header.dart';
import '../../widgets/common/error_banner.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await ref
        .read(authProvider.notifier)
        .signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
        );

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colorSurface0,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            if (isWide) {
              return Row(
                children: [
                  const Expanded(child: GleisnerHero()),
                  Container(width: 1, color: colorBorder),
                  Expanded(child: Center(child: _buildForm(authState))),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: spaceXxl),
                  _buildForm(authState),
                  const SizedBox(height: spaceLg),
                  const GleisnerHero(compact: true),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(AuthState authState) {
    return ConstrainedBox(
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
    );
  }
}
