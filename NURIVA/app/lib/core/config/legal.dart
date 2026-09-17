/// Legal and privacy contact details shown in the privacy notice.
///
/// India's DPDP Act 2023 requires the notice to tell people how to reach
/// someone about their data. Set this before any public release.
abstract final class LegalInfo {
  /// Contact for privacy questions and grievances. `null` until provided —
  /// the notice then states that contact details will be published before
  /// release, rather than showing a fake address.
  static const String? privacyContactEmail = null;

  /// Where the data lives. Must match the Firestore location.
  static const String dataRegion = 'Mumbai, India';
}
