import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:nuriva/features/patients/application/patient_providers.dart';
import 'package:nuriva/features/patients/presentation/patient_copy.dart';

/// Redeems a link code, creating a PENDING guardian relationship. Approval
/// by the patient's primary guardian still has to happen before any patient
/// data becomes visible — this screen only explains that, it can't skip it.
final class JoinPatientScreen extends ConsumerStatefulWidget {
  const JoinPatientScreen({super.key});

  @override
  ConsumerState<JoinPatientScreen> createState() => _JoinPatientScreenState();
}

class _JoinPatientScreenState extends ConsumerState<JoinPatientScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref
        .read(careCircleServiceProvider)
        .redeemLinkCode(code: _code.text, guardianUid: uid);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = result.failureOrNull;
      _sent = result.isSuccess;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthScaffold(
        icon: Icons.hourglass_top_outlined,
        title: 'Request sent',
        subtitle: "The patient's primary guardian needs to approve you "
            "before you can see anything. You'll be able to open this "
            "patient from your patients list once they do.",
        children: [
          NurivaButton(
            label: 'Done',
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Enter a link code',
      subtitle: 'Ask the family member who set up this patient for their '
          '6-character code.',
      children: [
        NurivaTextField(
          label: 'Code',
          controller: _code,
          hint: 'ABC123',
          prefixIcon: Icons.qr_code_outlined,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: NurivaTokens.space6),
        if (_failure != null) ...[
          NurivaInlineMessage(message: PatientCopy.forFailure(_failure!)),
          const SizedBox(height: NurivaTokens.space4),
        ],
        NurivaButton(label: 'Join', onPressed: _submit, isBusy: _busy),
      ],
    );
  }
}

/// Uppercases as the user types — codes are generated uppercase-only
/// (`LinkCodeGenerator`), and typing lowercase should still work.
final class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
