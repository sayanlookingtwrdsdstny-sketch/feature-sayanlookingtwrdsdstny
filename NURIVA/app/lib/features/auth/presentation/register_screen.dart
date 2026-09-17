import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_validators.dart';
import 'package:nuriva/features/auth/presentation/auth_copy.dart';
import 'package:nuriva/features/auth/presentation/widgets/account_fields.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';

/// Create an account: name, email, password, role and DPDP consent.
final class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roleKey = GlobalKey<FormFieldState<RoleChoice>>();
  final _consentKey = GlobalKey<FormFieldState<bool>>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
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
    final result = await ref.read(accountServiceProvider).register(
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
          roles: _roleKey.currentState?.value?.roles ?? const {},
          consentGiven: _consentKey.currentState?.value ?? false,
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
      title: 'Create your account',
      subtitle: 'It takes about a minute.',
      footer: AuthFooterPrompt(
        prompt: 'Already have an account?',
        actionLabel: 'Sign in',
        onAction: () => context.pushReplacement(AppRoutes.login),
      ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NurivaTextField(
                  label: 'Your name',
                  controller: _name,
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: AuthCopy.field(
                    'displayName',
                    AuthValidators.displayName,
                  ),
                ),
                const SizedBox(height: NurivaTokens.space5),
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
                  helper: 'At least 8 characters. Tap the eye to check it.',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator:
                      AuthCopy.field('password', AuthValidators.password),
                ),
                const SizedBox(height: NurivaTokens.space6),
                RoleChoiceField(key: _roleKey),
                const SizedBox(height: NurivaTokens.space4),
                ConsentField(
                  key: _consentKey,
                  onReadNotice: () => context.push(AppRoutes.privacy),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NurivaTokens.space4),
        if (_failure != null) ...[
          NurivaInlineMessage(message: AuthCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(
          label: 'Create account',
          onPressed: _submit,
          isBusy: _busy,
        ),
      ],
    );
  }
}
