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

/// Request a password-reset email.
///
/// The confirmation is worded identically whether or not an account exists,
/// so this screen cannot be used to discover who has signed up.
final class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
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
    final result = await ref
        .read(accountServiceProvider)
        .sendPasswordReset(email: _email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = result.failureOrNull;
      _sent = result.isSuccess;
    });
  }

  void _backToSignIn() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthScaffold(
        icon: Icons.mark_email_read_outlined,
        title: 'Check your email',
        subtitle: "If there's an account for ${_email.text.trim()}, a link to "
            'set a new password is on its way. It can take a few minutes — '
            'check your spam folder too.',
        children: [
          NurivaButton(label: 'Back to sign in', onPressed: _backToSignIn),
        ],
      );
    }

    return AuthScaffold(
      title: 'Reset your password',
      subtitle: "Enter the email you signed up with and we'll send you a link "
          'to set a new password.',
      children: [
        Form(
          key: _formKey,
          child: NurivaTextField(
            label: 'Email',
            controller: _email,
            hint: 'you@example.com',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
            validator: AuthCopy.field('email', AuthValidators.email),
          ),
        ),
        const SizedBox(height: NurivaTokens.space6),
        if (_failure != null) ...[
          NurivaInlineMessage(message: AuthCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(
          label: 'Send reset link',
          onPressed: _submit,
          isBusy: _busy,
        ),
      ],
    );
  }
}
