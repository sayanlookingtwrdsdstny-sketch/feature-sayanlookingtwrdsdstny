import 'package:flutter/material.dart';
import 'package:nuriva/core/config/legal.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/features/auth/domain/account_service.dart';

/// The privacy notice a user agrees to at registration.
///
/// Written to meet the DPDP Act 2023 notice duties (what is collected, why,
/// who sees it, where it is kept, the user's rights, how to get in touch).
/// **Needs legal review before any public release.** When the wording changes,
/// bump [kPrivacyNoticeVersion] so new consent records point at the new text.
final class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contact = LegalInfo.privacyContactEmail;

    final sections = <(String, String)>[
      (
        'What NURIVA is',
        'NURIVA helps you and your family organise medication and reminders. '
            'It does not diagnose conditions, recommend treatment, or change '
            'any prescription.',
      ),
      (
        'What we collect',
        'Your name and email address, and the medication details, '
            'prescriptions and dose records that you or the family members you '
            'approve add to NURIVA.',
      ),
      (
        'Why we use it',
        'Only to run NURIVA for you: to send reminders, keep your medication '
            'history, and share information with family members you approve. '
            'We do not sell your data or use it for advertising.',
      ),
      (
        'Who can see it',
        'You, and only the family members you explicitly approve. You can '
            'remove their access at any time.',
      ),
      (
        "Where it's stored",
        'On Google Firebase servers in ${LegalInfo.dataRegion}, encrypted '
            'while it travels and while it is stored.',
      ),
      (
        'Your rights',
        "Under India's Digital Personal Data Protection Act, 2023, you can ask "
            'to see, correct or delete your data, and you can withdraw your '
            'consent at any time. Withdrawing consent stops NURIVA from '
            'processing your data.',
      ),
      (
        'Contact',
        contact != null
            ? 'For privacy questions or complaints, write to $contact.'
            : 'Contact details for privacy questions will be published before '
                "NURIVA's public release.",
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy notice')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NurivaTokens.pageInset,
            NurivaTokens.space2,
            NurivaTokens.pageInset,
            NurivaTokens.space12,
          ),
          children: [
            for (final (heading, body) in sections) ...[
              Text(heading, style: context.text.titleMedium),
              const SizedBox(height: NurivaTokens.space2),
              Text(body, style: context.text.bodyLarge),
              const SizedBox(height: NurivaTokens.space6),
            ],
            Text(
              'Notice version $kPrivacyNoticeVersion',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
