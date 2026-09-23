/// A curated list of IANA timezones for the patient-timezone picker.
///
/// ARCHITECTURE §4: a patient's timezone "drives ALL scheduling" once
/// medications exist, so it must be a real IANA zone, never the device's
/// non-standard abbreviation (`DateTime.now().timeZoneName` returns things
/// like `IST` or `GMT+5:30`, which are not valid IANA identifiers and can be
/// ambiguous). No timezone-database package is wired in yet (deferred until
/// a scheduling module actually needs DST-aware conversion), so for now the
/// user picks explicitly from this list rather than the app guessing wrong
/// silently. Defaults to `Asia/Kolkata` — NURIVA's decided jurisdiction
/// (`docs/NURIVA_MODULE_STATUS.md`).
abstract final class NurivaTimezones {
  static const String defaultZone = 'Asia/Kolkata';

  static const List<String> common = [
    'Asia/Kolkata',
    'Asia/Dhaka',
    'Asia/Karachi',
    'Asia/Kathmandu',
    'Asia/Colombo',
    'Asia/Dubai',
    'Asia/Singapore',
    'Europe/London',
    'Europe/Berlin',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Australia/Sydney',
    'UTC',
  ];
}
