import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/domain/auth_validators.dart';
import 'package:nuriva/features/auth/presentation/auth_copy.dart';
import 'package:nuriva/features/auth/presentation/widgets/account_fields.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';

/// Recovery path: the account exists but its profile was never saved
/// (registration was interrupted between the two steps).
final class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roleKey = GlobalKey<FormFieldState<RoleChoice>>();
  final _consentKey = GlobalKey<FormFieldState<bool>>();
  late final _name = TextEditingController(text: _user?.displayName);
  bool _busy = false;
  AppFailure? _failure;

  AuthUser? get _user => switch (ref.read(sessionProvider)) {
        NeedsProfile(:final user) => user,
        _ => null,
      };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _user;
    if (_busy || user == null) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(accountServiceProvider).completeProfile(
          user: user,
          displayName: _name.text,
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
      title: 'Finish setting up',
      subtitle: "We couldn't save your details last time. Add them now to "
          'continue.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NurivaTextField(
                label: 'Your name',
                controller: _name,
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.done,
                validator: AuthCopy.field(
                  'displayName',
                  AuthValidators.displayName,
                ),
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
        const SizedBox(height: NurivaTokens.space4),
        if (_failure != null) ...[
          NurivaInlineMessage(message: AuthCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(
          label: 'Save and continue',
          onPressed: _submit,
          isBusy: _busy,
        ),
        const SizedBox(height: NurivaTokens.space3),
        Center(
          child: NurivaButton(
            label: 'Sign out',
            variant: NurivaButtonVariant.text,
            onPressed: () => ref.read(accountServiceProvider).signOut(),
          ),
        ),
      ],
    );
  }
}
