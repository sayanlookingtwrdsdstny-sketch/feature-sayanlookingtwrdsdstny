import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_validators.dart';
import 'package:nuriva/features/auth/presentation/auth_copy.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';

/// Sign in with email and password.
///
/// On success this screen does nothing itself: the session changes and the
/// router moves the user on (to verification or home).
final class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(accountServiceProvider).signIn(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = result.failureOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue.',
      footer: AuthFooterPrompt(
        prompt: 'New to NURIVA?',
        actionLabel: 'Create an account',
        onAction: () => context.pushReplacement(AppRoutes.register),
      ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NurivaTextField(
                  label: 'Email',
                  controller: _email,
                  hint: 'you@example.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthCopy.field('email', AuthValidators.email),
                ),
                const SizedBox(height: NurivaTokens.space5),
                NurivaTextField(
                  label: 'Password',
                  controller: _password,
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AuthCopy.forField('password', 'empty')
                      : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: NurivaButton(
            label: 'Forgot password?',
            variant: NurivaButtonVariant.text,
            onPressed: () => context.push(
              Uri(
                path: AppRoutes.forgotPassword,
                queryParameters: {
                  if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
                },
              ).toString(),
            ),
          ),
        ),
        const SizedBox(height: NurivaTokens.space4),
        if (_failure != null) ...[
          NurivaInlineMessage(message: AuthCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(label: 'Sign in', onPressed: _submit, isBusy: _busy),
      ],
    );
  }
}
