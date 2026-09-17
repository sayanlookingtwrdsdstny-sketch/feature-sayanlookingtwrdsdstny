import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/result/result.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/presentation/auth_copy.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';

/// Waits for the user to confirm their email address.
///
/// Checks automatically when the app returns to the foreground — the usual
/// path is: switch to the mail app, tap the link, switch back. Requiring an
/// extra tap after that would be friction for no reason.
final class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  /// Seconds before the verification email can be sent again. Firebase rate
  /// limits resends, so offering it immediately would just produce errors.
  static const int resendCooldownSeconds = 60;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _cooldownTimer;
  int _cooldown = VerifyEmailScreen.resendCooldownSeconds;
  bool _checking = false;
  bool _resending = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // An email was just sent at registration, so start in cooldown.
    _startCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = VerifyEmailScreen.resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);

    final result = await ref.read(accountServiceProvider).checkVerified();
    if (!mounted) return;
    setState(() => _checking = false);

    // When verified, the session changes and the router moves on by itself.
    if (silent) return;
    switch (result) {
      case Success(value: false):
        NurivaDialogs.toast(
          context,
          "We haven't seen the confirmation yet. Open the link in the "
          'email, then try again.',
          status: NurivaStatus.warning,
        );
      case Failure(:final failure):
        setState(() => _failure = failure);
      case Success():
        break;
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _failure = null;
    });
    final result = await ref.read(accountServiceProvider).resendVerification();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _failure = result.failureOrNull;
    });
    if (result.isSuccess) {
      NurivaDialogs.toast(context, 'Email sent again');
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final email = session is AwaitingVerification ? session.user.email : '';

    return AuthScaffold(
      icon: Icons.mark_email_unread_outlined,
      title: 'Confirm your email',
      subtitle: "We've sent a link to $email. Open it to confirm this "
          'address, then come back here.',
      children: [
        const NurivaInlineMessage(
          message: "Can't find it? Check your spam or junk folder.",
          status: NurivaStatus.info,
        ),
        const SizedBox(height: NurivaTokens.space6),
        if (_failure != null) ...[
          NurivaInlineMessage(message: AuthCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(
          label: "I've confirmed my email",
          onPressed: _check,
          isBusy: _checking,
        ),
        const SizedBox(height: NurivaTokens.space3),
        NurivaButton(
          label: _cooldown > 0
              ? 'Send again in ${_cooldown}s'
              : 'Send the email again',
          variant: NurivaButtonVariant.secondary,
          onPressed: _cooldown > 0 ? null : _resend,
          isBusy: _resending,
        ),
        const SizedBox(height: NurivaTokens.space4),
        Center(
          child: NurivaButton(
            label: 'Use a different account',
            variant: NurivaButtonVariant.text,
            onPressed: () => ref.read(accountServiceProvider).signOut(),
          ),
        ),
      ],
    );
  }
}
